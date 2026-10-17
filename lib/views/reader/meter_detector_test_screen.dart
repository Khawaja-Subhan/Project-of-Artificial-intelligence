import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/ai/meter_detector_service.dart';
import '../../services/camera/web_camera.dart';

/// Test screen for YOLO11n-OBB TFLite Meter Display Detector.
/// Allows capturing or picking meter photos, visualizing rotated bounding boxes,
/// viewing the straightened perspective crop, testing sample presets, and checking decision rules.
class MeterDetectorTestScreen extends StatefulWidget {
  const MeterDetectorTestScreen({super.key});

  @override
  State<MeterDetectorTestScreen> createState() => _MeterDetectorTestScreenState();
}

class _MeterDetectorTestScreenState extends State<MeterDetectorTestScreen> {
  final MeterDetectorService _detectorService = MeterDetectorService();

  String? _selectedImagePath;
  Uint8List? _selectedImageBytes;
  MeterDetectionResult? _result;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _processImage({String? path, Uint8List? bytes}) async {
    if ((path == null || path.isEmpty) && (bytes == null || bytes.isEmpty)) return;

    setState(() {
      _selectedImagePath = path;
      _selectedImageBytes = bytes;
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await _detectorService.detectMeter(
        imagePath: path,
        imageBytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error running detector: $e';
        _result = MeterDetectionResult.empty(
          message: 'Detection failed with error',
          error: e.toString(),
          rawBytes: bytes,
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final xfile = await _detectorService.pickImageFromGallery();
      if (xfile != null) {
        final bytes = await xfile.readAsBytes();
        await _processImage(path: xfile.path, bytes: bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _captureWithCamera() async {
    try {
      if (kIsWeb) {
        // Open live laptop webcam stream dialog
        final capturedBytes = await openLiveWebcamDialog(context);
        if (capturedBytes != null && capturedBytes.isNotEmpty) {
          await _processImage(bytes: capturedBytes);
        }
      } else {
        // Mobile / Android camera
        final xfile = await _detectorService.captureImageWithCamera();
        if (xfile != null) {
          final bytes = await xfile.readAsBytes();
          await _processImage(path: xfile.path, bytes: bytes);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture photo: $e')),
      );
    }
  }

  Future<void> _loadSamplePreset(SampleMeterType type) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });
    try {
      final sampleBytes = await _detectorService.loadSampleMeterImage(type);
      await _processImage(bytes: sampleBytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load sample meter: $e';
        _isLoading = false;
      });
    }
  }

  void _clear() {
    setState(() {
      _selectedImagePath = null;
      _selectedImageBytes = null;
      _result = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A), // Slate 900
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meter Display Detector',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              'YOLO11n-OBB • TFLite [1,3,640,640] NCHW',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          if (_selectedImagePath != null || _selectedImageBytes != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Clear & Reset',
              onPressed: _clear,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        children: [
          // Environment / Platform status pill
          _buildPlatformBanner(),
          const SizedBox(height: 14),

          // Action Buttons: Camera & Gallery + Sample Presets
          _buildActionCard(),
          const SizedBox(height: 16),

          // Loading state
          if (_isLoading) _buildLoadingCard(),

          // Error banner
          if (_errorMessage != null && !_isLoading) _buildErrorCard(_errorMessage!),

          // Decision / Status Banner
          if (!_isLoading && (_selectedImagePath != null || _selectedImageBytes != null) && _result != null) ...[
            _buildDecisionBanner(_result!),
            const SizedBox(height: 16),
            _buildMetricsGrid(_result!),
            const SizedBox(height: 16),
            _buildDetectionVisualCard(_result!),
            const SizedBox(height: 16),
            if (_result!.found && (_result!.croppedImageBytes != null || _result!.croppedImagePath != null)) ...[
              _buildCropCard(_result!),
              const SizedBox(height: 16),
            ],
            _buildDiagnosticsCard(_result!),
          ] else if (!_isLoading && _selectedImagePath == null && _selectedImageBytes == null) ...[
            _buildEmptyStateCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kIsWeb ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kIsWeb ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Icon(
            kIsWeb ? Icons.language_rounded : Icons.phone_android_rounded,
            size: 18,
            color: kIsWeb ? const Color(0xFF2563EB) : const Color(0xFF059669),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              kIsWeb
                  ? 'Active on Localhost (Web Browser). Real-time file picker, webcam capture & sample presets ready.'
                  : 'Active on Android: Native TFLite YOLO11n-OBB float32 engine loaded from assets/best.tflite.',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kIsWeb ? const Color(0xFF1E40AF) : const Color(0xFF065F46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.center_focus_strong_rounded, color: Color(0xFF0284C7), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Input Meter Photo',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Capture with camera, choose from gallery, or select a sample meter',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _captureWithCamera,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text('Camera Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text('Pick Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          Text(
            'OR TEST WITH SAMPLE PAKISTANI METERS (1-TAP):',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.electric_bolt_rounded, size: 16, color: Color(0xFF0284C7)),
                label: Text('⚡ Digital Meter #1', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: const Color(0xFFF0F9FF),
                side: const BorderSide(color: Color(0xFFBAE6FD)),
                onPressed: _isLoading ? null : () => _loadSamplePreset(SampleMeterType.digitalSinglePhase),
              ),
              ActionChip(
                avatar: const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF7C3AED)),
                label: Text('⚙️ Analog Wheel #1', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: const Color(0xFFF5F3FF),
                side: const BorderSide(color: Color(0xFFDDD6FE)),
                onPressed: _isLoading ? null : () => _loadSamplePreset(SampleMeterType.analogThreePhase),
              ),
              ActionChip(
                avatar: const Icon(Icons.screen_rotation_rounded, size: 16, color: Color(0xFFD97706)),
                label: Text('📐 Tilted Digital', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: const Color(0xFFFFFBEB),
                side: const BorderSide(color: Color(0xFFFDE68A)),
                onPressed: _isLoading ? null : () => _loadSamplePreset(SampleMeterType.tiltedDigital),
              ),
              ActionChip(
                avatar: const Icon(Icons.speed_rounded, size: 16, color: Color(0xFF059669)),
                label: Text('⚙️ Analog Wheel #2', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: const Color(0xFFECFDF5),
                side: const BorderSide(color: Color(0xFFA7F3D0)),
                onPressed: _isLoading ? null : () => _loadSamplePreset(SampleMeterType.analogSecond),
              ),
              ActionChip(
                avatar: const Icon(Icons.electric_meter_rounded, size: 16, color: Color(0xFF0284C7)),
                label: Text('⚡ Digital Meter #2', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                backgroundColor: const Color(0xFFF0F9FF),
                side: const BorderSide(color: Color(0xFFBAE6FD)),
                onPressed: _isLoading ? null : () => _loadSamplePreset(SampleMeterType.digitalSecond),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Color(0xFF0284C7)),
          const SizedBox(height: 16),
          Text(
            'Running YOLO11n-OBB TFLite Detector...',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Decoding [1, 7, 8400] output, applying Rotated NMS & perspective warp...',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF991B1B), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionBanner(MeterDetectionResult r) {
    Color bgCol;
    Color borderCol;
    Color textCol;
    IconData icon;
    String statusTitle;
    String subtext;

    switch (r.decision) {
      case 'Accepted':
        bgCol = const Color(0xFFECFDF5); // Emerald 50
        borderCol = const Color(0xFF10B981); // Emerald 500
        textCol = const Color(0xFF065F46); // Emerald 800
        icon = Icons.verified_rounded;
        statusTitle = 'Accepted (Confidence ≥ 0.50)';
        subtext = 'Display counter clearly detected. Proceeding directly to OCR digit recognition stage.';
        break;
      case 'Uncertain, manual check':
        bgCol = const Color(0xFFFFFBEB); // Amber 50
        borderCol = const Color(0xFFF59E0B); // Amber 500
        textCol = const Color(0xFF92400E); // Amber 800
        icon = Icons.warning_amber_rounded;
        statusTitle = 'Uncertain, manual check (0.25 ≤ Conf < 0.50)';
        subtext = 'Low contrast or glare detected. Flagged for supervisor review per Section 7.';
        break;
      default:
        bgCol = const Color(0xFFFEF2F2); // Red 50
        borderCol = const Color(0xFFEF4444); // Red 500
        textCol = const Color(0xFF991B1B); // Red 800
        icon = Icons.cancel_outlined;
        statusTitle = 'No meter found, retake';
        subtext = 'No meter display counter found. Please retake the photo with the display centered and clear.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: borderCol, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        statusTitle,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: textCol),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: textCol.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        r.found ? '${(r.confidence * 100).toStringAsFixed(1)}%' : '0%',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textCol,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtext,
                  style: GoogleFonts.inter(fontSize: 13, color: textCol.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(MeterDetectionResult r) {
    return Row(
      children: [
        Expanded(
          child: _metricCard(
            label: 'Display Class',
            value: r.found ? (r.isDigital ? 'Digital LCD' : 'Analog Wheel') : 'None',
            icon: r.isDigital ? Icons.pin_rounded : Icons.speed_rounded,
            color: const Color(0xFF0284C7),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            label: 'Confidence',
            value: r.found ? '${(r.confidence * 100).toStringAsFixed(1)}%' : '0%',
            icon: Icons.analytics_outlined,
            color: r.confidence >= 0.50
                ? const Color(0xFF059669)
                : (r.confidence >= 0.25 ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _metricCard(
            label: 'Inference',
            value: '${r.inferenceTimeMs} ms',
            icon: Icons.timer_outlined,
            color: const Color(0xFF6366F1),
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionVisualCard(MeterDetectionResult r) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.crop_rotate_rounded, size: 18, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Text(
                  'Full Photo with Rotated Bounding Box',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (r.found)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${r.corners.length} Corners OBB',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: _buildUniversalImageView(
              bytes: r.annotatedImageBytes ?? _selectedImageBytes,
              path: r.annotatedImagePath ?? _selectedImagePath,
              fallbackText: 'No preview available',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCropCard(MeterDetectionResult r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.transform_rounded, color: Color(0xFF0284C7), size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Straightened Display Crop (Perspective Warped)',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Warped from original full-resolution photo (keeps digits sharp for OCR)',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.all(8),
              child: _buildUniversalImageView(
                bytes: r.croppedImageBytes,
                path: r.croppedImagePath,
                fallbackText: 'Warped crop unavailable',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF059669)),
              const SizedBox(width: 6),
              Text(
                'Ready to pass to digit recognition (OCR) stage',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF059669), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsCard(MeterDetectionResult r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.code_rounded, size: 18, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                'OBB Detection Diagnostics',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _diagRow('Class ID', '${r.classIndex ?? "none"} (${r.className ?? "unclassified"})'),
          _diagRow('Confidence Raw', r.confidence.toStringAsFixed(6)),
          _diagRow('Surviving NMS Boxes', '${r.numBoxesFound} box'),
          _diagRow('Inference Time', '${r.inferenceTimeMs} ms'),
          _diagRow('Decision Outcome', r.decision),
          if (r.corners.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'OBB 4-Corner Vertices (Original Image Space):',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                r.corners
                    .asMap()
                    .entries
                    .map((e) => 'P${e.key + 1}: (${e.value.dx.toStringAsFixed(1)}, ${e.value.dy.toStringAsFixed(1)})')
                    .join('\n'),
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: const Color(0xFF38BDF8), height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F9FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.document_scanner_rounded, size: 40, color: Color(0xFF0284C7)),
          ),
          const SizedBox(height: 16),
          Text(
            'Ready to Detect Meter Displays',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Use Camera or Gallery above, or tap one of the 1-Tap Sample Presets to test instant digital, analog, or tilted meter counter detection.',
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUniversalImageView({
    Uint8List? bytes,
    String? path,
    required String fallbackText,
  }) {
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) => _errorPlaceholder(fallbackText),
      );
    }

    if (!kIsWeb && path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => _errorPlaceholder(fallbackText),
          );
        }
      } catch (_) {}
    }

    return _errorPlaceholder(fallbackText);
  }

  Widget _errorPlaceholder(String message) {
    return Container(
      height: 140,
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 28, color: Color(0xFF94A3B8)),
          const SizedBox(height: 6),
          Text(message, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
