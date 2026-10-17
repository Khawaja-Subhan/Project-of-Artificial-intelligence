import 'package:flutter/material.dart';

/// Centralized color palette tailored for Pakistan Power Distribution Companies (DISCOs).
/// Uses professional emerald green tones aligned with official power sector branding,
/// accompanied by high-contrast traffic-light status indicators.
class AppColors {
  AppColors._();

  // Primary DISCO Brand Palette (Inspired by Pakistan National Power Identity)
  static const Color primary = Color(0xFF004D40); // Deep Emerald
  static const Color primaryLight = Color(0xFF00796B);
  static const Color primaryDark = Color(0xFF00251A);
  static const Color secondary = Color(0xFF0284C7); // Utility Blue
  static const Color accent = Color(0xFF10B981); // Bright Mint

  // Background & Surface
  static const Color surfaceLight = Color(0xFFF8FAFC);
  static const Color cardLight = Colors.white;
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF1E293B);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Traffic Light Status Colors (Mandated by Section P1.3 / FR-27)
  static const Color statusGreen = Color(0xFF059669); // Auto-accept / Safe (Confidence >= 0.90)
  static const Color statusGreenBg = Color(0xFFECFDF5);
  static const Color statusAmber = Color(0xFFD97706); // Requires Check / Warning (0.70 - 0.89)
  static const Color statusAmberBg = Color(0xFFFFFBEB);
  static const Color statusRed = Color(0xFFDC2626);   // Escalated / Critical (< 0.70)
  static const Color statusRedBg = Color(0xFFFEF2F2);

  // Meter LCD Screen Colors (Authentic 7-Segment Green/Amber Backlight)
  static const Color lcdBackground = Color(0xFF8BA888);
  static const Color lcdDigitActive = Color(0xFF1A2619);
  static const Color lcdDigitGhost = Color(0x221A2619);
  static const Color lcdBacklightBlue = Color(0xFFBCE3F5);

  // Border & Divider
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);
}
