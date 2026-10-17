/// Representation of an electricity consumer in the DISCO billing ledger (FR-5, FR-46, FR-49).
class ConsumerModel {
  final String id;
  final String referenceNo; // e.g. 04-11234-5678901 U
  final String name; // Strictly realistic fake names per FR-49
  final String address;
  final String tariffCategory; // Domestic, Commercial, Industrial, Agriculture
  final double connectedLoadKw;
  final double lat;
  final double lng;
  final String routeId;
  final String meterId;
  final double previousReading;
  final String previousDate;
  final List<double> past6MonthsConsumption; // Historical monthly consumed units for Rule D & E

  const ConsumerModel({
    required this.id,
    required this.referenceNo,
    required this.name,
    required this.address,
    required this.tariffCategory,
    required this.connectedLoadKw,
    required this.lat,
    required this.lng,
    required this.routeId,
    required this.meterId,
    required this.previousReading,
    required this.previousDate,
    required this.past6MonthsConsumption,
  });

  /// Computes the 6-month average consumed units for anomaly detection rules (Rule D & E).
  double get averageMonthlyConsumption {
    if (past6MonthsConsumption.isEmpty) return 150.0;
    final total = past6MonthsConsumption.reduce((a, b) => a + b);
    return total / past6MonthsConsumption.length;
  }

  /// Domestic consumers <= 200 units belong to NEPRA Protected tariff category
  bool get isProtectedSlab => tariffCategory.toLowerCase() == 'domestic' && averageMonthlyConsumption <= 200.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'referenceNo': referenceNo,
    'name': name,
    'address': address,
    'tariffCategory': tariffCategory,
    'connectedLoadKw': connectedLoadKw,
    'lat': lat,
    'lng': lng,
    'routeId': routeId,
    'meterId': meterId,
    'previousReading': previousReading,
    'previousDate': previousDate,
    'past6MonthsConsumption': past6MonthsConsumption,
  };

  factory ConsumerModel.fromJson(Map<String, dynamic> json) {
    return ConsumerModel(
      id: json['id'] as String,
      referenceNo: json['referenceNo'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      tariffCategory: json['tariffCategory'] as String? ?? 'Domestic',
      connectedLoadKw: (json['connectedLoadKw'] as num?)?.toDouble() ?? 3.0,
      lat: (json['lat'] as num?)?.toDouble() ?? 31.5204,
      lng: (json['lng'] as num?)?.toDouble() ?? 74.3587,
      routeId: json['routeId'] as String,
      meterId: json['meterId'] as String,
      previousReading: (json['previousReading'] as num?)?.toDouble() ?? 0.0,
      previousDate: json['previousDate'] as String? ?? '2026-09-15',
      past6MonthsConsumption: (json['past6MonthsConsumption'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [180.0, 210.0, 195.0, 240.0, 220.0, 190.0],
    );
  }
}
