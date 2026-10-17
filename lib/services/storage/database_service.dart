import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/audit_log_model.dart';
import '../../models/consumer_model.dart';
import '../../models/meter_model.dart';
import '../../models/reading_model.dart';
import '../../models/route_model.dart';
import '../../models/user_model.dart';
import 'seed_data.dart';

/// Local database and persistence service implementing offline-first architecture (FR-34, FR-36).
/// Persists all routes, consumers, meters, readings queue, and audit logs locally.
class DatabaseService {
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();

  DatabaseService._();

  SharedPreferences? _prefs;

  final List<UserModel> _users = [];
  final List<RouteModel> _routes = [];
  final List<ConsumerModel> _consumers = [];
  final List<MeterModel> _meters = [];
  final List<ReadingModel> _readings = [];
  final List<AuditLogModel> _auditLogs = [];

  List<UserModel> get users => List.unmodifiable(_users);
  List<RouteModel> get routes => List.unmodifiable(_routes);
  List<ConsumerModel> get consumers => List.unmodifiable(_consumers);
  List<MeterModel> get meters => List.unmodifiable(_meters);
  List<ReadingModel> get readings => List.unmodifiable(_readings);
  List<AuditLogModel> get auditLogs => List.unmodifiable(_auditLogs);

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();

    _loadUsers();
    _loadRoutes();
    _loadConsumers();
    _loadMeters();
    _loadReadings();
    _loadAuditLogs();
  }

  void _loadUsers() {
    _users.clear();
    _users.addAll(SeedData.defaultUsers);
  }

  void _loadRoutes() {
    _routes.clear();
    _routes.addAll(SeedData.defaultRoutes);
  }

  void _loadConsumers() {
    _consumers.clear();
    final cached = _prefs?.getString('cached_consumers');
    if (cached != null) {
      try {
        final List list = jsonDecode(cached);
        _consumers.addAll(list.map((e) => ConsumerModel.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {
        _consumers.addAll(SeedData.generateSeedConsumers());
      }
    } else {
      final generated = SeedData.generateSeedConsumers();
      _consumers.addAll(generated);
      _persistConsumers();
    }
  }

  void _loadMeters() {
    _meters.clear();
    final cached = _prefs?.getString('cached_meters');
    if (cached != null) {
      try {
        final List list = jsonDecode(cached);
        _meters.addAll(list.map((e) => MeterModel.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {
        _meters.addAll(SeedData.generateSeedMeters(_consumers));
      }
    } else {
      final generated = SeedData.generateSeedMeters(_consumers);
      _meters.addAll(generated);
      _persistMeters();
    }
  }

  void _loadReadings() {
    _readings.clear();
    final cached = _prefs?.getString('cached_readings');
    if (cached != null) {
      try {
        final List list = jsonDecode(cached);
        _readings.addAll(list.map((e) => ReadingModel.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {}
    }
  }

  void _loadAuditLogs() {
    _auditLogs.clear();
    final cached = _prefs?.getString('cached_audit_logs');
    if (cached != null) {
      try {
        final List list = jsonDecode(cached);
        _auditLogs.addAll(list.map((e) => AuditLogModel.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {}
    }
  }

  Future<void> _persistConsumers() async {
    final str = jsonEncode(_consumers.map((e) => e.toJson()).toList());
    await _prefs?.setString('cached_consumers', str);
  }

  Future<void> _persistMeters() async {
    final str = jsonEncode(_meters.map((e) => e.toJson()).toList());
    await _prefs?.setString('cached_meters', str);
  }

  Future<void> _persistReadings() async {
    final str = jsonEncode(_readings.map((e) => e.toJson()).toList());
    await _prefs?.setString('cached_readings', str);
  }

  Future<void> _persistAuditLogs() async {
    final str = jsonEncode(_auditLogs.map((e) => e.toJson()).toList());
    await _prefs?.setString('cached_audit_logs', str);
  }

  // -------------------------------------------------------------
  // CRUD & MUTATIONS
  // -------------------------------------------------------------

  /// Saves or updates a reading locally using unique client_uuid (FR-36).
  Future<void> saveReading(ReadingModel reading) async {
    final existingIdx = _readings.indexWhere((r) => r.clientUuid == reading.clientUuid || r.id == reading.id);
    if (existingIdx >= 0) {
      _readings[existingIdx] = reading;
    } else {
      _readings.add(reading);
    }
    await _persistReadings();
  }

  /// Appends an immutable audit log entry (FR-42).
  Future<void> addAuditLog(AuditLogModel log) async {
    _auditLogs.insert(0, log);
    await _persistAuditLogs();
  }

  /// Finds consumer by ID
  ConsumerModel? getConsumerById(String id) {
    try {
      return _consumers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Finds meter by ID
  MeterModel? getMeterById(String id) {
    try {
      return _meters.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Finds reading for a specific consumer
  ReadingModel? getReadingForConsumer(String consumerId) {
    try {
      return _readings.firstWhere((r) => r.consumerId == consumerId);
    } catch (_) {
      return null;
    }
  }

  /// Executes Billing Cycle Close admin action (FR-47):
  /// Moves current readings to become next cycle's previous readings and resets readings queue.
  Future<void> closeBillingCycle() async {
    for (final reading in _readings) {
      if (reading.status == ReadingStatus.approved || reading.trafficLight.name == 'green') {
        final cIdx = _consumers.indexWhere((c) => c.id == reading.consumerId);
        if (cIdx >= 0) {
          final old = _consumers[cIdx];
          final updatedHistory = List<double>.from(old.past6MonthsConsumption);
          final consumed = (reading.finalValue - old.previousReading).clamp(0.0, 5000.0);
          updatedHistory.removeAt(0);
          updatedHistory.add(consumed);

          _consumers[cIdx] = ConsumerModel(
            id: old.id,
            referenceNo: old.referenceNo,
            name: old.name,
            address: old.address,
            tariffCategory: old.tariffCategory,
            connectedLoadKw: old.connectedLoadKw,
            lat: old.lat,
            lng: old.lng,
            routeId: old.routeId,
            meterId: old.meterId,
            previousReading: reading.finalValue,
            previousDate: '2026-10-14',
            past6MonthsConsumption: updatedHistory,
          );
        }
      }
    }
    _readings.clear();
    await _persistConsumers();
    await _persistReadings();
  }

  /// Resets demo to fresh seed state
  Future<void> resetAllDemoData() async {
    await _prefs?.clear();
    _consumers.clear();
    _meters.clear();
    _readings.clear();
    _auditLogs.clear();

    final generatedConsumers = SeedData.generateSeedConsumers();
    _consumers.addAll(generatedConsumers);
    _meters.addAll(SeedData.generateSeedMeters(generatedConsumers));
    await _persistConsumers();
    await _persistMeters();
  }
}
