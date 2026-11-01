import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../localization/app_strings.dart';

/// Opens the device camera and returns the first barcode it reads **inside the
/// aiming frame**.
///
/// The screen pops itself with the scanned value as soon as a readable barcode
/// is found. The caller is responsible for turning that value into a search.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const Color _successColor = Color(0xFF34C759);

  final MobileScannerController _controller = MobileScannerController(
    // `normal` (instead of `noDuplicates`) keeps reporting a code that stays
    // in view. That matters now that detections outside the frame are
    // ignored: a code moved into the frame afterwards is still picked up.
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 250,
    // Higher resolution helps with small or dense barcodes (Android).
    cameraResolution: const Size(1920, 1080),
  );

  /// Drives the sweeping line inside the scan window.
  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  /// Flips to true when a barcode was accepted (corners turn green).
  final ValueNotifier<bool> _detected = ValueNotifier<bool>(false);

  /// Guards against popping the screen more than once.
  bool _handled = false;

  /// True when the camera was stopped because the app went to the background.
  bool _stoppedByLifecycle = false;

  /// Latest layout, kept so [_onDetect] can map barcodes onto the screen.
  Rect _window = Rect.zero;
  Size _previewSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLine.dispose();
    _detected.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;

    switch (state) {
      case AppLifecycleState.paused:
        if (_controller.value.isRunning) {
          _stoppedByLifecycle = true;
          unawaited(_controller.stop());
        }
      case AppLifecycleState.resumed:
        if (_stoppedByLifecycle) {
          _stoppedByLifecycle = false;
          unawaited(_controller.start());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;

    final value = _barcodeInsideWindow(capture);
    if (value == null) return;

    _handled = true;
    _detected.value = true;
    HapticFeedback.mediumImpact();

    // Brief pause so the green confirmation is visible.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  /// The barcode value closest to the centre of the aiming frame, considering
  /// ONLY barcodes whose centre lies inside the frame.
  ///
  /// Barcode corners come in the camera frame's coordinate space, so they are
  /// scaled the same way `BoxFit.cover` scales the preview before being
  /// compared with the on-screen window. Barcodes whose position cannot be
  /// determined are ignored, so nothing outside the frame can slip through.
  String? _barcodeInsideWindow(BarcodeCapture capture) {
    final frame = capture.size;
    final view = _previewSize;
    if (frame.isEmpty || view.isEmpty || _window.isEmpty) return null;

    // BoxFit.cover: scale to fill, crop the overflow equally on both sides.
    final scale = math.max(view.width / frame.width, view.height / frame.height);
    final offsetX = (view.width - frame.width * scale) / 2;
    final offsetY = (view.height - frame.height * scale) / 2;

    // A little tolerance so codes touching the border still count.
    final accepted = _window.inflate(6);
    final windowCenter = _window.center;

    String? best;
    var bestDistance = double.infinity;

    for (final barcode in capture.barcodes) {
      final value = (barcode.rawValue ?? barcode.displayValue)?.trim();
      if (value == null || value.isEmpty) continue;

      final corners = barcode.corners;
      if (corners.isEmpty) continue;

      var sumX = 0.0;
      var sumY = 0.0;
      for (final c in corners) {
        sumX += c.dx;
        sumY += c.dy;
      }
      final center = Offset(
        (sumX / corners.length) * scale + offsetX,
        (sumY / corners.length) * scale + offsetY,
      );

      if (!accepted.contains(center)) continue;

      final distance = (center - windowCenter).distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = value;
      }
    }

    return best;
  }

  /// The area the user should aim at.
  Rect _scanWindowFor(Size size) {
    final width = size.width * 0.82;
    final height = math.min(width * 0.75, size.height * 0.36);

    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Text(
          context.tr('Scan Barcode'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _previewSize = constraints.biggest;
          _window = _scanWindowFor(_previewSize);

          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => const ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                errorBuilder: (context, error) => _ScannerError(error: error),
              ),

              // Overlay only while the camera is live.
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: _controller,
                builder: (context, state, _) {
                  if (!state.isRunning || state.error != null) {
                    return const SizedBox.shrink();
                  }

                  return IgnorePointer(
                    child: _ScanWindowOverlay(
                      window: _window,
                      color: theme.colorScheme.primary,
                      successColor: _successColor,
                      animation: _scanLine,
                      detected: _detected,
                    ),
                  );
                },
              ),

              // Hint pill just under the frame.
              Positioned(
                left: 24,
                right: 24,
                top: _window.bottom + 24,
                child: IgnorePointer(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _detected,
                    builder: (context, detected, _) => _HintPill(
                      icon: detected
                          ? Icons.check_circle_rounded
                          : Icons.qr_code_scanner_rounded,
                      iconColor: detected ? _successColor : Colors.white,
                      text: context.tr(
                        'Align the barcode inside the frame to scan it',
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom controls.
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TorchButton(controller: _controller),
                        _SwitchCameraButton(controller: _controller),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rounded translucent "glass" circle used for the control buttons.
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: active
              ? Colors.amber.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.16),
          shape: CircleBorder(
            side: BorderSide(
              color: Colors.white.withValues(alpha: active ? 0 : 0.25),
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                icon,
                color: active ? Colors.black87 : Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flashlight toggle. Hidden when the device has no torch.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        if (!state.isRunning || state.torchState == TorchState.unavailable) {
          return const SizedBox.shrink();
        }

        final isOn = state.torchState == TorchState.on;

        return _GlassButton(
          tooltip: context.tr(isOn ? 'Turn torch off' : 'Turn torch on'),
          icon: isOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
          active: isOn,
          onPressed: controller.toggleTorch,
        );
      },
    );
  }
}

/// Front/back camera toggle. Hidden when the device has a single camera.
class _SwitchCameraButton extends StatelessWidget {
  const _SwitchCameraButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final cameras = state.availableCameras ?? 0;

        if (!state.isRunning || cameras < 2) {
          return const SizedBox.shrink();
        }

        return _GlassButton(
          tooltip: context.tr('Switch camera'),
          icon: Icons.cameraswitch_rounded,
          onPressed: controller.switchCamera,
        );
      },
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims everything except the scan window, draws corner brackets and a
/// sweeping line to show where to aim.
class _ScanWindowOverlay extends StatelessWidget {
  const _ScanWindowOverlay({
    required this.window,
    required this.color,
    required this.successColor,
    required this.animation,
    required this.detected,
  });

  final Rect window;
  final Color color;
  final Color successColor;
  final Animation<double> animation;
  final ValueListenable<bool> detected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _ScanWindowPainter(
          window: window,
          color: color,
          successColor: successColor,
          animation: animation,
          detected: detected,
        ),
      ),
    );
  }
}

