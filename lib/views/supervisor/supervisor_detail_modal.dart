import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/consumer_model.dart';
import '../../models/meter_model.dart';
import '../../models/reading_model.dart';
import '../../state/app_state.dart';
import '../../widgets/meter_preview_canvas.dart';

/// Comprehensive supervisory adjudication sheet for evaluating flagged readings (FR-40 to FR-44).
class SupervisorDetailModal extends StatefulWidget {
  final AppState state;
  final ReadingModel reading;
  final ConsumerModel? consumer;
  final MeterModel? meter;

  const SupervisorDetailModal({
    super.key,
    required this.state,
    required this.reading,
    this.consumer,
    this.meter,
  });

  @override
  State<SupervisorDetailModal> createState() => _SupervisorDetailModalState();
}

class _SupervisorDetailModalState extends State<SupervisorDetailModal> {
  final _commentController = TextEditingController();
  final _correctionController = TextEditingController();
  bool _isCorrecting = false;

  @override
  void initState() {
    super.initState();
    _correctionController.text = widget.reading.finalValue.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _correctionController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    await widget.state.supervisorApproveReading(
      widget.reading,
      _commentController.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reading approved and verified for billing calculation.'),
        backgroundColor: AppColors.statusGreen,
      ),
    );
  }

  Future<void> _correct() async {
    final parsed = double.tryParse(_correctionController.text.trim());
    if (parsed == null) return;

    await widget.state.supervisorCorrectReading(
      reading: widget.reading,
      newValue: parsed,
      comment: _commentController.text.trim().isEmpty
          ? 'Supervisor corrected optical misread'
          : _commentController.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Corrected reading saved to DISCO billing records.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _reject() async {
    await widget.state.supervisorRejectReading(
      widget.reading,
      _commentController.text.trim().isEmpty
          ? 'Returned to meter reader for physical photo re-take'
          : _commentController.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reading rejected. Returned to reader app as task (FR-43).'),
        backgroundColor: AppColors.statusAmber,
      ),
    );
  }

  Future<void> _markFaulty() async {
    await widget.state.supervisorMarkFaulty(
      widget.reading,
      _commentController.text.trim().isEmpty
          ? 'Meter marked defective / meter test replacement ordered'
          : _commentController.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meter flagged defective in MMR system (FR-41).'),
        backgroundColor: AppColors.statusRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consumer;
    final m = widget.meter;
    final prev = c?.previousReading ?? 0.0;
    final history = c?.past6MonthsConsumption ?? [180, 200, 190, 220, 210, 195];

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Modal Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Supervisor Inspection & Verification',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9), height: 1),

              // Body Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Consumer Summary
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c?.name ?? 'Consumer Name',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ref: ${c?.referenceNo ?? 'N/A'} • Tariff: ${c?.tariffCategory ?? 'Domestic'}',
                            style: GoogleFonts.chivoMono(fontSize: 12, color: AppColors.textSecondaryLight),
                          ),
                          Text(
                            c?.address ?? '',
                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // High-Res Photo & Display Inspection (FR-44)
                    MeterPreviewCanvas(
                      readingText: widget.reading.finalValue.toStringAsFixed(1),
                      meterSerial: m?.meterNo ?? widget.reading.meterId,
                      showBoundingBox: true,
                    ),
                    const SizedBox(height: 14),

                    // Optical Detection Summary
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'AI READING',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight),
                              ),
                              Text(
                                '${widget.reading.aiValue.toStringAsFixed(1)} kWh',
                                style: GoogleFonts.chivoMono(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 30, color: const Color(0xFFCBD5E1)),
                          Column(
                            children: [
                              Text(
                                'READER ENTERED',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight),
                              ),
                              Text(
                                '${widget.reading.finalValue.toStringAsFixed(1)} kWh',
                                style: GoogleFonts.chivoMono(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 30, color: const Color(0xFFCBD5E1)),
                          Column(
                            children: [
                              Text(
                                'PREVIOUS RECORD',
                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight),
                              ),
                              Text(
                                '${prev.toStringAsFixed(1)} kWh',
                                style: GoogleFonts.chivoMono(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Historical 6-Month Consumption Bar Chart
                    Text(
                      'HISTORICAL 6-MONTH CONSUMPTION PATTERN (kWh)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(history.length, (idx) {
                          final units = history[idx];
                          final height = (units / 400.0 * 80).clamp(16.0, 90.0);
                          final monthLabel = 'M-${6 - idx}';
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${units.toInt()}',
                                style: GoogleFonts.chivoMono(fontSize: 9.5, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 22,
                                height: height,
                                decoration: BoxDecoration(
                                  color: idx == history.length - 1
                                      ? AppColors.primary
                                      : const Color(0xFF94A3B8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                monthLabel,
                                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondaryLight),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Supervisor Remarks & Comments Field (FR-42)
                    TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        labelText: 'Supervisor Adjudication Remarks (Mandatory for Audit)',
                        hintText: 'e.g. Verified against meter snap; optical reading accepted.',
                      ),
                    ),
                    const SizedBox(height: 12),

                    // If Supervisor chooses to Correct Value
                    if (_isCorrecting) ...[
                      TextField(
                        controller: _correctionController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Corrected Final Reading (kWh)',
                          suffixText: 'kWh',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action Decisions (FR-41)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusGreen),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Approve Reading'),
                            onPressed: _approve,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(_isCorrecting ? Icons.save_rounded : Icons.edit_rounded, size: 18),
                            label: Text(_isCorrecting ? 'Save Value' : 'Correct Value'),
                            onPressed: () {
                              if (_isCorrecting) {
                                _correct();
                              } else {
                                setState(() => _isCorrecting = true);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.statusAmber,
                              side: const BorderSide(color: AppColors.statusAmber),
                            ),
                            icon: const Icon(Icons.replay_rounded, size: 18),
                            label: const Text('Reject for Retake'),
                            onPressed: _reject,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.statusRed,
                              side: const BorderSide(color: AppColors.statusRed),
                            ),
                            icon: const Icon(Icons.broken_image_rounded, size: 18),
                            label: const Text('Mark Faulty'),
                            onPressed: _markFaulty,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
