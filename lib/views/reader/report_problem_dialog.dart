import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/consumer_model.dart';

/// Modal dialog allowing field readers to report on-site exceptions and meter faults (FR-32, Section 8.3).
class ReportProblemDialog extends StatefulWidget {
  final ConsumerModel consumer;
  final Future<void> Function(String code, String? note) onReport;

  const ReportProblemDialog({
    super.key,
    required this.consumer,
    required this.onReport,
  });

  @override
  State<ReportProblemDialog> createState() => _ReportProblemDialogState();
}

class _ReportProblemDialogState extends State<ReportProblemDialog> {
  String _selectedCode = AppConstants.problemCodes.first;
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.report_problem_rounded, color: AppColors.statusRed, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Report Site Exception',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select official DISCO meter status exception code for ${widget.consumer.referenceNo}:',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _selectedCode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Exception Reason Code'),
              items: AppConstants.problemCodes.map((code) {
                return DropdownMenuItem(
                  value: code,
                  child: Text(
                    code,
                    style: GoogleFonts.inter(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCode = val);
              },
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Field Remarks / Note (Optional)',
                hintText: 'e.g. Consumer not available, premises locked since morning.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusRed),
          onPressed: _isSubmitting
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  await widget.onReport(
                    _selectedCode,
                    _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
                  );
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
