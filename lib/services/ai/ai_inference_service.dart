import '../../models/ai_inference_result.dart';
import '../../models/meter_model.dart';

/// Clean Replaceable AI Inference Interface (Section 9, FR-60, FR-61).
/// All AI backends (Stub mock, on-device TFLite/ONNX, or cloud fallback REST API)
/// implement this single interface so switching requires modifying only one module.
abstract class AiInferenceService {
  /// Analyzes an image and returns a structured AI reading result.
  ///
  /// [imageBytes] or [imagePath]: Raw photo captured by the camera.
  /// [meterTypeHint]: Expected meter type (e.g. single-phase digital LCD).
  /// [expectedDigits]: Number of digits registered on the meter.
  /// [previousReading]: Last known reading to assist optical disambiguation.
  Future<AiInferenceResult> inferMeterReading({
    dynamic imageSource,
    MeterType meterTypeHint = MeterType.digitalLcd,
    int expectedDigits = 5,
    double? previousReading,
    String? scenarioKey,
  });

  /// Name and version identifier of the active inference engine.
  String get activeModelVersion;
}
