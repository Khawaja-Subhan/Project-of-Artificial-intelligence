enum MeterType {
  digitalLcd,
  analogDrum,
  threePhase,
  touSmart,
}

/// Technical specifications of an electrical meter (Section 3.2, 10.1).
class MeterModel {
  final String id;
  final String consumerId;
  final String meterNo;
  final MeterType meterType;
  final String phase; // 'single' or 'three'
  final int digits; // typically 5 or 6
  final int decimals; // typically 0 or 1
  final double multiplier; // Multiplier Factor (MF), usually 1.0 or 10.0
  final bool touEnabled;
  final bool bidirectional;
  final String installedOn;
  final String status; // 'normal', 'defective', 'burnt', 'replaced'

  const MeterModel({
    required this.id,
    required this.consumerId,
    required this.meterNo,
    required this.meterType,
    this.phase = 'single',
    this.digits = 5,
    this.decimals = 1,
    this.multiplier = 1.0,
    this.touEnabled = false,
    this.bidirectional = false,
    required this.installedOn,
    this.status = 'normal',
  });

  String get typeLabel {
    switch (meterType) {
      case MeterType.digitalLcd:
        return '1-Phase Digital LCD';
      case MeterType.analogDrum:
        return 'Analog Mechanical Dial';
      case MeterType.threePhase:
        return '3-Phase Static Electronic';
      case MeterType.touSmart:
        return 'TOU / Net Metering AMI';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'consumerId': consumerId,
    'meterNo': meterNo,
    'meterType': meterType.name,
    'phase': phase,
    'digits': digits,
    'decimals': decimals,
    'multiplier': multiplier,
    'touEnabled': touEnabled,
    'bidirectional': bidirectional,
    'installedOn': installedOn,
    'status': status,
  };

  factory MeterModel.fromJson(Map<String, dynamic> json) {
    return MeterModel(
      id: json['id'] as String,
      consumerId: json['consumerId'] as String,
      meterNo: json['meterNo'] as String,
      meterType: MeterType.values.firstWhere(
        (e) => e.name == json['meterType'],
        orElse: () => MeterType.digitalLcd,
      ),
      phase: json['phase'] as String? ?? 'single',
      digits: (json['digits'] as num?)?.toInt() ?? 5,
      decimals: (json['decimals'] as num?)?.toInt() ?? 1,
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      touEnabled: json['touEnabled'] as bool? ?? false,
      bidirectional: json['bidirectional'] as bool? ?? false,
      installedOn: json['installedOn'] as String? ?? '2022-01-15',
      status: json['status'] as String? ?? 'normal',
    );
  }
}
