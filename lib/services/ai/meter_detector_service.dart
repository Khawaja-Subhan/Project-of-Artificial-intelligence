import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Structured result of the YOLO11n-OBB meter display detector.
class MeterDetectionResult {
  final bool found;
  final int? classIndex; // 0 = digital_display, 1 = analog_display
  final String? className;
  final double confidence;
  final String decision; // "Accepted", "Uncertain, manual check", or "No meter found, retake"
  final int inferenceTimeMs;
  final int numBoxesFound;
  final String? annotatedImagePath;
  final String? croppedImagePath;
  final Uint8List? imageBytes;
  final Uint8List? annotatedImageBytes;
  final Uint8List? croppedImageBytes;
  final List<Offset> corners;
  final String? message;
  final String? error;

  const MeterDetectionResult({
    required this.found,
    this.classIndex,
    this.className,
    this.confidence = 0.0,
    required this.decision,
    this.inferenceTimeMs = 0,
    this.numBoxesFound = 0,
    this.annotatedImagePath,
    this.croppedImagePath,
    this.imageBytes,
    this.annotatedImageBytes,
    this.croppedImageBytes,
    this.corners = const [],
    this.message,
    this.error,
  });

  bool get isDigital => classIndex == 0;
  bool get isAnalog => classIndex == 1;

  factory MeterDetectionResult.fromMap(Map<dynamic, dynamic> map, {Uint8List? rawBytes}) {
    final bool found = map['found'] == true;
    final List<dynamic>? rawCorners = map['corners'] as List<dynamic>?;
    final List<Offset> parsedCorners = [];
    if (rawCorners != null) {
      for (final pt in rawCorners) {
        if (pt is Map) {
          final x = (pt['x'] as num?)?.toDouble() ?? 0.0;
          final y = (pt['y'] as num?)?.toDouble() ?? 0.0;
          parsedCorners.add(Offset(x, y));
        }
      }
    }

    Uint8List? annBytes;
    if (map['annotatedImageBase64'] != null) {
      try {
        annBytes = base64Decode(map['annotatedImageBase64'] as String);
      } catch (_) {}
    }

    Uint8List? crpBytes;
    if (map['cropImageBase64'] != null) {
      try {
        crpBytes = base64Decode(map['cropImageBase64'] as String);
      } catch (_) {}
    }

    return MeterDetectionResult(
      found: found,
      classIndex: map['cls'] as int?,
      className: map['className'] as String?,
      confidence: (map['conf'] as num?)?.toDouble() ?? 0.0,
      decision: (map['decision'] as String?) ?? (found ? 'Accepted' : 'No meter found, retake'),
      inferenceTimeMs: (map['inferenceTimeMs'] as num?)?.toInt() ?? 0,
      numBoxesFound: (map['numBoxesFound'] as num?)?.toInt() ?? (found ? 1 : 0),
      annotatedImagePath: map['annotatedImagePath'] as String?,
      croppedImagePath: map['croppedImagePath'] as String?,
      imageBytes: rawBytes,
      annotatedImageBytes: annBytes,
      croppedImageBytes: crpBytes,
      corners: parsedCorners,
      message: map['message'] as String?,
      error: map['error'] as String?,
    );
  }

  factory MeterDetectionResult.empty({
    String? message,
    String? error,
    Uint8List? rawBytes,
  }) {
    return MeterDetectionResult(
      found: false,
      decision: 'No meter found, retake',
      message: message ?? 'No meter display detected in image',
      error: error,
      imageBytes: rawBytes,
    );
  }
}

enum SampleMeterType {
  digitalSinglePhase,
  analogThreePhase,
  tiltedDigital,
  analogSecond,
  digitalSecond,
}

/// Service bridging the Flutter application to the YOLO11n-OBB MeterDetector.
/// - On physical Android: routes through native Kotlin TFLite + OpenCV via MethodChannel.
/// - On Web / Localhost / Desktop: connects to the real Python TFLite server (http://127.0.0.1:5050).
/// ZERO hardcoded or simulated values.
class MeterDetectorService {
  static const MethodChannel _channel = MethodChannel('pk.gov.power.disco_meter_reader/meter_detector');
  final ImagePicker _picker = ImagePicker();

  static const String serverUrl = 'http://127.0.0.1:5050/detect';

  /// Launches photo picker (browser file picker on web, system gallery on Android).
  Future<XFile?> pickImageFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 95,
      );
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Launches camera intent on native devices (opens live webcam on web).
  Future<XFile?> captureImageWithCamera() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 95,
      );
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Runs real YOLO11n-OBB inference on the given image.
  Future<MeterDetectionResult> detectMeter({
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    // 1. If running on physical Android device with native path, invoke native Kotlin detector
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && imagePath != null) {
      try {
        final dynamic raw = await _channel.invokeMethod('detectMeter', {'imagePath': imagePath});
        if (raw is Map) {
          return MeterDetectionResult.fromMap(raw, rawBytes: imageBytes);
        }
      } catch (e) {
        debugPrint('Android MethodChannel call failed, trying server fallback: $e');
      }
    }

    // 2. Client-side / Web / Server-backed Real TFLite Engine
    if (imageBytes == null || imageBytes.isEmpty) {
      return MeterDetectionResult.empty(message: 'No image data provided for meter detection');
    }

    try {
      final uri = Uri.parse('$serverUrl?conf=0.25');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/octet-stream',
        },
        body: imageBytes,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return MeterDetectionResult.fromMap(data, rawBytes: imageBytes);
      } else {
        return MeterDetectionResult.empty(
          message: 'Server returned HTTP ${response.statusCode}: ${response.body}',
          error: 'HTTP ${response.statusCode}',
          rawBytes: imageBytes,
        );
      }
    } catch (e) {
      return MeterDetectionResult.empty(
        message: 'TFLite inference service error ($e). Ensure meter_server.py is running on http://127.0.0.1:5050.',
        error: e.toString(),
        rawBytes: imageBytes,
      );
    }
  }

  /// Loads real electricity meter photos from the dataset for testing.
  Future<Uint8List> loadSampleMeterImage(SampleMeterType type) async {
    String assetPath;
    switch (type) {
      case SampleMeterType.digitalSinglePhase:
        assetPath = 'assets/sample_meters/digital_meter_1.jpg';
        break;
      case SampleMeterType.analogThreePhase:
        assetPath = 'assets/sample_meters/analog_meter_1.jpg';
        break;
      case SampleMeterType.tiltedDigital:
        assetPath = 'assets/sample_meters/digital_tilted.jpg';
        break;
      case SampleMeterType.analogSecond:
        assetPath = 'assets/sample_meters/analog_meter_2.jpg';
        break;
      case SampleMeterType.digitalSecond:
        assetPath = 'assets/sample_meters/digital_meter_2.jpg';
        break;
    }

    final byteData = await rootBundle.load(assetPath);
    return byteData.buffer.asUint8List();
  }
}
