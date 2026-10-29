import 'package:flutter/rendering.dart';

import 'controller.dart';

/// Builds the island silhouette for a shell of [size].
///
/// In attached mode the body is rounded on the side away from the screen edge
/// and grows concave "ears" of [radius] on both sides of the edge, so the
/// island reads as part of the bezel. The ears extend outside [size].
Path notchPath(
  Size size, {
  required NotchPosition position,
  required NotchMode mode,
  double radius = 16,
  double floatingRadius = 20,
}) {
  if (mode == NotchMode.floating) {
    return Path()..addRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(floatingRadius),
      ),
    );
  }

  final w = size.width;
  final h = size.height;
  final r = radius;
  final circle = Radius.circular(r);
  final path = Path()
    ..moveTo(-r, 0)
    ..arcToPoint(Offset(0, r), radius: circle)
    ..lineTo(0, h - r)
    ..arcToPoint(Offset(r, h), radius: circle, clockwise: false)
    ..lineTo(w - r, h)
    ..arcToPoint(Offset(w, h - r), radius: circle, clockwise: false)
    ..lineTo(w, r)
    ..arcToPoint(Offset(w + r, 0), radius: circle)
    ..close();

  if (position == NotchPosition.topCenter) return path;
  final flip = Matrix4.identity()
    ..translateByDouble(0, h, 0, 1)
    ..scaleByDouble(1, -1, 1, 1);
  return path.transform(flip.storage);
}

/// The body of the island without the ears, used to clip content.
BorderRadius notchBodyRadius({
  required NotchPosition position,
  required NotchMode mode,
  double radius = 16,
  double floatingRadius = 20,
}) {
  if (mode == NotchMode.floating) {
    return BorderRadius.circular(floatingRadius);
  }
  final corner = Radius.circular(radius);
  return position == NotchPosition.topCenter
      ? BorderRadius.vertical(bottom: corner)
      : BorderRadius.vertical(top: corner);
}

class NotchShellPainter extends CustomPainter {
  NotchShellPainter({
    required this.color,
    required this.shadowColor,
    required this.position,
    required this.mode,
    required this.radius,
  });

  final Color color;
  final Color shadowColor;
  final NotchPosition position;
  final NotchMode mode;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = notchPath(
      size,
      position: position,
      mode: mode,
      radius: radius,
    );
    if (shadowColor.a > 0) {
      canvas.drawPath(
        path.shift(const Offset(0, 8)),
        Paint()
          ..color = shadowColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(NotchShellPainter old) =>
      old.color != color ||
      old.shadowColor != shadowColor ||
      old.position != position ||
      old.mode != mode ||
      old.radius != radius;
}
