import 'package:flutter/material.dart';

/// Normalized Bounding Box coordinates for detected LCD display or digits (Section 9).
class DisplayBox {
  final double x;
  final double y;
  final double w;
  final double h;

  const DisplayBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  Rect toRect() => Rect.fromLTWH(x, y, w, h);

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  factory DisplayBox.fromJson(Map<String, dynamic> json) {
    return DisplayBox(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      w: (json['w'] as num).toDouble(),
      h: (json['h'] as num).toDouble(),
    );
  }
}

/// Standard structured AI result mandated by Section 9 (FR-20, FR-60).
class AiInferenceResult {
  final String status; // 'ok' | 'no_display' | 'unreadable' | 'error'
  final String readingText; // e.g. "012345.6"
  final double readingValue; // e.g. 12345.6
  final List<double> digitConfidences; // [0.99, 0.98, 0.97, 0.95, 0.99, 0.91, 0.88]
  final double overallConfidence; // 0.88
  final DisplayBox displayBox;
  final String meterTypeGuess; // digital_lcd | analog | three_phase | tou
  final String registerGuess; // kWh | kVAh | MDI | peak | offpeak | unknown
  final List<String> qualityFlags; // glare, blur, low_light, tilted
  final String modelVersion;
  final int inferenceMs;

  const AiInferenceResult({
    required this.status,
    required this.readingText,
    required this.readingValue,
    required this.digitConfidences,
    required this.overallConfidence,
    required this.displayBox,
    required this.meterTypeGuess,
    required this.registerGuess,
    required this.qualityFlags,
    required this.modelVersion,
    required this.inferenceMs,
  });

  /// Identifies the weakest digit index and confidence to visually highlight in Amber/Red (FR-19, P1.4 #5).
  int get weakestDigitIndex {
    if (digitConfidences.isEmpty) return -1;
    int minIdx = 0;
    double minVal = digitConfidences[0];
    for (int i = 1; i < digitConfidences.length; i++) {
      if (digitConfidences[i] < minVal) {
        minVal = digitConfidences[i];
        minIdx = i;
      }
    }
    return minIdx;
  }

  double get weakestDigitConfidence {
    if (digitConfidences.isEmpty) return 0.0;
    return digitConfidences[weakestDigitIndex];
  }

  bool get isSuccess => status == 'ok';

  Map<String, dynamic> toJson() => {
    'status': status,
    'reading_text': readingText,
    'reading_value': readingValue,
    'digit_confidences': digitConfidences,
    'overall_confidence': overallConfidence,
    'display_box': displayBox.toJson(),
    'meter_type_guess': meterTypeGuess,
    'register_guess': registerGuess,
    'quality_flags': qualityFlags,
    'model_version': modelVersion,
    'inference_ms': inferenceMs,
  };

  factory AiInferenceResult.fromJson(Map<String, dynamic> json) {
    return AiInferenceResult(
      status: json['status'] as String? ?? 'ok',
      readingText: json['reading_text'] as String? ?? '',
      readingValue: (json['reading_value'] as num?)?.toDouble() ?? 0.0,
      digitConfidences: (json['digit_confidences'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      overallConfidence: (json['overall_confidence'] as num?)?.toDouble() ?? 0.0,
      displayBox: DisplayBox.fromJson(
        Map<String, dynamic>.from(json['display_box'] ?? {'x': 100, 'y': 200, 'w': 300, 'h': 100}),
      ),
      meterTypeGuess: json['meter_type_guess'] as String? ?? 'digital_lcd',
      registerGuess: json['register_guess'] as String? ?? 'kWh',
      qualityFlags: List<String>.from(json['quality_flags'] ?? []),
      modelVersion: json['model_version'] as String? ?? 'detector-v0.3 / ocr-v0.2',
      inferenceMs: (json['inference_ms'] as num?)?.toInt() ?? 1200,
    );
  }
}
