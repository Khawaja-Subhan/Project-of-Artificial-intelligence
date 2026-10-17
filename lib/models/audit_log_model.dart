/// Immutable audit trail tracking every supervisor decision or reader modification (FR-42, Section 10.1).
class AuditLogModel {
  final String id;
  final String readingId;
  final String consumerRef;
  final String user;
  final String action; // 'approved', 'corrected', 'rejected', 'marked_faulty', 'edited_by_reader'
  final String entity;
  final String beforeValue;
  final String afterValue;
  final String comment;
  final DateTime timestamp;

  const AuditLogModel({
    required this.id,
    required this.readingId,
    required this.consumerRef,
    required this.user,
    required this.action,
    this.entity = 'reading',
    required this.beforeValue,
    required this.afterValue,
    required this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'readingId': readingId,
    'consumerRef': consumerRef,
    'user': user,
    'action': action,
    'entity': entity,
    'beforeValue': beforeValue,
    'afterValue': afterValue,
    'comment': comment,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as String,
      readingId: json['readingId'] as String,
      consumerRef: json['consumerRef'] as String? ?? 'N/A',
      user: json['user'] as String,
      action: json['action'] as String,
      entity: json['entity'] as String? ?? 'reading',
      beforeValue: json['beforeValue'] as String,
      afterValue: json['afterValue'] as String,
      comment: json['comment'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
