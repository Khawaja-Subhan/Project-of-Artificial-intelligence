/// Meter Reader Route definition representing a DISCO billing batch & sub-division (FR-4, Section 10.1).
class RouteModel {
  final String id;
  final String name; // e.g., 'Gulberg III - Sector B'
  final String batchNo; // e.g., '04'
  final String subdivision; // e.g., 'SD-11234 (Model Town)'
  final String discoCode; // e.g., 'LESCO'
  final String readerId;

  const RouteModel({
    required this.id,
    required this.name,
    required this.batchNo,
    required this.subdivision,
    required this.discoCode,
    required this.readerId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'batchNo': batchNo,
    'subdivision': subdivision,
    'discoCode': discoCode,
    'readerId': readerId,
  };

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] as String,
      name: json['name'] as String,
      batchNo: json['batchNo'] as String,
      subdivision: json['subdivision'] as String,
      discoCode: json['discoCode'] as String? ?? 'LESCO',
      readerId: json['readerId'] as String,
    );
  }
}
