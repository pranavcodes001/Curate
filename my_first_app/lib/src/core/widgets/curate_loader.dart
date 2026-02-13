import 'package:flutter/material.dart';

// Premium, muted "misty steel" brand color for Curie avatar/loader.
const Color kCurateBrand = Color(0xFF5A7E92);

/// The official Mascot of Curate.
/// A minimalist, friendly "Blob" with natural eyes.
class CurateAvatar extends StatelessWidget {
  final double size;
  final Color? color;
  final bool animate;

  const CurateAvatar({
    super.key,
    this.size = 100,
    this.color,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    if (animate) {
      return CurateLoader(size: size);
    }

    final effectiveColor = color ?? kCurateBrand;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MascotPainter(color: effectiveColor, blink: 1.0, look: 0.0),
      ),
    );
  }
}

/// The main loading widget for the Curate app.
/// Featuring "Curie" the mascot.
class CurateLoader extends StatefulWidget {
  final double size;
  final String? label;
  final bool showLabel;
  final bool fullScreen;

  const CurateLoader({
    super.key,
    this.size = 80,
    this.label,
    this.showLabel = true,
    this.fullScreen = false,
  });

  @override
  State<CurateLoader> createState() => _CurateLoaderState();
}

class _CurateLoaderState extends State<CurateLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounce;
  late Animation<double> _blink;
  late Animation<double> _look;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    // Gentle bounce
    _bounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: -10.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -10.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    // Periodic blink
    _blink = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 80),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 5),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 5),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 10),
    ]).animate(_controller);

    // Looking around
    _look = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 20),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.fullScreen ? Colors.white : kCurateBrand;

    final loader = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, _bounce.value),
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: _MascotPainter(
                    color: color,
                    blink: _blink.value,
                    look: _look.value,
                  ),
                ),
              ),
            ),
            if (widget.showLabel && widget.label != null) ...[
              const SizedBox(height: 16),
              Text(
                widget.label!.toUpperCase(),
                style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontSize: 10,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        );
      },
    );

    if (widget.fullScreen) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Center(child: loader),
      );
    }

    return loader;
  }
}

class _MascotPainter extends CustomPainter {
  final Color color;
  final double blink;
  final double look;

  _MascotPainter({
    required this.color,
    required this.blink,
    required this.look,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final center = Offset(size.width / 2, size.height / 2);
    final unit = size.width / 10;

    // 1. Draw Body (A soft, rounded "Curate" blob)
    final bodyRect = Rect.fromCenter(
      center: center.translate(0, unit),
      width: unit * 7,
      height: unit * 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(unit * 3)),
      paint,
    );

    // 2. Draw Eyes (Natural white eyes with black pupils)
    final eyePaint = Paint()..color = Colors.white;
    final pupilPaint = Paint()..color = const Color(0xFF1A1A1A);

    final leftEyeCenter = center.translate(-unit * 1.5, unit * 0.5);
    final rightEyeCenter = center.translate(unit * 1.5, unit * 0.5);

    void drawEye(Offset eyeCenter) {
      if (blink < 0.1) {
        // Closed eye (just a line)
        final strokePaint = Paint()
          ..color = const Color(0xFF1A1A1A).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          eyeCenter.translate(-unit * 0.8, 0),
          eyeCenter.translate(unit * 0.8, 0),
          strokePaint,
        );
      } else {
        // Open eye
        canvas.drawOval(
          Rect.fromCenter(
            center: eyeCenter,
            width: unit * 2,
            height: unit * 2 * blink,
          ),
          eyePaint,
        );

        // Pupil
        final pupilOffset = Offset(look * unit * 0.5, 0);
        canvas.drawCircle(
          eyeCenter + pupilOffset,
          unit * 0.6 * blink,
          pupilPaint,
        );
      }
    }

    drawEye(leftEyeCenter);
    drawEye(rightEyeCenter);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
