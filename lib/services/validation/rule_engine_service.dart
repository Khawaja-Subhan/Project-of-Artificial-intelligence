import '../../core/constants/app_constants.dart';
import '../../models/ai_inference_result.dart';
import '../../models/consumer_model.dart';
import '../../models/meter_model.dart';
import '../../models/validation_result.dart';

/// Validation and Business Rules Engine implementing the 6 Phase-1 validation checks (P1.3)
/// plus extended DISCO anomalies (Section 7).
class RuleEngineService {
  double greenConfidenceThreshold;
  double amberConfidenceThreshold;
  double maxConsumptionMultiplier;
  double absoluteConsumptionCap;
  double suspiciousZeroThreshold;

  RuleEngineService({
    this.greenConfidenceThreshold = AppConstants.defaultGreenConfidenceThreshold,
    this.amberConfidenceThreshold = AppConstants.defaultAmberConfidenceThreshold,
    this.maxConsumptionMultiplier = AppConstants.defaultMaxConsumptionMultiplier,
    this.absoluteConsumptionCap = AppConstants.defaultAbsoluteConsumptionCap,
    this.suspiciousZeroThreshold = AppConstants.defaultSuspiciousZeroThreshold,
  });

  /// Evaluates an AI reading against the meter specs, consumer history, and previous reading.
  ValidationResult evaluate({
    required AiInferenceResult aiResult,
    required MeterModel meter,
    required ConsumerModel consumer,
    required double currentReading,
    bool isMarkedRollover = false,
    bool isMarkedMeterReplaced = false,
  }) {
    final checks = <RuleCheckOutcome>[];
    TrafficLight highestSeverity = TrafficLight.green;
    String primaryReason = 'All business and confidence checks passed successfully.';

    // Helper to upgrade severity
    void elevate(TrafficLight newSeverity, String reason) {
      if (newSeverity == TrafficLight.red) {
        highestSeverity = TrafficLight.red;
        primaryReason = reason;
      } else if (newSeverity == TrafficLight.amber && highestSeverity != TrafficLight.red) {
        highestSeverity = TrafficLight.amber;
        primaryReason = reason;
      }
    }

    // -------------------------------------------------------------
    // RULE A (Format & Digit Count, P1.3-A / V1, V2)
    // -------------------------------------------------------------
    final cleanDigits = aiResult.readingText.replaceAll(RegExp(r'[^0-9]'), '');
    final isNumeric = RegExp(r'^\d+(\.\d+)?$').hasMatch(aiResult.readingText);
    // Allow standard tolerance of meter digits count
    final digitCountMatches = cleanDigits.length >= meter.digits && cleanDigits.length <= (meter.digits + 2);
    final passedRuleA = isNumeric && digitCountMatches;

    checks.add(RuleCheckOutcome(
      ruleCode: 'A',
      title: 'Format & Digit Count Check',
      passed: passedRuleA,
      severityIfFailed: TrafficLight.red,
      explanation: passedRuleA
          ? 'Reading text contains valid numeric digits matching register specification.'
          : 'Digit count (${cleanDigits.length}) does not match meter register profile (${meter.digits} digits).',
    ));
    if (!passedRuleA) {
      elevate(TrafficLight.red, 'Format mismatch: Incorrect digit length or invalid character.');
    }

    // -------------------------------------------------------------
    // RULE B (Confidence Threshold, P1.3-B / V8)
    // -------------------------------------------------------------
    final overallConf = aiResult.overallConfidence;
    final weakestConf = aiResult.weakestDigitConfidence;
    final effectiveConf = overallConf < weakestConf ? overallConf : weakestConf;

    TrafficLight confidenceSeverity = TrafficLight.green;
    String confExplanation;

    if (effectiveConf >= greenConfidenceThreshold) {
      confidenceSeverity = TrafficLight.green;
      confExplanation = 'AI confidence ${(effectiveConf * 100).toStringAsFixed(1)}% satisfies Green threshold (>= ${(greenConfidenceThreshold * 100).toInt()}%).';
    } else if (effectiveConf >= amberConfidenceThreshold) {
      confidenceSeverity = TrafficLight.amber;
      confExplanation = 'AI confidence ${(effectiveConf * 100).toStringAsFixed(1)}% falls into Amber threshold (needs verification).';
      elevate(TrafficLight.amber, 'Low optical confidence: Weak digit detected (${(weakestConf * 100).toStringAsFixed(0)}%). Verify carefully.');
    } else {
      confidenceSeverity = TrafficLight.red;
      confExplanation = 'AI confidence ${(effectiveConf * 100).toStringAsFixed(1)}% is below Red threshold (< ${(amberConfidenceThreshold * 100).toInt()}%).';
      elevate(TrafficLight.red, 'Untrusted reading: Confidence too low due to optical glare or blur.');
    }

    checks.add(RuleCheckOutcome(
      ruleCode: 'B',
      title: 'Confidence Score & Weakest Digit Check',
      passed: confidenceSeverity == TrafficLight.green,
      severityIfFailed: confidenceSeverity,
      explanation: confExplanation,
    ));

    // -------------------------------------------------------------
    // RULE C (Not Lower Than Previous & Rollover, P1.3-C / V3, V4)
    // -------------------------------------------------------------
    final prev = consumer.previousReading;
    final isLower = currentReading < prev;
    bool isPossibleRollover = false;

    // Check if meter was near 99,999 and rolled over to 00,000
    final maxRegisterVal = (meter.digits == 5) ? 99999.0 : 999999.0;
    if (isLower && prev > (maxRegisterVal * 0.90) && currentReading < 1000.0) {
      isPossibleRollover = true;
    }

    bool passedRuleC = true;
    String ruleCExplanation = 'Current reading ($currentReading) >= previous reading ($prev).';

    if (isLower) {
      if (isMarkedRollover || isPossibleRollover) {
        passedRuleC = true;
        ruleCExplanation = 'Meter rollover detected near register wrap-around ($prev -> $currentReading).';
      } else if (isMarkedMeterReplaced) {
        passedRuleC = true;
        ruleCExplanation = 'Meter was replaced since last billing cycle. New meter reading confirmed.';
      } else {
        passedRuleC = false;
        ruleCExplanation = 'Current reading ($currentReading) is lower than previous reading ($prev).';
        elevate(TrafficLight.amber, 'Current reading is lower than previous ($prev kWh). Rollover or replacement?');
      }
    }

    checks.add(RuleCheckOutcome(
      ruleCode: 'C',
      title: 'Previous Reading Baseline Check',
      passed: passedRuleC,
      severityIfFailed: TrafficLight.amber,
      explanation: ruleCExplanation,
    ));

    // Calculate Units Consumed (taking MF and rollover into account)
    double unitsConsumed = 0.0;
    if (isPossibleRollover || isMarkedRollover) {
      unitsConsumed = (maxRegisterVal - prev + currentReading) * meter.multiplier;
    } else if (isMarkedMeterReplaced) {
      unitsConsumed = currentReading * meter.multiplier;
    } else {
      unitsConsumed = (currentReading - prev) * meter.multiplier;
    }
    if (unitsConsumed < 0) unitsConsumed = 0;

    // -------------------------------------------------------------
    // RULE D (Not Too High / Consumption Spike, P1.3-D / V5)
    // -------------------------------------------------------------
    final avgMonthly = consumer.averageMonthlyConsumption;
    final maxAllowedUnits = avgMonthly * maxConsumptionMultiplier;
    final isSpike = unitsConsumed > maxAllowedUnits || unitsConsumed > absoluteConsumptionCap;

    checks.add(RuleCheckOutcome(
      ruleCode: 'D',
      title: 'Consumption Spike Check (Max 3x Average)',
      passed: !isSpike,
      severityIfFailed: TrafficLight.amber,
      explanation: !isSpike
          ? 'Units consumed ($unitsConsumed kWh) within safe limits (Avg: ${avgMonthly.toStringAsFixed(0)} kWh).'
          : 'Consumption ($unitsConsumed kWh) exceeds 3x 6-month average (${maxAllowedUnits.toStringAsFixed(0)} kWh).',
    ));
    if (isSpike) {
      elevate(TrafficLight.amber, 'Excessive consumption ($unitsConsumed kWh vs normal ${avgMonthly.toStringAsFixed(0)} kWh). Check digits.');
    }

    // -------------------------------------------------------------
    // RULE E (Not Suspiciously Zero, P1.3-E / V6)
    // -------------------------------------------------------------
    final isSuspiciousZero = (unitsConsumed == 0.0 || (currentReading - prev).abs() < 0.1) && avgMonthly >= suspiciousZeroThreshold;

    checks.add(RuleCheckOutcome(
      ruleCode: 'E',
      title: 'Suspicious Zero Consumption Check',
      passed: !isSuspiciousZero,
      severityIfFailed: TrafficLight.amber,
      explanation: !isSuspiciousZero
          ? 'Units consumption is consistent with historical patterns.'
          : 'Zero units recorded on active consumer with historical average of ${avgMonthly.toStringAsFixed(0)} kWh.',
    ));
    if (isSuspiciousZero) {
      elevate(TrafficLight.amber, 'Suspicious zero units recorded. Confirm if premises vacant or meter stopped.');
    }

    // -------------------------------------------------------------
    // RULE F (Missing or Extra Digit Jump, P1.3-F / V7)
    // -------------------------------------------------------------
    bool isDigitJump = false;
    if (prev > 100) {
      final ratio = currentReading / prev;
      if (ratio > 8.0 || ratio < 0.15) {
        // Obvious missing digit or extra digit (e.g. 1234 vs 12340)
        isDigitJump = true;
      }
    }

    checks.add(RuleCheckOutcome(
      ruleCode: 'F',
      title: 'Missing / Extra Digit Jump Check',
      passed: !isDigitJump,
      severityIfFailed: TrafficLight.red,
      explanation: !isDigitJump
          ? 'Reading order of magnitude matches previous billing history.'
          : 'Abnormal decimal or digit shift detected ($prev vs $currentReading). Possible missed digit.',
    ));
    if (isDigitJump) {
      elevate(TrafficLight.red, 'Order of magnitude jump! Possible missed or extra digit.');
    }

    return ValidationResult(
      trafficLight: highestSeverity,
      checks: checks,
      isRolloverDetected: isPossibleRollover || isMarkedRollover,
      isSuspiciousZero: isSuspiciousZero,
      isConsumptionSpike: isSpike,
      isDigitJump: isDigitJump,
      isFormatMismatched: !passedRuleA,
      primaryReason: primaryReason,
    );
  }
}
