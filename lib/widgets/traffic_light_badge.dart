import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../models/validation_result.dart';

/// Interactive Traffic-Light Status Badge with expandable business rule audit sheet (FR-27, P1.3).
class TrafficLightBadge extends StatefulWidget {
  final ValidationResult validation;
  final bool initiallyExpanded;

  const TrafficLightBadge({
    super.key,
    required this.validation,
    this.initiallyExpanded = false,
  });

  @override
  State<TrafficLightBadge> createState() => _TrafficLightBadgeState();
}

class _TrafficLightBadgeState extends State<TrafficLightBadge> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color bgColor;
    IconData icon;
    String title;
    String subtitle;

    switch (widget.validation.trafficLight) {
      case TrafficLight.green:
        badgeColor = AppColors.statusGreen;
        bgColor = AppColors.statusGreenBg;
        icon = Icons.check_circle_rounded;
        title = 'GREEN: AUTO-ACCEPT SUGGESTION';
        subtitle = 'All 6 validation rules passed. Reader can tap confirm directly.';
        break;
      case TrafficLight.amber:
        badgeColor = AppColors.statusAmber;
        bgColor = AppColors.statusAmberBg;
        icon = Icons.warning_rounded;
        title = 'AMBER: VERIFICATION REQUIRED';
        subtitle = widget.validation.primaryReason;
        break;
      case TrafficLight.red:
        badgeColor = AppColors.statusRed;
        bgColor = AppColors.statusRedBg;
        icon = Icons.cancel_rounded;
        title = 'RED: REJECT / ESCALATE TO SDO';
        subtitle = widget.validation.primaryReason;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: badgeColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: badgeColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: badgeColor,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Rule Outcomes
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  const Divider(color: Color(0xFFCBD5E1), height: 1),
                  const SizedBox(height: 8),
                  ...widget.validation.checks.map((check) {
                    final color = check.passed ? AppColors.statusGreen : AppColors.statusRed;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            check.passed ? Icons.check_circle_outline : Icons.error_outline,
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rule ${check.ruleCode}: ${check.title}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  check.explanation,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
