import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'motion.dart';

/// The 16px status glyph shown before the title. Renders nothing for
/// [NotchToastType.normal].
class NotchStatusIcon extends StatelessWidget {
  const NotchStatusIcon({
    super.key,
    required this.type,
    required this.foreground,
    required this.background,
    required this.reduceMotion,
  });

  final NotchToastType type;

  /// The toast text colour; fills the icon badge.
  final Color foreground;

  /// The shell colour; used for strokes drawn on top of the badge.
  final Color background;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (type) {
      NotchToastType.normal => const SizedBox.shrink(),
      NotchToastType.loading => _Spinner(
        color: foreground,
        reduceMotion: reduceMotion,
      ),
      _ => _AnimatedGlyph(
        type: type,
        foreground: foreground,
        background: background,
        reduceMotion: reduceMotion,
      ),
    };
    if (type == NotchToastType.normal) return child;
    return SizedBox.square(dimension: 16, child: Center(child: child));
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner({required this.color, required this.reduceMotion});

  final Color color;
  final bool reduceMotion;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_Spinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: const Size.square(14),
        painter: _SpinnerPainter(widget.color),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 2.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawOval(rect, paint..color = color.withValues(alpha: 0.32));
    canvas.drawArc(
      rect,
      -math.pi * 3 / 4,
      math.pi / 2,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) => old.color != color;
}

/// Plays the one-shot pop + stroke-draw animation for success, error,
/// warning and info glyphs.
class _AnimatedGlyph extends StatefulWidget {
  const _AnimatedGlyph({
    required this.type,
    required this.foreground,
    required this.background,
    required this.reduceMotion,
  });

  final NotchToastType type;
  final Color foreground;
  final Color background;
  final bool reduceMotion;

  @override
  State<_AnimatedGlyph> createState() => _AnimatedGlyphState();
}

class _AnimatedGlyphState extends State<_AnimatedGlyph>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 660);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Progress of a segment that starts after [delayMs] and lasts [durationMs].
  double _segment(int delayMs, int durationMs) {
    final total = _total.inMilliseconds;
    return Interval(
      delayMs / total,
      math.min(1, (delayMs + durationMs) / total),
      curve: notchEase,
    ).transform(_controller.value);
  }

  /// Linear keyframe interpolation with [notchEase] applied per segment.
  static double _keyframes(List<double> values, double t) {
    final segments = values.length - 1;
    final scaled = t * segments;
    final index = math.min(scaled.floor(), segments - 1);
    final local = notchEase.transform((scaled - index).clamp(0.0, 1.0));
    return values[index] + (values[index + 1] - values[index]) * local;
  }

  @override
  Widget build(BuildContext context) {
    final (popDelay, popDuration, scales, rotations) = switch (widget.type) {
      NotchToastType.success => (
        140,
        500,
        [0.86, 1.075, 0.985, 1.0],
        [-4.0, 1.8, -0.6, 0.0],
      ),
      NotchToastType.error => (
        140,
        460,
        [0.86, 1.065, 0.985, 1.0],
        [-3.0, 1.8, -0.5, 0.0],
      ),
      _ => (120, 420, [0.88, 1.055, 0.99, 1.0], [-2.0, 1.0, -0.3, 0.0]),
    };

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pop = _controller.value == 1
            ? 1.0
            : _segment(popDelay, popDuration);
        final strokes = switch (widget.type) {
          NotchToastType.success => [_segment(160, 460)],
          NotchToastType.error => [_segment(160, 340), _segment(260, 340)],
          _ => [_segment(200, 300), _segment(420, 200)],
        };
        return Transform.rotate(
          angle: _keyframes(rotations, pop) * math.pi / 180,
          child: Transform.scale(
            scale: _keyframes(scales, pop),
            child: CustomPaint(
              size: const Size.square(16),
              painter: _GlyphPainter(
                type: widget.type,
                foreground: widget.foreground,
                background: widget.background,
                progress: strokes,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.type,
    required this.foreground,
    required this.background,
    required this.progress,
  });

  final NotchToastType type;
  final Color foreground;
  final Color background;
  final List<double> progress;

  static final Path _warningTriangle = Path()
    ..moveTo(10.06, 2.15)
    ..arcToPoint(const Offset(13.94, 2.15), radius: const Radius.circular(2.24))
    ..lineTo(22.64, 17.22)
    ..arcToPoint(
      const Offset(20.70, 20.58),
      radius: const Radius.circular(2.24),
    )
    ..lineTo(3.3, 20.58)
    ..arcToPoint(const Offset(1.36, 17.22), radius: const Radius.circular(2.24))
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case NotchToastType.success || NotchToastType.error:
        _paintBadge(canvas, size);
      case NotchToastType.warning || NotchToastType.info:
        _paintAlert(canvas, size);
      case NotchToastType.normal || NotchToastType.loading:
        break;
    }
  }

  /// A filled circle with a 10px check or cross drawn in a 16-unit viewBox.
  void _paintBadge(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2,
      Paint()..color = foreground,
    );
    canvas.save();
    final isSuccess = type == NotchToastType.success;
    canvas.translate(3, 3 + (isSuccess ? 0.4 : 0.2));
    canvas.scale(10 / 16);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSuccess ? 2.15 : 2.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final paths = isSuccess
        ? [
            Path()
              ..moveTo(3.45, 8.15)
              ..relativeLineTo(2.75, 2.7)
              ..relativeLineTo(6.35, -6.2),
          ]
        : [
            Path()
              ..moveTo(3.7, 3.7)
              ..lineTo(12.3, 12.3),
            Path()
              ..moveTo(12.3, 3.7)
              ..lineTo(3.7, 12.3),
          ];
    for (var i = 0; i < paths.length; i++) {
      _drawPartial(canvas, paths[i], progress[i], stroke, background);
    }
    canvas.restore();
  }

  /// A filled triangle or circle with an exclamation mark, 24-unit viewBox.
  void _paintAlert(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24);
    final fill = Paint()..color = foreground;
    final isWarning = type == NotchToastType.warning;
    if (isWarning) {
      canvas.drawPath(_warningTriangle, fill);
    } else {
      canvas.drawCircle(const Offset(12, 12), 11.25, fill);
    }
    final bar = Path()
      ..moveTo(12, isWarning ? 8.2 : 7.55)
      ..lineTo(12, isWarning ? 12.85 : 12.55);
    _drawPartial(
      canvas,
      bar,
      progress[0],
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isWarning ? 2.35 : 2.45
        ..strokeCap = StrokeCap.round,
      background,
    );
    final dot = progress[1];
    if (dot > 0) {
      canvas.drawCircle(
        Offset(12, isWarning ? 16.55 : 16.65),
        1.35 * dot,
        Paint()..color = background.withValues(alpha: background.a * dot),
      );
    }
    canvas.restore();
  }

  static void _drawPartial(
    Canvas canvas,
    Path path,
    double t,
    Paint paint,
    Color color,
  ) {
    if (t <= 0) return;
    paint.color = color.withValues(alpha: color.a * t.clamp(0.0, 1.0));
    if (t >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.type != type ||
      old.foreground != foreground ||
      old.background != background ||
      !_listEquals(old.progress, progress);

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
