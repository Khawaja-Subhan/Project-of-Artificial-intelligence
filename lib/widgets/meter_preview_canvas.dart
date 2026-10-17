import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../models/ai_inference_result.dart';

/// Highly authentic custom-painted Pakistani electricity meter representation.
/// Renders standard single-phase electronic meters (e.g., MicroTech Industries / PEL / Accurate)
/// with authentic LCD display, optical impulse LED, DISCO seal, and scenario artifacts.
class MeterPreviewCanvas extends StatelessWidget {
  final String readingText;
  final String meterSerial;
  final String discoName;
  final String scenarioKey;
  final DisplayBox? detectedBox;
  final bool showBoundingBox;
  final bool isCaptured;

  const MeterPreviewCanvas({
    super.key,
    required this.readingText,
    required this.meterSerial,
    this.discoName = 'LESCO (Lahore)',
    this.scenarioKey = 'normal_clean',
    this.detectedBox,
    this.showBoundingBox = true,
    this.isCaptured = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF263238), // Dark utility casing
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Meter Outer Chassis & Paint
          CustomPaint(
            painter: _ChassisPainter(
              meterSerial: meterSerial,
              discoName: discoName,
            ),
          ),

          // Central LCD Screen Area
          Center(
            child: Container(
              width: 270,
              height: 110,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scenarioKey == 'unreadable_blank'
                    ? const Color(0xFF4A5568)
                    : AppColors.lcdBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1F2937), width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 6,
                    offset: Offset(2, 2),
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL ACTIVE',
                        style: GoogleFonts.robotoMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.lcdDigitActive.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        'kWh',
                        style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.lcdDigitActive,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // 7-Segment Digital Readout
                  Text(
                    scenarioKey == 'unreadable_blank' ? 'Err-01' : readingText,
                    style: GoogleFonts.chivoMono(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: scenarioKey == 'unreadable_blank'
                          ? Colors.redAccent
                          : AppColors.lcdDigitActive,
                    ),
                  ),
                  const Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '1600 imp/kWh',
                            style: GoogleFonts.robotoMono(
                              fontSize: 8,
                              color: AppColors.lcdDigitActive.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '230V 10(40)A 50Hz',
                        style: GoogleFonts.robotoMono(
                          fontSize: 8,
                          color: AppColors.lcdDigitActive.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Glare Overlay Simulation
          if (scenarioKey == 'glare_ambiguous')
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: const Alignment(-0.8, -0.8),
                      end: const Alignment(0.6, 0.6),
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.45),
                        Colors.white.withOpacity(0.65),
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.2, 0.45, 0.55, 0.8],
                    ),
                  ),
                ),
              ),
            ),

          // Low-Light Shadow Simulation
          if (scenarioKey == 'low_light')
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black.withOpacity(0.65),
                  ),
                ),
              ),
            ),

          // Detected LCD Region Bounding Box Overlay (FR-30, Section 9)
          if (showBoundingBox)
            Center(
              child: Container(
                width: 280,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF10B981), // Bright Emerald Box
                    width: 2.5,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 4,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ROI: LCD DISPLAY (99.4%)',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChassisPainter extends CustomPainter {
  final String meterSerial;
  final String discoName;

  _ChassisPainter({required this.meterSerial, required this.discoName});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      borderPaint,
    );

    // Draw Utility Screws / Seals in Corners
    final screwPaint = Paint()..color = const Color(0xFF78909C);
    canvas.drawCircle(const Offset(20, 20), 5, screwPaint);
    canvas.drawCircle(Offset(size.width - 20, 20), 5, screwPaint);
    canvas.drawCircle(Offset(20, size.height - 20), 5, screwPaint);
    canvas.drawCircle(Offset(size.width - 20, size.height - 20), 5, screwPaint);

    // Header Stamp: DISCO Title
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'WAPDA / $discoName - DIGITAL MMR',
        style: const TextStyle(
          color: Color(0xFFECEFF1),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, 22));

    // Serial Number at Bottom
    final serialPainter = TextPainter(
      text: TextSpan(
        text: 'METER NO: $meterSerial',
        style: const TextStyle(
          color: Color(0xFFB0BEC5),
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    serialPainter.paint(canvas, Offset((size.width - serialPainter.width) / 2, size.height - 35));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
