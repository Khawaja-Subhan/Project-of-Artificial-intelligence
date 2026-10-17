/// System constants including Pakistan DISCO definitions, standard meter problem codes,
/// and baseline validation thresholds as specified in Section P1.3 & Section 8.3.
class AppConstants {
  AppConstants._();

  // Active DISCOs across Pakistan Power Sector
  static const List<String> discos = [
    'LESCO (Lahore)',
    'IESCO (Islamabad)',
    'FESCO (Faisalabad)',
    'GEPCO (Gujranwala)',
    'MEPCO (Multan)',
    'PESCO (Peshawar)',
    'HESCO (Hyderabad)',
    'SEPCO (Sukkur)',
    'QESCO (Quetta)',
    'TESCO (Tribal Areas)',
  ];

  // Standard Meter Problem Codes for Field Readers (FR-32, Section 8.3)
  static const List<String> problemCodes = [
    'Door / Gate Locked',
    'Premises Vacant / Abandoned',
    'Meter Not Found on Site',
    'Meter Inside Premises - Access Denied',
    'Display Blank or Error (E-01/Err)',
    'Meter Burnt or Physically Damaged',
    'Meter Glass Broken / Seal Tampered',
    'Suspected Tampering / Direct Bypass',
    'Wrong Meter Number Installed',
    'Dangerous Location (Aggressive Dog / Height)',
    'Meter Submerged in Water / Flooded',
    'Other Problem (Note Required)',
  ];

  // Default Validation Thresholds (Admin Configurable FR-28 / Section 7)
  static const double defaultGreenConfidenceThreshold = 0.90;
  static const double defaultAmberConfidenceThreshold = 0.70;
  static const double defaultMaxConsumptionMultiplier = 3.0; // 3x 6-month average (Rule D)
  static const double defaultAbsoluteConsumptionCap = 2500.0; // Fixed upper limit in kWh
  static const double defaultSuspiciousZeroThreshold = 40.0; // If avg > 40 units and curr == 0 (Rule E)

  // Demo Model Versions
  static const String currentModelVersion = 'detector-v0.3 / ocr-v0.2';
  static const String baselineModelVersion = 'detector-v0.1 / ocr-baseline';
}
