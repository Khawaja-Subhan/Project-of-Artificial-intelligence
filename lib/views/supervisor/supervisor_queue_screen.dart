import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/reading_model.dart';
import '../../models/validation_result.dart';
import '../../state/app_state.dart';
import 'audit_log_view.dart';
import 'supervisor_detail_modal.dart';

/// Supervisor Verification Queue screen (FR-40, FR-41, P1.2 #9).
/// Displays flagged readings (Amber/Red/Problem) requiring human supervisory intervention.
class SupervisorQueueScreen extends StatelessWidget {
  final AppState state;

  const SupervisorQueueScreen({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final queue = state.supervisorQueue;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppStrings.queueTab),
        actions: [
          IconButton(
            tooltip: 'View Audit Logs',
            icon: const Icon(Icons.history_edu_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AuditLogView(state: state),
                ),
              );
            },
          ),
        ],
      ),
      body: queue.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.statusGreenBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        size: 48,
                        color: AppColors.statusGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verification Queue Clear',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'All readings in this batch are verified and approved.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final reading = queue[index];
                final consumer = state.db.getConsumerById(reading.consumerId);
                final meter = state.db.getMeterById(reading.meterId);

                return _QueueItemCard(
                  reading: reading,
                  consumerName: consumer?.name ?? 'Unknown Consumer',
                  referenceNo: consumer?.referenceNo ?? 'N/A',
                  meterNo: meter?.meterNo ?? reading.meterId,
                  previousReading: consumer?.previousReading ?? 0.0,
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SupervisorDetailModal(
                        state: state,
                        reading: reading,
                        consumer: consumer,
                        meter: meter,
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _QueueItemCard extends StatelessWidget {
  final ReadingModel reading;
  final String consumerName;
  final String referenceNo;
  final String meterNo;
  final double previousReading;
  final VoidCallback onTap;

  const _QueueItemCard({
    required this.reading,
    required this.consumerName,
    required this.referenceNo,
    required this.meterNo,
    required this.previousReading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    Color badgeBg;
    String badgeTitle;

    if (reading.status == ReadingStatus.problem) {
      badgeColor = AppColors.statusRed;
      badgeBg = AppColors.statusRedBg;
      badgeTitle = 'SITE EXCEPTION: ${reading.problemCode ?? "Reported Problem"}';
    } else if (reading.trafficLight == TrafficLight.red) {
      badgeColor = AppColors.statusRed;
      badgeBg = AppColors.statusRedBg;
      badgeTitle = 'HIGH RISK (RED): OCR / JUMP ANOMALY';
    } else {
      badgeColor = AppColors.statusAmber;
      badgeBg = AppColors.statusAmberBg;
      badgeTitle = 'CHECK REQUIRED (AMBER): CONFIDENCE / SPIKE';
    }

    final double units = (reading.finalValue - previousReading).clamp(0.0, 99999.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    badgeTitle,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Consumer details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            consumerName,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                          Text(
                            '$referenceNo • $meterNo',
                            style: GoogleFonts.chivoMono(
                              fontSize: 11.5,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                  ],
                ),
                const Divider(color: Color(0xFFF1F5F9), height: 20),

                // Value Comparison
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI READING',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),
                        ),
                        Text(
                          '${reading.aiValue.toStringAsFixed(1)} kWh',
                          style: GoogleFonts.chivoMono(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SUBMITTED VALUE',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),
                        ),
                        Text(
                          '${reading.finalValue.toStringAsFixed(1)} kWh',
                          style: GoogleFonts.chivoMono(fontSize: 14, fontWeight: FontWeight.w800, color: badgeColor),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'UNITS',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondaryLight),
                        ),
                        Text(
                          '${units.toStringAsFixed(1)} kWh',
                          style: GoogleFonts.chivoMono(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
