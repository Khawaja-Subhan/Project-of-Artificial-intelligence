import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../models/ai_inference_result.dart';
import '../../models/consumer_model.dart';
import '../../models/meter_model.dart';
import '../../models/validation_result.dart';
import '../../state/app_state.dart';
import '../../widgets/digit_display_widget.dart';
import '../../widgets/meter_preview_canvas.dart';
import '../../widgets/traffic_light_badge.dart';
import 'camera_capture_screen.dart';
import 'report_problem_dialog.dart';

/// Meter Reader Confirmation Screen displaying detected ROI, AI reading, calculated units,
/// traffic-light rules, and manual override capabilities (FR-30, FR-31, FR-32, FR-33).
class ReadingConfirmationScreen extends StatefulWidget {
  final AppState state;
  final ConsumerModel consumer;
  final MeterModel meter;
  final AiInferenceResult aiResult;
  final ValidationResult validation;
  final String scenarioKey;

  const ReadingConfirmationScreen({
    super.key,
    required this.state,
    required this.consumer,
    required this.meter,
    required this.aiResult,
    required this.validation,
    required this.scenarioKey,
  });

  @override
  State<ReadingConfirmationScreen> createState() => _ReadingConfirmationScreenState();
}

class _ReadingConfirmationScreenState extends State<ReadingConfirmationScreen> {
  late double _currentValue;
  late ValidationResult _currentValidation;
  String? _readerEditReason;
  bool _isRollover = false;
  bool _isMeterReplaced = false;
  double? _oldMeterFinalReading;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.aiResult.readingValue;
    _currentValidation = widget.validation;
    _isRollover = widget.validation.isRolloverDetected;
  }

  void _recalculateValidation() {
    setState(() {
      _currentValidation = widget.state.ruleEngine.evaluate(
        aiResult: widget.aiResult,
        meter: widget.meter,
        consumer: widget.consumer,
        currentReading: _currentValue,
        isMarkedRollover: _isRollover,
        isMarkedMeterReplaced: _isMeterReplaced,
      );
    });
  }

  double get _calculatedUnits {
    if (_isRollover) {
      final maxVal = widget.meter.digits == 5 ? 99999.0 : 999999.0;
      return (maxVal - widget.consumer.previousReading + _currentValue) * widget.meter.multiplier;
    }
    if (_isMeterReplaced) {
      return _currentValue * widget.meter.multiplier;
    }
    final raw = (_currentValue - widget.consumer.previousReading) * widget.meter.multiplier;
    return raw < 0 ? 0.0 : raw;
  }

  void _openEditDialog() {
    final controller = TextEditingController(text: _currentValue.toStringAsFixed(1));
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Reading Value',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI reading was ${widget.aiResult.readingValue.toStringAsFixed(1)} kWh. Please specify corrected value:',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Correct Reading (kWh)',
                  suffixText: 'kWh',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for Adjustment (FR-29)',
                  hintText: 'e.g. AI misread 7 as 1 due to sunlight glare',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed != null) {
                setState(() {
                  _currentValue = parsed;
                  _readerEditReason = reasonController.text.trim().isEmpty
                      ? 'Manual reader adjustment'
                      : reasonController.text.trim();
                });
                _recalculateValidation();
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save Override'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirm() async {
    await widget.state.submitReading(
      consumer: widget.consumer,
      meter: widget.meter,
      aiResult: widget.aiResult,
      finalValue: _currentValue,
      validation: _currentValidation,
      readerEditReason: _readerEditReason,
      isRollover: _isRollover,
      isMeterReplaced: _isMeterReplaced,
      oldMeterFinalReading: _oldMeterFinalReading,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _currentValidation.trafficLight == TrafficLight.green
              ? 'Reading confirmed and saved to MMR (Auto-Accepted)!'
              : 'Reading saved and routed to Supervisor Review Queue.',
        ),
        backgroundColor: _currentValidation.trafficLight == TrafficLight.green
            ? AppColors.statusGreen
            : AppColors.statusAmber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(AppStrings.readingTitle),
        actions: [
          IconButton(
            tooltip: 'Report Problem',
            icon: const Icon(Icons.report_problem_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ReportProblemDialog(
                  consumer: widget.consumer,
                  onReport: (code, note) async {
                    await widget.state.reportProblem(
                      consumer: widget.consumer,
                      meter: widget.meter,
                      problemCode: code,
                      note: note,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Consumer Header Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.consumer.name,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${widget.consumer.referenceNo} • ${widget.meter.meterNo}',
                          style: GoogleFonts.chivoMono(fontSize: 11.5, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.aiResult.inferenceMs}ms',
                      style: GoogleFonts.chivoMono(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Captured Meter Photo Preview with Detected Bounding Box (FR-30, FR-33)
            MeterPreviewCanvas(
              readingText: widget.aiResult.readingText,
              meterSerial: widget.meter.meterNo,
              scenarioKey: widget.scenarioKey,
              detectedBox: widget.aiResult.displayBox,
              showBoundingBox: true,
            ),
            const SizedBox(height: 14),

            // Traffic Light Result Badge (FR-27, P1.3)
            TrafficLightBadge(
              validation: _currentValidation,
              initiallyExpanded: _currentValidation.trafficLight != TrafficLight.green,
            ),
            const SizedBox(height: 14),

            // Per-Digit Optical Confidence Matrix (FR-19, P1.4 #5)
            DigitDisplayWidget(
              readingText: widget.aiResult.readingText,
              digitConfidences: widget.aiResult.digitConfidences,
              weakestIndex: widget.aiResult.weakestDigitIndex,
            ),
            const SizedBox(height: 14),

            // Reading Comparison & Units Card (FR-30)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.previousReading.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.consumer.previousReading.toStringAsFixed(1)} kWh',
                            style: GoogleFonts.chivoMono(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: Color(0xFFCBD5E1)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'CURRENT READING',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_currentValue.toStringAsFixed(1)} kWh',
                            style: GoogleFonts.chivoMono(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFF1F5F9), height: 24),

                  // Calculated Units & Tariff Slabs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'UNITS CONSUMED',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            '${_calculatedUnits.toStringAsFixed(1)} Units',
                            style: GoogleFonts.chivoMono(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _calculatedUnits <= 200.0
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _calculatedUnits <= 200.0
                              ? 'Protected Slab (<=200)'
                              : 'Unprotected (>200)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _calculatedUnits <= 200.0
                                ? const Color(0xFF166534)
                                : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Reader override note if edited
                  if (_readerEditReason != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.statusAmberBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.statusAmber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Manual override: $_readerEditReason',
                              style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.statusAmber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Rollover or Replaced Meter Toggles (P1.4 #7)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Meter Register Rollover (Wrapped to Zero)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _isRollover,
                    onChanged: (val) {
                      setState(() => _isRollover = val);
                      _recalculateValidation();
                    },
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  SwitchListTile(
                    title: Text(
                      'Meter Replaced Since Last Cycle',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _isMeterReplaced,
                    onChanged: (val) {
                      setState(() => _isMeterReplaced = val);
                      _recalculateValidation();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons Bar (FR-31)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(AppStrings.editReading),
                    onPressed: _openEditDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: Text(AppStrings.retakePhoto),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => CameraCaptureScreen(
                            state: widget.state,
                            consumer: widget.consumer,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Primary Confirm Button
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                _currentValidation.trafficLight == TrafficLight.green
                    ? AppStrings.confirmReading
                    : 'Confirm & Send to Verification Queue',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentValidation.trafficLight == TrafficLight.green
                    ? AppColors.primary
                    : AppColors.statusAmber,
              ),
              onPressed: _handleConfirm,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
