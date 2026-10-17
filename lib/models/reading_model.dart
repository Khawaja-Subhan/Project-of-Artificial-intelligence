import 'validation_result.dart';

enum ReadingStatus {
  pending,
  approved,
  rejected,
  problem,
}

enum SyncStatus {
  savedOffline,
  uploading,
  synced,
  failed,
}

/// Represents a single meter reading submission record (Section 10.1, FR-34 to FR-39).
class ReadingModel {
  final String id;
  final String clientUuid; // Client-generated idempotent ID (FR-36)
  final String meterId;
  final String consumerId;
  final String cycleId;
  final String readerId;
  final double aiValue;
  final double finalValue;
  final double aiConfidence;
  final TrafficLight trafficLight;
  final List<String> flags;
  final ReadingStatus status;
  final String? problemCode;
  final String? problemNote;
  final String? readerEditReason;
  final DateTime capturedAt;
  final DateTime? syncedAt;
  final SyncStatus syncStatus;
  final double? gpsLat;
  final double? gpsLng;
  final String device;
  final String modelVersion;
  final String imageHash; // SHA-256 (FR-14)
  final bool isRollover;
  final bool isMeterReplaced;
  final double? oldMeterFinalReading;
  final String? supervisorComment;
  final String? supervisorAction;

  const ReadingModel({
    required this.id,
    required this.clientUuid,
    required this.meterId,
    required this.consumerId,
    required this.cycleId,
    required this.readerId,
    required this.aiValue,
    required this.finalValue,
    required this.aiConfidence,
    required this.trafficLight,
    required this.flags,
    required this.status,
    this.problemCode,
    this.problemNote,
    this.readerEditReason,
    required this.capturedAt,
    this.syncedAt,
    this.syncStatus = SyncStatus.savedOffline,
    this.gpsLat,
    this.gpsLng,
    required this.device,
    required this.modelVersion,
    required this.imageHash,
    this.isRollover = false,
    this.isMeterReplaced = false,
    this.oldMeterFinalReading,
    this.supervisorComment,
    this.supervisorAction,
  });

  bool get isEditedByReader => (aiValue - finalValue).abs() > 0.05;

  ReadingModel copyWith({
    String? id,
    String? clientUuid,
    String? meterId,
    String? consumerId,
    String? cycleId,
    String? readerId,
    double? aiValue,
    double? finalValue,
    double? aiConfidence,
    TrafficLight? trafficLight,
    List<String>? flags,
    ReadingStatus? status,
    String? problemCode,
    String? problemNote,
    String? readerEditReason,
    DateTime? capturedAt,
    DateTime? syncedAt,
    SyncStatus? syncStatus,
    double? gpsLat,
    double? gpsLng,
    String? device,
    String? modelVersion,
    String? imageHash,
    bool? isRollover,
    bool? isMeterReplaced,
    double? oldMeterFinalReading,
    String? supervisorComment,
    String? supervisorAction,
  }) {
    return ReadingModel(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      meterId: meterId ?? this.meterId,
      consumerId: consumerId ?? this.consumerId,
      cycleId: cycleId ?? this.cycleId,
      readerId: readerId ?? this.readerId,
      aiValue: aiValue ?? this.aiValue,
      finalValue: finalValue ?? this.finalValue,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      trafficLight: trafficLight ?? this.trafficLight,
      flags: flags ?? this.flags,
      status: status ?? this.status,
      problemCode: problemCode ?? this.problemCode,
      problemNote: problemNote ?? this.problemNote,
      readerEditReason: readerEditReason ?? this.readerEditReason,
      capturedAt: capturedAt ?? this.capturedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      gpsLat: gpsLat ?? this.gpsLat,
      gpsLng: gpsLng ?? this.gpsLng,
      device: device ?? this.device,
      modelVersion: modelVersion ?? this.modelVersion,
      imageHash: imageHash ?? this.imageHash,
      isRollover: isRollover ?? this.isRollover,
      isMeterReplaced: isMeterReplaced ?? this.isMeterReplaced,
      oldMeterFinalReading: oldMeterFinalReading ?? this.oldMeterFinalReading,
      supervisorComment: supervisorComment ?? this.supervisorComment,
      supervisorAction: supervisorAction ?? this.supervisorAction,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clientUuid': clientUuid,
    'meterId': meterId,
    'consumerId': consumerId,
    'cycleId': cycleId,
    'readerId': readerId,
    'aiValue': aiValue,
    'finalValue': finalValue,
    'aiConfidence': aiConfidence,
    'trafficLight': trafficLight.name,
    'flags': flags,
    'status': status.name,
    'problemCode': problemCode,
    'problemNote': problemNote,
    'readerEditReason': readerEditReason,
    'capturedAt': capturedAt.toIso8601String(),
    'syncedAt': syncedAt?.toIso8601String(),
    'syncStatus': syncStatus.name,
    'gpsLat': gpsLat,
    'gpsLng': gpsLng,
    'device': device,
    'modelVersion': modelVersion,
    'imageHash': imageHash,
    'isRollover': isRollover,
    'isMeterReplaced': isMeterReplaced,
    'oldMeterFinalReading': oldMeterFinalReading,
    'supervisorComment': supervisorComment,
    'supervisorAction': supervisorAction,
  };

  factory ReadingModel.fromJson(Map<String, dynamic> json) {
    return ReadingModel(
      id: json['id'] as String,
      clientUuid: json['clientUuid'] as String,
      meterId: json['meterId'] as String,
      consumerId: json['consumerId'] as String,
      cycleId: json['cycleId'] as String,
      readerId: json['readerId'] as String,
      aiValue: (json['aiValue'] as num).toDouble(),
      finalValue: (json['finalValue'] as num).toDouble(),
      aiConfidence: (json['aiConfidence'] as num).toDouble(),
      trafficLight: TrafficLight.values.firstWhere(
        (e) => e.name == json['trafficLight'],
        orElse: () => TrafficLight.green,
      ),
      flags: List<String>.from(json['flags'] ?? []),
      status: ReadingStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ReadingStatus.pending,
      ),
      problemCode: json['problemCode'] as String?,
      problemNote: json['problemNote'] as String?,
      readerEditReason: json['readerEditReason'] as String?,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      syncedAt: json['syncedAt'] != null ? DateTime.parse(json['syncedAt'] as String) : null,
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == json['syncStatus'],
        orElse: () => SyncStatus.savedOffline,
      ),
      gpsLat: (json['gpsLat'] as num?)?.toDouble(),
      gpsLng: (json['gpsLng'] as num?)?.toDouble(),
      device: json['device'] as String? ?? 'DISCO Field Phone',
      modelVersion: json['modelVersion'] as String? ?? 'detector-v0.3 / ocr-v0.2',
      imageHash: json['imageHash'] as String? ?? '',
      isRollover: json['isRollover'] as bool? ?? false,
      isMeterReplaced: json['isMeterReplaced'] as bool? ?? false,
      oldMeterFinalReading: (json['oldMeterFinalReading'] as num?)?.toDouble(),
      supervisorComment: json['supervisorComment'] as String?,
      supervisorAction: json['supervisorAction'] as String?,
    );
  }
}
