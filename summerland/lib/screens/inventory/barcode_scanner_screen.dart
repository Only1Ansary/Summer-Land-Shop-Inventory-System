import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../localization/app_strings.dart';

/// Opens the device camera and returns the first barcode it reads.
///
/// The screen pops itself with the scanned value as soon as a readable barcode
/// is found. The caller is responsible for turning that value into a search.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  /// Guards against popping the screen more than once: the camera keeps
  /// emitting the same barcode until the route is actually gone.
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue ?? barcode.displayValue;
      final trimmed = value?.trim();

      if (trimmed == null || trimmed.isEmpty) continue;

      _handled = true;
      Navigator.of(context).pop(trimmed);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.tr('Scan barcode')),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
            placeholderBuilder: (_) => const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            errorBuilder: (context, error) => _ScannerError(error: error),
            overlayBuilder: (context, constraints) {
              final size = constraints.biggest;

              return _ScanWindowOverlay(
                window: Rect.fromCenter(
                  center: size.center(Offset.zero),
                  width: size.width * 0.82,
                  height: size.height * 0.32,
                ),
                color: theme.colorScheme.primary,
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Text(
                  context.tr('Point the camera at a barcode to search for it.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dims everything except the scan window and outlines where to aim.
class _ScanWindowOverlay extends StatelessWidget {
  const _ScanWindowOverlay({required this.window, required this.color});

  final Rect window;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScanWindowPainter(window: window, color: color),
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  const _ScanWindowPainter({required this.window, required this.color});

  final Rect window;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(16)));
    final dimmed = Path.combine(PathOperation.difference, overlay, cutout);

    canvas.drawPath(
      dimmed,
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(16)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ScanWindowPainter oldDelegate) =>
      oldDelegate.window != window || oldDelegate.color != color;
}

/// Shown when the camera cannot start (permission denied, no camera, or a
/// platform that the scanner does not support).
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final bool permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                permissionDenied
                    ? context.tr(
                        'Camera access was denied. Allow it in your device '
                        'settings and try again.',
                      )
                    : context.tr(
                        'The camera could not be opened on this device.',
                      ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
