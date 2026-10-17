import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../../core/localization/app_strings.dart';
import '../../models/ai_inference_result.dart';
import '../../models/audit_log_model.dart';
import '../../models/consumer_model.dart';
import '../../models/meter_model.dart';
import '../../models/reading_model.dart';
import '../../models/route_model.dart';
import '../../models/user_model.dart';
import '../../models/validation_result.dart';
import '../services/ai/stub_ai_service.dart';
import '../services/storage/database_service.dart';
import '../services/sync/sync_service.dart';
import '../services/validation/rule_engine_service.dart';

/// Central state manager coordinating field readings, business rules,
/// supervisor decisions, and telemetry metrics (ChangeNotifier pattern).
class AppState extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final StubAiService _aiService = StubAiService();
  final RuleEngineService _ruleEngine = RuleEngineService();
  final SyncService _syncService = SyncService();

  UserModel _currentUser = DatabaseService.instance.users.first;
  RouteModel? _activeRoute;
  String _consumerSearchQuery = '';
  String _consumerStatusFilter = 'All'; // 'All', 'Pending', 'Done', 'Flagged', 'Problem'
  bool _isUrdu = false;
  ThemeMode _themeMode = ThemeMode.light;

  // Getters
  DatabaseService get db => _db;
  StubAiService get aiService => _aiService;
  RuleEngineService get ruleEngine => _ruleEngine;
  SyncService get syncService => _syncService;

  UserModel get currentUser => _currentUser;
  RouteModel? get activeRoute => _activeRoute ?? (_db.routes.isNotEmpty ? _db.routes.first : null);
  String get consumerSearchQuery => _consumerSearchQuery;
  String get consumerStatusFilter => _consumerStatusFilter;
  bool get isUrdu => _isUrdu;
  ThemeMode get themeMode => _themeMode;

  bool get isReader => _currentUser.role == UserRole.reader;
  bool get isSupervisor => _currentUser.role == UserRole.supervisor;
  bool get isAdmin => _currentUser.role == UserRole.admin;

  AppState() {
    _init();
  }

  void _init() {
    if (_db.routes.isNotEmpty) {
      _activeRoute = _db.routes.first;
    }
  }

  // -------------------------------------------------------------
  // USER / SESSION ACTIONS
  // -------------------------------------------------------------

  void setCurrentUser(UserModel user) {
    _currentUser = user;
    if (user.assignedRouteIds.isNotEmpty) {
      final matching = _db.routes.where((r) => user.assignedRouteIds.contains(r.id)).toList();
      if (matching.isNotEmpty) {
        _activeRoute = matching.first;
      }
    }
    notifyListeners();
  }

  void switchRole(UserRole role) {
    final user = _db.users.firstWhere((u) => u.role == role, orElse: () => _db.users.first);
    setCurrentUser(user);
  }

  void setActiveRoute(RouteModel route) {
    _activeRoute = route;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _consumerSearchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(String filter) {
    _consumerStatusFilter = filter;
    notifyListeners();
  }

  void toggleLanguage() {
    _isUrdu = !_isUrdu;
    AppStrings.isUrdu = _isUrdu;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = (_themeMode == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void toggleOnlineMode() {
    _syncService.setOnlineMode(!_syncService.isOnline);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // FILTERED CONSUMERS & PROGRESS (FR-5, FR-6, FR-8)
  // -------------------------------------------------------------

  List<ConsumerModel> get consumersForActiveRoute {
    final route = activeRoute;
    if (route == null) return [];
    return _db.consumers.where((c) => c.routeId == route.id).toList();
  }

  List<ConsumerModel> get filteredConsumers {
    final routeConsumers = consumersForActiveRoute;
    return routeConsumers.where((c) {
      final matchesSearch = _consumerSearchQuery.isEmpty ||
          c.referenceNo.toLowerCase().contains(_consumerSearchQuery.toLowerCase()) ||
          c.name.toLowerCase().contains(_consumerSearchQuery.toLowerCase()) ||
          c.meterId.toLowerCase().contains(_consumerSearchQuery.toLowerCase());

      if (!matchesSearch) return false;

      final reading = _db.getReadingForConsumer(c.id);
      if (_consumerStatusFilter == 'All') return true;
      if (_consumerStatusFilter == 'Pending') return reading == null;
      if (_consumerStatusFilter == 'Done') {
        return reading != null && reading.trafficLight == TrafficLight.green && reading.status != ReadingStatus.problem;
      }
      if (_consumerStatusFilter == 'Flagged') {
        return reading != null && (reading.trafficLight == TrafficLight.amber || reading.trafficLight == TrafficLight.red) && reading.status != ReadingStatus.problem;
      }
      if (_consumerStatusFilter == 'Problem') {
        return reading != null && reading.status == ReadingStatus.problem;
      }

      return true;
    }).toList();
  }

  int get routeTotalCount => consumersForActiveRoute.length;

  int get routeCompletedCount {
    final routeConsumers = consumersForActiveRoute;
    int count = 0;
    for (final c in routeConsumers) {
      if (_db.getReadingForConsumer(c.id) != null) count++;
    }
    return count;
  }

  // -------------------------------------------------------------
  // SUPERVISOR REVIEW QUEUE (FR-40)
  // -------------------------------------------------------------

  List<ReadingModel> get supervisorQueue {
    return _db.readings.where((r) {
      // Show Amber, Red, or Problem status items that are pending or require review
      final isFlagged = (r.trafficLight == TrafficLight.amber ||
          r.trafficLight == TrafficLight.red ||
          r.status == ReadingStatus.problem ||
          r.status == ReadingStatus.pending);
      final notYetApproved = r.status != ReadingStatus.approved;
      return isFlagged && notYetApproved;
    }).toList();
  }

  // -------------------------------------------------------------
  // READING SUBMISSIONS (FR-30, FR-34 to FR-39)
  // -------------------------------------------------------------

  Future<void> submitReading({
    required ConsumerModel consumer,
    required MeterModel meter,
    required AiInferenceResult aiResult,
    required double finalValue,
    required ValidationResult validation,
    String? readerEditReason,
    bool isRollover = false,
    bool isMeterReplaced = false,
    double? oldMeterFinalReading,
  }) async {
    final now = DateTime.now();
    final clientUuid = 'UUID-${now.millisecondsSinceEpoch}-${consumer.id}';
    final imagePayload = '${consumer.id}:${aiResult.readingText}:${now.toIso8601String()}';
    final imageHash = sha256.convert(utf8.encode(imagePayload)).toString();

    final status = (validation.trafficLight == TrafficLight.green)
        ? ReadingStatus.approved
        : ReadingStatus.pending;

    final reading = ReadingModel(
      id: 'RDG-${now.millisecondsSinceEpoch}',
      clientUuid: clientUuid,
      meterId: meter.id,
      consumerId: consumer.id,
      cycleId: 'CYCLE-2026-10',
      readerId: _currentUser.id,
      aiValue: aiResult.readingValue,
      finalValue: finalValue,
      aiConfidence: aiResult.overallConfidence,
      trafficLight: validation.trafficLight,
      flags: aiResult.qualityFlags,
      status: status,
      readerEditReason: readerEditReason,
      capturedAt: now,
      syncStatus: _syncService.isOnline ? SyncStatus.synced : SyncStatus.savedOffline,
      syncedAt: _syncService.isOnline ? now : null,
      gpsLat: consumer.lat,
      gpsLng: consumer.lng,
      device: 'Samsung Galaxy A14 (SM-A145F)',
      modelVersion: aiResult.modelVersion,
      imageHash: imageHash,
      isRollover: isRollover,
      isMeterReplaced: isMeterReplaced,
      oldMeterFinalReading: oldMeterFinalReading,
    );

    await _db.saveReading(reading);

    if (readerEditReason != null && readerEditReason.isNotEmpty) {
      await _db.addAuditLog(AuditLogModel(
        id: 'LOG-${now.millisecondsSinceEpoch}',
        readingId: reading.id,
        consumerRef: consumer.referenceNo,
        user: _currentUser.name,
        action: 'edited_by_reader',
        beforeValue: '${aiResult.readingValue} kWh',
        afterValue: '$finalValue kWh',
        comment: readerEditReason,
        timestamp: now,
      ));
    }

    notifyListeners();
  }

  Future<void> reportProblem({
    required ConsumerModel consumer,
    required MeterModel meter,
    required String problemCode,
    String? note,
  }) async {
    final now = DateTime.now();
    final clientUuid = 'PROB-${now.millisecondsSinceEpoch}-${consumer.id}';
    final imageHash = sha256.convert(utf8.encode('PROBLEM:${consumer.id}:$now')).toString();

    final reading = ReadingModel(
      id: 'RDG-${now.millisecondsSinceEpoch}',
      clientUuid: clientUuid,
      meterId: meter.id,
      consumerId: consumer.id,
      cycleId: 'CYCLE-2026-10',
      readerId: _currentUser.id,
      aiValue: 0.0,
      finalValue: consumer.previousReading,
      aiConfidence: 0.0,
      trafficLight: TrafficLight.red,
      flags: const ['problem_reported'],
      status: ReadingStatus.problem,
      problemCode: problemCode,
      problemNote: note,
      capturedAt: now,
      syncStatus: _syncService.isOnline ? SyncStatus.synced : SyncStatus.savedOffline,
      syncedAt: _syncService.isOnline ? now : null,
      gpsLat: consumer.lat,
      gpsLng: consumer.lng,
      device: 'Samsung Galaxy A14',
      modelVersion: _aiService.activeModelVersion,
      imageHash: imageHash,
    );

    await _db.saveReading(reading);
    notifyListeners();
  }

  // -------------------------------------------------------------
  // SUPERVISOR ACTIONS (FR-41, FR-42)
  // -------------------------------------------------------------

  Future<void> supervisorApproveReading(ReadingModel reading, String comment) async {
    final now = DateTime.now();
    final consumer = _db.getConsumerById(reading.consumerId);

    final updated = reading.copyWith(
      status: ReadingStatus.approved,
      supervisorAction: 'approved',
      supervisorComment: comment,
    );
    await _db.saveReading(updated);

    await _db.addAuditLog(AuditLogModel(
      id: 'LOG-${now.millisecondsSinceEpoch}',
      readingId: reading.id,
      consumerRef: consumer?.referenceNo ?? 'N/A',
      user: _currentUser.name,
      action: 'approved',
      beforeValue: '${reading.finalValue} kWh (Pending)',
      afterValue: '${reading.finalValue} kWh (Approved)',
      comment: comment.isEmpty ? 'Reading verified and approved by Supervisor.' : comment,
      timestamp: now,
    ));

    notifyListeners();
  }

  Future<void> supervisorCorrectReading({
    required ReadingModel reading,
    required double newValue,
    required String comment,
  }) async {
    final now = DateTime.now();
    final consumer = _db.getConsumerById(reading.consumerId);

    final updated = reading.copyWith(
      finalValue: newValue,
      status: ReadingStatus.approved,
      supervisorAction: 'corrected',
      supervisorComment: comment,
    );
    await _db.saveReading(updated);

    await _db.addAuditLog(AuditLogModel(
      id: 'LOG-${now.millisecondsSinceEpoch}',
      readingId: reading.id,
      consumerRef: consumer?.referenceNo ?? 'N/A',
      user: _currentUser.name,
      action: 'corrected',
      beforeValue: '${reading.finalValue} kWh',
      afterValue: '$newValue kWh',
      comment: comment,
      timestamp: now,
    ));

    notifyListeners();
  }

  Future<void> supervisorRejectReading(ReadingModel reading, String comment) async {
    final now = DateTime.now();
    final consumer = _db.getConsumerById(reading.consumerId);

    final updated = reading.copyWith(
      status: ReadingStatus.rejected,
      supervisorAction: 'rejected',
      supervisorComment: comment,
    );
    await _db.saveReading(updated);

    await _db.addAuditLog(AuditLogModel(
      id: 'LOG-${now.millisecondsSinceEpoch}',
      readingId: reading.id,
      consumerRef: consumer?.referenceNo ?? 'N/A',
      user: _currentUser.name,
      action: 'rejected',
      beforeValue: '${reading.finalValue} kWh',
      afterValue: 'Returned to Reader for Retake',
      comment: comment,
      timestamp: now,
    ));

    notifyListeners();
  }

  Future<void> supervisorMarkFaulty(ReadingModel reading, String comment) async {
    final now = DateTime.now();
    final consumer = _db.getConsumerById(reading.consumerId);

    final updated = reading.copyWith(
      status: ReadingStatus.problem,
      problemCode: 'Meter Defective / Marked Faulty by SDO',
      supervisorAction: 'marked_faulty',
      supervisorComment: comment,
    );
    await _db.saveReading(updated);

    await _db.addAuditLog(AuditLogModel(
      id: 'LOG-${now.millisecondsSinceEpoch}',
      readingId: reading.id,
      consumerRef: consumer?.referenceNo ?? 'N/A',
      user: _currentUser.name,
      action: 'marked_faulty',
      beforeValue: 'Normal Meter Status',
      afterValue: 'Defective / Replacement Scheduled',
      comment: comment,
      timestamp: now,
    ));

    notifyListeners();
  }

  // -------------------------------------------------------------
  // METRICS & ACCURACY COMPUTATION (FR-50, FR-51, Section 13)
  // -------------------------------------------------------------

  int get totalReadingsCount => _db.readings.length;

  double get autoAcceptRate {
    if (totalReadingsCount == 0) return 72.0; // Baseline demo target
    final greens = _db.readings.where((r) => r.trafficLight == TrafficLight.green).length;
    return (greens / totalReadingsCount) * 100.0;
  }

  double get manualReviewRate {
    if (totalReadingsCount == 0) return 28.0;
    final ambersAndReds = _db.readings.where(
      (r) => r.trafficLight == TrafficLight.amber || r.trafficLight == TrafficLight.red,
    ).length;
    return (ambersAndReds / totalReadingsCount) * 100.0;
  }

  double get readerEditedRate {
    if (totalReadingsCount == 0) return 6.5;
    final edited = _db.readings.where((r) => r.isEditedByReader).length;
    return (edited / totalReadingsCount) * 100.0;
  }

  double get exactMatchAccuracy {
    if (totalReadingsCount == 0) return 94.2;
    final matches = _db.readings.where((r) => (r.aiValue - r.finalValue).abs() < 0.05).length;
    return (matches / totalReadingsCount) * 100.0;
  }

  double get wrongButConfidentRate {
    // Safety critical metric: Green results that were wrong (Target <= 1%)
    final greens = _db.readings.where((r) => r.trafficLight == TrafficLight.green).toList();
    if (greens.isEmpty) return 0.5;
    final wrongGreens = greens.where((r) => (r.aiValue - r.finalValue).abs() > 0.5).length;
    return (wrongGreens / greens.length) * 100.0;
  }

  Future<void> triggerSync() async {
    await _syncService.syncPendingReadings(onProgress: notifyListeners);
    notifyListeners();
  }

  Future<void> closeBillingCycle() async {
    await _db.closeBillingCycle();
    notifyListeners();
  }

  Future<void> resetDemoData() async {
    await _db.resetAllDemoData();
    notifyListeners();
  }
}
