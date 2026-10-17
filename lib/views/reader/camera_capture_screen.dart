import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../models/consumer_model.dart';
import '../../models/meter_model.dart';
import '../../state/app_state.dart';
import '../../widgets/meter_preview_canvas.dart';
import '../../widgets/quality_hint_banner.dart';
import '../../services/camera/web_camera.dart';
import 'reading_confirmation_screen.dart';
import 'report_problem_dialog.dart';
import 'meter_detector_test_screen.dart';

/// Camera Screen with custom viewfinder reticle, quality heuristics, and test scenarios (FR-10 to FR-16).
class CameraCaptureScreen extends StatefulWidget {
  final AppState state;
  final ConsumerModel consumer;

  const CameraCaptureScreen({
    super.key,
    required this.state,
    required this.consumer,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  bool _isTorchOn = false;
  String _selectedScenario = 'normal_clean';
  bool _isProcessing = false;

  final Map<String, String> _scenarios = {
    'normal_clean': 'Standard Clean Digital Reading (Expected Green)',
    'glare_ambiguous': 'Sun Glare on Glass / Ambiguous Digit (Amber)',
    'spike_high': 'Consumption Spike > 3x Average (Amber)',
    'suspicious_zero': 'Zero Consumption on Active Consumer (Amber)',
    'rollover': 'Register Rollover (99999 -> 00024 kWh)',
    'missing_digit': 'Missing Digit Jump (Red Anomaly)',
    'unreadable_blank': 'Blank Display / Error Code (Problem)',
  };

  Future<void> _captureAndInfer() async {
    if (kIsWeb) {
      // Prompt live laptop camera stream dialog
      final bytes = await openLiveWebcamDialog(context);
      if (bytes == null) {
        return; // User cancelled capture
      }
    }

    setState(() => _isProcessing = true);

    final meter = widget.state.db.getMeterById(widget.consumer.meterId) ??
        MeterModel(
          id: widget.consumer.meterId,
          consumerId: widget.consumer.id,
          meterNo: 'PK-MTR-DEFAULT',
          meterType: MeterType.digitalLcd,
          installedOn: '2022-01-01',
        );

    // Call replaceable AI Inference Engine (FR-17 to FR-20, Section 9)
    final aiResult = await widget.state.aiService.inferMeterReading(
      meterTypeHint: meter.meterType,
      expectedDigits: meter.digits,
      previousReading: widget.consumer.previousReading,
      scenarioKey: _selectedScenario,
    );

    // Run Rule Engine across 6 Phase-1 checks (P1.3)
    final validation = widget.state.ruleEngine.evaluate(
      aiResult: aiResult,
      meter: meter,
      consumer: widget.consumer,
      currentReading: aiResult.readingValue,
      isMarkedRollover: _selectedScenario == 'rollover',
    );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReadingConfirmationScreen(
          state: widget.state,
          consumer: widget.consumer,
          meter: meter,
          aiResult: aiResult,
          validation: validation,
          scenarioKey: _selectedScenario,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meter = widget.state.db.getMeterById(widget.consumer.meterId);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.consumer.name,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              '${widget.consumer.referenceNo} • ${meter?.meterNo ?? 'Meter'}',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          // Inspect AI Detector (YOLO11n-OBB)
          IconButton(
            tooltip: 'Inspect AI Detector (YOLO11n-OBB)',
            icon: const Icon(Icons.document_scanner_rounded, color: Color(0xFF38BDF8)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MeterDetectorTestScreen()),
              );
            },
          ),
          // Torch / Flash Toggle (FR-12)
          IconButton(
            tooltip: 'Flash Toggle',
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? const Color(0xFFFACC15) : Colors.white,
            ),
            onPressed: () => setState(() => _isTorchOn = !_isTorchOn),
          ),
          // Report Problem Direct Access (FR-32)
          IconButton(
            tooltip: 'Report Site Issue',
            icon: const Icon(Icons.report_problem_outlined, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => ReportProblemDialog(
                  consumer: widget.consumer,
                  onReport: (code, note) async {
                    if (meter != null) {
                      await widget.state.reportProblem(
                        consumer: widget.consumer,
                        meter: meter,
                        problemCode: code,
                        note: note,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Problem recorded: $code'),
                            backgroundColor: AppColors.statusRed,
                          ),
                        );
                      }
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Optical Quality Guidance Hint Banner (FR-11)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: QualityHintBanner(
                scenarioKey: _selectedScenario,
                isTorchOn: _isTorchOn,
              ),
            ),

            // Live Viewfinder / Frame Guide Area (FR-10)
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Simulated Pakistani Electricity Meter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: MeterPreviewCanvas(
                      readingText: _selectedScenario == 'rollover'
                          ? '00024.5'
                          : _selectedScenario == 'spike_high'
                              ? (widget.consumer.previousReading + 890.0).toStringAsFixed(1)
                              : _selectedScenario == 'suspicious_zero'
                                  ? widget.consumer.previousReading.toStringAsFixed(1)
                                  : (widget.consumer.previousReading + 182.4).toStringAsFixed(1),
                      meterSerial: meter?.meterNo ?? 'PK-MTI-89214',
                      scenarioKey: _selectedScenario,
                      showBoundingBox: false,
                    ),
                  ),

                  // Framing Guide Reticle Overlay (FR-10)
                  Container(
                    width: 310,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFFACC15).withOpacity(0.9), // High-visibility yellow
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 8,
                          left: 10,
                          child: Text(
                            'ALIGN LCD DISPLAY HERE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFACC15),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Processing Spinner
                  if (_isProcessing)
                    Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: AppColors.accent),
                            const SizedBox(height: 16),
                            Text(
                              'Running On-Device AI Inference...',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Detecting ROI & 7-Segment OCR',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Scenario Selector Bar (Allows testing all PDF edge cases)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined, size: 16, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Text(
                    'Simulate Scenario:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedScenario,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
                        items: _scenarios.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(
                              entry.value,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedScenario = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Dedicated Button to Inspect AI Detector (YOLO11n-OBB)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Center(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.document_scanner_rounded, size: 16),
                  label: Text(
                    'Inspect AI Detector (YOLO11n-OBB)',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MeterDetectorTestScreen()),
                    );
                  },
                ),
              ),
            ),

            // Bottom Shutter & Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel / Back
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),

                  // Primary Capture Shutter Button
                  GestureDetector(
                    onTap: _isProcessing ? null : _captureAndInfer,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 28),
                        ),
                      ),
                    ),
                  ),

                  // Torch Quick Button
                  IconButton(
                    icon: Icon(
                      _isTorchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                      color: _isTorchOn ? const Color(0xFFFACC15) : Colors.white,
                      size: 28,
                    ),
                    onPressed: () => setState(() => _isTorchOn = !_isTorchOn),
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
