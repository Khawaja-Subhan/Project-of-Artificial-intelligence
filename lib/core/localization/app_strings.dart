/// Bilingual translation dictionary supporting English and Urdu (FR-58).
/// Note: All energy readings and numerical inputs must retain English digits (0-9)
/// to comply with National Electric Power Regulatory Authority (NEPRA) meter conventions (FR-59).
class AppStrings {
  AppStrings._();

  static bool isUrdu = false;

  // App & General
  static String get appTitle => isUrdu ? 'اے آئی میٹر ریڈنگ سسٹم' : 'DISCO AI Meter Reader';
  static String get discoSubheading => isUrdu ? 'پاکستان پاور ڈسٹری بیوشن کمپنیاں' : 'Pakistan Power Sector MMR System';
  static String get login => isUrdu ? 'لاگ ان کریں' : 'Log In';
  static String get usernameOrMobile => isUrdu ? 'یوزر نیم یا موبائل نمبر' : 'Username or Mobile Number';
  static String get password => isUrdu ? 'پاس ورڈ' : 'Password';
  static String get roleReader => isUrdu ? 'میٹر ریڈر' : 'Meter Reader';
  static String get roleSupervisor => isUrdu ? 'سپروائزر / تصدیق کار' : 'Supervisor / Verifier';
  static String get roleAdmin => isUrdu ? 'ایڈمن / اے آئی ٹیم' : 'Admin & AI Team';

  // Navigation & Tabs
  static String get routeTab => isUrdu ? 'روٹ لسٹ' : 'Today\'s Route';
  static String get queueTab => isUrdu ? 'جائزہ کیو' : 'Review Queue';
  static String get dashboardTab => isUrdu ? 'کارکردگی' : 'Dashboard';
  static String get settingsTab => isUrdu ? 'ترتیبات' : 'Settings';

  // Route & Consumers
  static String get searchPlaceholder => isUrdu ? 'ریفرنس یا میٹر نمبر تلاش کریں...' : 'Search reference or meter no...';
  static String get consumersProgress => isUrdu ? 'مکمل ریڈنگز' : 'Progress';
  static String get pending => isUrdu ? 'زیر التواء' : 'Pending';
  static String get completed => isUrdu ? 'مکمل' : 'Done';
  static String get flagged => isUrdu ? 'مشتبہ' : 'Flagged';
  static String get problem => isUrdu ? 'مسئلہ' : 'Problem';

  // Camera & Capture
  static String get alignMeterGuide => isUrdu ? 'میٹر کی سکرین کو فریم کے اندر رکھیں' : 'Align meter LCD within box guide';
  static String get torch => isUrdu ? 'ٹارچ' : 'Flash';
  static String get capturePhoto => isUrdu ? 'تصویر لیں' : 'Capture';
  static String get testScenarios => isUrdu ? 'ٹیسٹ منظر نامے' : 'Test Scenarios';

  // Live Heuristic Warnings (FR-11)
  static String get hintHoldSteady => isUrdu ? 'فون سیدھا رکھیں' : 'Hold steady';
  static String get hintTooDark => isUrdu ? 'روشنی کم ہے، فلیش آن کریں' : 'Too dark • Flash recommended';
  static String get hintGlare => isUrdu ? 'شیشے پر چمک ہے، زاویہ بدلیں' : 'Glare detected on glass';
  static String get hintBlurry => isUrdu ? 'تصویر دھندلی ہے' : 'Photo blurry • Re-focus';
  static String get hintOptimal => isUrdu ? 'بہترین فریم اور فوکس' : 'Optimal framing & focus';

  // Confirmation & Reading
  static String get readingTitle => isUrdu ? 'میٹر ریڈنگ تصدیق' : 'Meter Reading Confirmation';
  static String get aiReading => isUrdu ? 'اے آئی ریڈنگ (کلو واٹ آور)' : 'AI Detected Reading (kWh)';
  static String get previousReading => isUrdu ? 'سابقہ ریڈنگ' : 'Previous Reading';
  static String get calculatedUnits => isUrdu ? 'استعمال شدہ یونٹ' : 'Calculated Units';
  static String get confirmReading => isUrdu ? 'ریڈنگ کی تصدیق کریں' : 'Confirm Reading';
  static String get editReading => isUrdu ? 'ریڈنگ تبدیل کریں' : 'Edit Value';
  static String get retakePhoto => isUrdu ? 'دوبارہ تصویر لیں' : 'Retake Photo';
  static String get reportProblem => isUrdu ? 'مسئلہ رپورٹ کریں' : 'Report Problem';

  // Status & Traffic Lights
  static String get statusGreenLabel => isUrdu ? 'تصدیق شدہ (سبز)' : 'Auto-Accept Suggestion (Green)';
  static String get statusAmberLabel => isUrdu ? 'چیک درکار (پیلا)' : 'Needs Verification (Amber)';
  static String get statusRedLabel => isUrdu ? 'مشتبہ / غلط (سرخ)' : 'High Risk / Reject (Red)';

  // Sync Status
  static String get syncSavedOffline => isUrdu ? 'فون پر محفوظ (آف لائن)' : 'Saved on Phone (Offline)';
  static String get syncUploading => isUrdu ? 'اپ لوڈ ہو رہا ہے...' : 'Uploading...';
  static String get syncCompleted => isUrdu ? 'سرور پر ہم آہنگ (Synced)' : 'Synced to MMR';
  static String get syncFailed => isUrdu ? 'ناکام (دوبارہ کوشش)' : 'Upload Failed';

  // Supervisor Actions
  static String get supervisorDecision => isUrdu ? 'سپروائزر کا فیصلہ' : 'Supervisor Decision';
  static String get approveAction => isUrdu ? 'منظور کریں' : 'Approve Reading';
  static String get correctAction => isUrdu ? 'درست کریں' : 'Correct Reading';
  static String get rejectAction => isUrdu ? 'رد کریں (دوبارہ تصویر)' : 'Reject for Retake';
  static String get faultyAction => isUrdu ? 'میٹر خراب قرار دیں' : 'Mark Meter Faulty';
}
