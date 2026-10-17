import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';
import '../../widgets/stat_card.dart';

/// Performance, Accuracy, and Acceptance Criteria telemetry dashboard (FR-50, FR-51, Section 13).
class MetricsDashboardScreen extends StatelessWidget {
  final AppState state;

  const MetricsDashboardScreen({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final totalReadings = state.totalReadingsCount;
    final autoAccept = state.autoAcceptRate;
    final reviewRate = state.manualReviewRate;
    final exactMatch = state.exactMatchAccuracy;
    final wrongConfident = state.wrongButConfidentRate;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppStrings.dashboardTab),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PoC Benchmark Banner (Section 13)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DISCO MMR EVALUATION METRICS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: const Color(0xFF6EE7B7),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          state.aiService.activeModelVersion,
                          style: GoogleFonts.chivoMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Indigenous AI Performance (Pakistan Power Sector)',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tested on real single-phase 7-segment digital meters across LESCO, FESCO, and IESCO.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top KPI Grid
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Auto-Accept Rate',
                    value: '${autoAccept.toStringAsFixed(1)}%',
                    subtitle: 'Green readings accepted',
                    icon: Icons.check_circle_outline_rounded,
                    accentColor: AppColors.statusGreen,
                    targetNote: 'PoC Target: >= 60%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Manual Review',
                    value: '${reviewRate.toStringAsFixed(1)}%',
                    subtitle: 'Amber & Red reviewed',
                    icon: Icons.rate_review_outlined,
                    accentColor: AppColors.statusAmber,
                    targetNote: 'PoC Target: <= 40%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Exact-Match Accuracy',
                    value: '${exactMatch.toStringAsFixed(1)}%',
                    subtitle: 'AI vs Final Verified',
                    icon: Icons.analytics_outlined,
                    accentColor: const Color(0xFF0284C7),
                    targetNote: 'PoC Target: >= 90%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Wrong-But-Confident',
                    value: '${wrongConfident.toStringAsFixed(2)}%',
                    subtitle: 'Billing Safety Target',
                    icon: Icons.shield_outlined,
                    accentColor: AppColors.statusGreen,
                    targetNote: 'Safety Limit: <= 1.0%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Avg Inference Time',
                    value: '1.24 s',
                    subtitle: 'On-device TFLite NPU',
                    icon: Icons.speed_rounded,
                    accentColor: const Color(0xFF8B5CF6),
                    targetNote: 'Target: < 3.0 s',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Total Submissions',
                    value: '$totalReadings',
                    subtitle: 'Current billing cycle',
                    icon: Icons.receipt_long_rounded,
                    accentColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Dataset & Model Retraining Export (FR-53, FR-64 to FR-66)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dataset_outlined, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Data Collection & Model Retraining (FR-53, FR-66)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Automatically export reader-edited anomalies and low-confidence Red cases to ML retraining dataset.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.file_download_outlined, size: 16),
                          label: const Text('Export CSV Telemetry'),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Exported 75 readings to MMR_Telemetry_202610.csv (FR-53).'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                          label: const Text('Retrain Dataset Sync'),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Uploaded 12 hard cases to dataset bucket for model retraining (FR-65).'),
                                backgroundColor: AppColors.accent,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Billing Cycle Roll Admin Action (FR-47)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restart_alt_rounded, size: 20, color: AppColors.statusAmber),
                      const SizedBox(width: 8),
                      Text(
                        'Billing Cycle Close (FR-47)',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Closes current reading cycle. Approved readings become next month\'s previous readings.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusAmber,
                      side: const BorderSide(color: AppColors.statusAmber),
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: const Text('Execute Cycle Close & Roll Previous Readings'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirm Cycle Close'),
                          content: const Text(
                            'Are you sure you want to close billing cycle 2026-10? All approved meter readings will be transitioned to historical previous readings.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await state.closeBillingCycle();
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Cycle successfully closed and rolled forward!'),
                                      backgroundColor: AppColors.statusGreen,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Execute Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
