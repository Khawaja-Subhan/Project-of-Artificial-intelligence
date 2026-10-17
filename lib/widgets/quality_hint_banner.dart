import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Live optical quality heuristic banner displayed during camera framing (FR-11).
class QualityHintBanner extends StatelessWidget {
  final String scenarioKey;
  final bool isTorchOn;

  const QualityHintBanner({
    super.key,
    required this.scenarioKey,
    required this.isTorchOn,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.check_circle_outline_rounded;
    Color color = const Color(0xFF10B981); // Bright Emerald
    String message = 'Optimal Focus & Lighting • Ready to Capture';

    switch (scenarioKey) {
      case 'glare_ambiguous':
        icon = Icons.flare_rounded;
        color = const Color(0xFFF59E0B);
        message = 'Glare detected on meter glass cover • Tilt slightly';
        break;
      case 'low_light':
        icon = Icons.nightlight_round;
        color = isTorchOn ? const Color(0xFF10B981) : const Color(0xFFEF4444);
        message = isTorchOn
            ? 'Flash active • Good illumination'
            : 'Too dark in meter enclosure • Flash recommended';
        break;
      case 'missing_digit':
        icon = Icons.crop_free_rounded;
        color = const Color(0xFFF59E0B);
        message = 'Partial display cut off • Center LCD inside yellow frame';
        break;
      case 'unreadable_blank':
        icon = Icons.error_outline_rounded;
        color = const Color(0xFFEF4444);
        message = 'Display unreadable / Blank screen • Use Report Problem';
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.8), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
