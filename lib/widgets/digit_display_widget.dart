import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

/// Renders detected meter digits with individual confidence chips beneath each digit,
/// highlighting the weakest digit in Amber/Red for rapid reader inspection (FR-19, P1.4 #5).
class DigitDisplayWidget extends StatelessWidget {
  final String readingText;
  final List<double> digitConfidences;
  final int weakestIndex;

  const DigitDisplayWidget({
    super.key,
    required this.readingText,
    required this.digitConfidences,
    required this.weakestIndex,
  });

  @override
  Widget build(BuildContext context) {
    // Parse characters
    final chars = readingText.split('');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'OPTICAL DIGIT CONFIDENCE MAP',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '7-SEGMENT OCR',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Digits row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(chars.length, (i) {
                final char = chars[i];
                final isDecimal = char == '.';
                final double? conf = (i < digitConfidences.length) ? digitConfidences[i] : null;
                final bool isWeakest = i == weakestIndex;

                Color digitColor = AppColors.textPrimaryLight;
                Color chipBg = AppColors.statusGreenBg;
                Color chipText = AppColors.statusGreen;

                if (conf != null) {
                  if (conf < 0.70) {
                    digitColor = AppColors.statusRed;
                    chipBg = AppColors.statusRedBg;
                    chipText = AppColors.statusRed;
                  } else if (conf < 0.90) {
                    digitColor = AppColors.statusAmber;
                    chipBg = AppColors.statusAmberBg;
                    chipText = AppColors.statusAmber;
                  }
                }

                if (isDecimal) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '.',
                      style: GoogleFonts.chivoMono(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isWeakest ? chipBg : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isWeakest ? chipText : const Color(0xFFCBD5E1),
                            width: isWeakest ? 2.0 : 1.0,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          char,
                          style: GoogleFonts.chivoMono(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: digitColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (conf != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: chipBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: chipText.withOpacity(0.3)),
                          ),
                          child: Text(
                            '${(conf * 100).toInt()}%',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: chipText,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
