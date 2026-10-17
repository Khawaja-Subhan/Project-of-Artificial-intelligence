import 'dart:math';
import '../../models/ai_inference_result.dart';
import '../../models/meter_model.dart';
import 'ai_inference_service.dart';

/// Concrete Stub AI module required from Day 1 (FR-60, Section 9).
/// Simulates realistic deep learning inference (object detector + 7-segment OCR)
/// with natural latency, per-digit confidence arrays, bounding boxes, and quality flags.
class StubAiService implements AiInferenceService {
  final Random _random = Random();
  String _modelVersion = 'detector-v0.3 / ocr-v0.2';

  @override
  String get activeModelVersion => _modelVersion;

  void setModelVersion(String version) {
    _modelVersion = version;
  }

  @override
  Future<AiInferenceResult> inferMeterReading({
    dynamic imageSource,
    MeterType meterTypeHint = MeterType.digitalLcd,
    int expectedDigits = 5,
    double? previousReading,
    String? scenarioKey,
  }) async {
    // Simulate mobile GPU/NPU inference latency (Section 11: target under 3 seconds)
    final latency = 900 + _random.nextInt(600); // 900ms - 1500ms
    await Future.delayed(Duration(milliseconds: latency));

    final prev = previousReading ?? 12450.0;

    switch (scenarioKey) {
      case 'glare_ambiguous':
        // Edge Case #1 & #5: Glare on glass, digit looks like 1 vs 7 or 0 vs 8
        final targetVal = prev + 185.0;
        final formattedText = targetVal.toStringAsFixed(1).padLeft(expectedDigits + 2, '0');
        return AiInferenceResult(
          status: 'ok',
          readingText: formattedText,
          readingValue: targetVal,
          digitConfidences: [0.98, 0.96, 0.97, 0.68, 0.95, 0.92], // 4th digit is weak (0.68)
          overallConfidence: 0.74, // Amber range
          displayBox: const DisplayBox(x: 110, y: 320, w: 420, h: 130),
          meterTypeGuess: meterTypeHint == MeterType.analogDrum ? 'analog' : 'digital_lcd',
          registerGuess: 'kWh',
          qualityFlags: const ['glare', 'tilted_angle'],
          modelVersion: _modelVersion,
          inferenceMs: latency,
        );

      case 'spike_high':
        // Rule D: Units > 3x 6-month average
        final targetVal = prev + 890.0;
        final formattedText = targetVal.toStringAsFixed(1).padLeft(expectedDigits + 2, '0');
        return AiInferenceResult(
          status: 'ok',
          readingText: formattedText,
          readingValue: targetVal,
          digitConfidences: [0.99, 0.98, 0.97, 0.96, 0.98, 0.94],
          overallConfidence: 0.96,
          displayBox: const DisplayBox(x: 115, y: 330, w: 410, h: 125),
          meterTypeGuess: 'digital_lcd',
          registerGuess: 'kWh',
          qualityFlags: const [],
          modelVersion: _modelVersion,
          inferenceMs: latency,
        );

      case 'suspicious_zero':
        // Rule E: 0 units when average is high
        final targetVal = prev; // Exactly equal to previous reading
        final formattedText = targetVal.toStringAsFixed(1).padLeft(expectedDigits + 2, '0');
        return AiInferenceResult(
          status: 'ok',
          readingText: formattedText,
          readingValue: targetVal,
          digitConfidences: [0.98, 0.97, 0.99, 0.98, 0.96, 0.95],
          overallConfidence: 0.97,
          displayBox: const DisplayBox(x: 120, y: 335, w: 405, h: 120),
          meterTypeGuess: 'digital_lcd',
          registerGuess: 'kWh',
          qualityFlags: const [],
          modelVersion: _modelVersion,
          inferenceMs: latency,
        );

      case 'rollover':
        // Rule C & V4: Meter wraps around 99999 -> 00024.5
        const targetVal = 24.5;
        final formattedText = '00024.5';
        return AiInferenceResult(
          status: 'ok',
          readingText: formattedText,
          readingValue: targetVal,
          digitConfidences: [0.99, 0.97, 0.98, 0.96, 0.95, 0.92],
          overallConfidence: 0.96,
          displayBox: const DisplayBox(x: 120, y: 340, w: 410, h: 120),
          meterTypeGuess: 'digital_lcd',
          registerGuess: 'kWh',
          qualityFlags: const [],
          modelVersion: _modelVersion,
          inferenceMs: latency,
        );

      case 'missing_digit':
        // Rule F / Rule A: Missing digit jump (e.g., 4 digits instead of 5)
        final targetVal = (prev / 10).floorToDouble() + 12.0;
        final formattedText = targetVal.toStringAsFixed(0);
        return AiInferenceResult(
          status: 'ok',
          readingText: formattedText,
          readingValue: targetVal,
          digitConfidences: [0.91, 0.92, 0.88, 0.85],
          overallConfidence: 0.86,
          displayBox: const DisplayBox(x: 130, y: 340, w: 320, h: 110),
          meterTypeGuess: 'digital_lcd',
          registerGuess: 'kWh',
          qualityFlags: const ['cropped_display'],
          modelVersion: _modelVersion,
          inferenceMs: latency,
        );

      case 'unreadable_blank':
        // Edge case #6 & #21: Blank display or error code E-01
        return AiInferenceResult(
          status: 'unreadable',
          readingText: 'Err-01',
          readingValue: 0.0,
          digitConfidences: const [],
          overallConfidence: 0.15,
          displayBox: const DisplayBox(x: 120, y: 340, w: 400, h: 110),
          meterTypeGuess: 'digital_lcd',
          registerGuess: 'unknown',
          qualityFlags: const ['display_error_code', 'low_contrast'],
          modelVersion: _modelVersion,
          inferenceMs: latency,
        );

      case 'normal_clean':
      default:
        // Standard normal consumption: +160 - +240 units
        final consumedIncrement = 140.0 + _random.nextInt(110) + (_random.nextInt(10) / 10.0);
        final targetVal = prev + consumedIncrement;
        final formattedText = targetVal.toStringAsFixed(1).padLeft(expectedDigits + 2, '0');
        return AiInferenceResult(
          status: 'ok',
          readingText: formattedText,
          readingValue: targetVal,
          digitConfidences: [0.99, 0.98, 0.97, 0.95, 0.99, 0.96],
          overallConfidence: 0.96, // Green range >= 0.90
          displayBox: const DisplayBox(x: 120, y: 340, w: 410, h: 120),
          meterTypeGuess: meterTypeHint == MeterType.analogDrum ? 'analog' : 'digital_lcd',
          registerGuess: 'kWh',
          qualityFlags: const [],
          modelVersion: _modelVersion,
          inferenceMs: latency,
        );
    }
  }
}
