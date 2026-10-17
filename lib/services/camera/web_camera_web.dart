import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<Uint8List?> openLiveWebcamDialog(BuildContext context) async {
  return showDialog<Uint8List?>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const _LiveWebcamDialog(),
  );
}

class _LiveWebcamDialog extends StatefulWidget {
  const _LiveWebcamDialog();

  @override
  State<_LiveWebcamDialog> createState() => _LiveWebcamDialogState();
}

class _LiveWebcamDialogState extends State<_LiveWebcamDialog> {
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;
  String _viewType = '';
  bool _isCameraReady = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startWebcam();
  }

  Future<void> _startWebcam() async {
    try {
      _viewType = 'webcam-view-${DateTime.now().millisecondsSinceEpoch}';

      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(1)';

      // Request live camera stream from laptop/device
      final mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
        },
        'audio': false,
      });

      if (mediaStream == null) {
        throw Exception('Camera device not found or access denied by browser');
      }

      video.srcObject = mediaStream;
      _mediaStream = mediaStream;
      _videoElement = video;

      // Register platform view for Flutter Web
      ui_web.platformViewRegistry.registerViewFactory(
        _viewType,
        (int viewId) => video,
      );

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to access laptop webcam: $e\nPlease grant camera permission in your browser.';
        });
      }
    }
  }

  void _capturePhoto() {
    final video = _videoElement;
    if (video == null || video.videoWidth == 0 || video.videoHeight == 0) return;

    try {
      final canvas = html.CanvasElement(
        width: video.videoWidth,
        height: video.videoHeight,
      );
      final ctx = canvas.context2D;
      ctx.drawImage(video, 0, 0);

      final dataUrl = canvas.toDataUrl('image/jpeg', 0.95);
      final commaIdx = dataUrl.indexOf(',');
      final base64Data = commaIdx != -1 ? dataUrl.substring(commaIdx + 1) : dataUrl;
      final bytes = base64Decode(base64Data);

      _stopCamera();
      Navigator.of(context).pop(bytes);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to capture frame: $e';
      });
    }
  }

  void _stopCamera() {
    try {
      _mediaStream?.getTracks().forEach((track) => track.stop());
      _mediaStream = null;
      _videoElement?.srcObject = null;
      _videoElement = null;
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Live Camera Viewfinder',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () {
                      _stopCamera();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1E293B)),

            // Viewfinder
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isCameraReady)
                    ClipRect(
                      child: HtmlElementView(viewType: _viewType),
                    )
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam_off_rounded, size: 48, color: Color(0xFFEF4444)),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFFCA5A5)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF38BDF8)),
                        const SizedBox(height: 14),
                        Text(
                          'Starting camera hardware...',
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),

                  // Overlay target grid
                  if (_isCameraReady)
                    IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Center meter display counter here',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Shutter controls
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              color: const Color(0xFF0B132B),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel'),
                    onPressed: () {
                      _stopCamera();
                      Navigator.of(context).pop();
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.camera_rounded, size: 22),
                    label: Text(
                      'Capture Photo',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _isCameraReady ? _capturePhoto : null,
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