class _ScanWindowPainter extends CustomPainter {
  _ScanWindowPainter({
    required this.window,
    required this.color,
    required this.successColor,
    required this.animation,
    required this.detected,
  }) : super(repaint: Listenable.merge([animation, detected]));

  final Rect window;
  final Color color;
  final Color successColor;
  final Animation<double> animation;
  final ValueListenable<bool> detected;

  static const double _radius = 20;
  static const double _cornerLength = 34;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      window,
      const Radius.circular(_radius),
    );
    final accent = detected.value ? successColor : color;

    // Dim everything outside the window.
    final dimmed = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rrect),
    );
    canvas.drawPath(
      dimmed,
      Paint()..color = Colors.black.withValues(alpha: 0.62),
    );

    // Subtle tint inside the window while a code is accepted.
    if (detected.value) {
      canvas.drawRRect(
        rrect,
        Paint()..color = successColor.withValues(alpha: 0.12),
      );
    }

    // Faint outline so the whole window is visible.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    _paintCorners(canvas, accent);
    if (!detected.value) _paintScanLine(canvas, accent);
  }

  void _paintCorners(Canvas canvas, Color accent) {
    final path = Path();
    const rad = _radius;
    const len = _cornerLength;
    final l = window.left;
    final t = window.top;
    final r = window.right;
    final b = window.bottom;
    const arc = Radius.circular(rad);

    path
    // Top-left
      ..moveTo(l, t + len)
      ..lineTo(l, t + rad)
      ..arcToPoint(Offset(l + rad, t), radius: arc)
      ..lineTo(l + len, t)
    // Top-right
      ..moveTo(r - len, t)
      ..lineTo(r - rad, t)
      ..arcToPoint(Offset(r, t + rad), radius: arc)
      ..lineTo(r, t + len)
    // Bottom-right
      ..moveTo(r, b - len)
      ..lineTo(r, b - rad)
      ..arcToPoint(Offset(r - rad, b), radius: arc)
      ..lineTo(r - len, b)
    // Bottom-left
      ..moveTo(l + len, b)
      ..lineTo(l + rad, b)
      ..arcToPoint(Offset(l, b - rad), radius: arc)
      ..lineTo(l, b - len);

    // Soft glow underneath, crisp stroke on top.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
  }

  void _paintScanLine(Canvas canvas, Color accent) {
    const inset = 14.0;
    final travel = window.height - inset * 2;
    final y = window.top +
        inset +
        travel * Curves.easeInOut.transform(animation.value);

    final lineRect = Rect.fromLTWH(
      window.left + inset,
      y - 1.5,
      window.width - inset * 2,
      3,
    );

    final gradient = LinearGradient(
      colors: [
        accent.withValues(alpha: 0),
        accent,
        accent.withValues(alpha: 0),
      ],
    ).createShader(lineRect);

    // Glow, then the line itself.
    canvas.drawRect(
      lineRect.inflate(3),
      Paint()
        ..shader = gradient
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRect(lineRect, Paint()..shader = gradient);
  }

  @override
  bool shouldRepaint(_ScanWindowPainter old) =>
      old.window != window ||
          old.color != color ||
          old.successColor != successColor ||
          old.animation != animation ||
          old.detected != detected;
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
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(22),
                  child: Icon(
                    Icons.no_photography_outlined,
                    color: Colors.white70,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                permissionDenied
                    ? context.tr('Camera access is turned off')
                    : context.tr('Camera unavailable'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
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
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}