import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../state/app_state.dart';

/// Traceable Audit Log viewer displaying historical supervisor adjustments (FR-42).
class AuditLogView extends StatelessWidget {
  final AppState state;

  const AuditLogView({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final logs = state.db.auditLogs;
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('DISCO MMR Audit Trail'),
      ),
      body: logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_rounded, size: 48, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 12),
                  Text(
                    'No supervisory actions logged yet.',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];

                Color actionColor;
                IconData actionIcon;

                switch (log.action) {
                  case 'approved':
                    actionColor = AppColors.statusGreen;
                    actionIcon = Icons.check_circle_rounded;
                    break;
                  case 'corrected':
                    actionColor = AppColors.primary;
                    actionIcon = Icons.edit_note_rounded;
                    break;
                  case 'rejected':
                    actionColor = AppColors.statusAmber;
                    actionIcon = Icons.replay_rounded;
                    break;
                  case 'marked_faulty':
                    actionColor = AppColors.statusRed;
                    actionIcon = Icons.report_problem_rounded;
                    break;
                  case 'edited_by_reader':
                  default:
                    actionColor = const Color(0xFF0284C7);
                    actionIcon = Icons.person_rounded;
                    break;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(actionIcon, size: 16, color: actionColor),
                              const SizedBox(width: 6),
                              Text(
                                log.action.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: actionColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            formatter.format(log.timestamp),
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Consumer: ${log.consumerRef}',
                        style: GoogleFonts.chivoMono(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'User: ${log.user}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Before: ${log.beforeValue}',
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFCBD5E1)),
                            Expanded(
                              child: Text(
                                'After: ${log.afterValue}',
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (log.comment.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Remarks: "${log.comment}"',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
