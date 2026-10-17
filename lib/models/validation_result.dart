enum TrafficLight {
  green,
  amber,
  red,
}

/// Represents an individual validation rule check outcome (Section P1.3, Section 7).
class RuleCheckOutcome {
  final String ruleCode; // 'A', 'B', 'C', 'D', 'E', 'F' or 'V1'..'V14'
  final String title;
  final bool passed;
  final TrafficLight severityIfFailed;
  final String explanation;

  const RuleCheckOutcome({
    required this.ruleCode,
    required this.title,
    required this.passed,
    required this.severityIfFailed,
    required this.explanation,
  });
}

/// Comprehensive outcome of the 6 Phase-1 Validation Rules (P1.3).
class ValidationResult {
  final TrafficLight trafficLight;
  final List<RuleCheckOutcome> checks;
  final bool isRolloverDetected;
  final bool isSuspiciousZero;
  final bool isConsumptionSpike;
  final bool isDigitJump;
  final bool isFormatMismatched;
  final String primaryReason;

  const ValidationResult({
    required this.trafficLight,
    required this.checks,
    this.isRolloverDetected = false,
    this.isSuspiciousZero = false,
    this.isConsumptionSpike = false,
    this.isDigitJump = false,
    this.isFormatMismatched = false,
    required this.primaryReason,
  });

  bool get isGreen => trafficLight == TrafficLight.green;
  bool get isAmber => trafficLight == TrafficLight.amber;
  bool get isRed => trafficLight == TrafficLight.red;

  String get trafficLightTitle {
    switch (trafficLight) {
      case TrafficLight.green:
        return 'Auto-Accept Suggestion (Green)';
      case TrafficLight.amber:
        return 'Verification Required (Amber)';
      case TrafficLight.red:
        return 'Critical Anomaly / Untrusted (Red)';
    }
  }
}
