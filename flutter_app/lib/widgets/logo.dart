import 'dart:math' as math;
import 'package:flutter/material.dart';

class Logo extends StatelessWidget {
  final double size;

  const Logo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _LogoPainter());
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 32;
    canvas.save();
    canvas.scale(scale);

    final gradient = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        radius: 0.75,
        colors: [Color(0xFFFFD9A0), Color(0xFFFF9F43), Color(0xFFD9480F)],
        stops: [0.0, 0.45, 1.0],
      ).createShader(const Rect.fromLTWH(1.5, 1.5, 29, 29));
    canvas.drawCircle(const Offset(16, 16), 14.5, gradient);

    final outerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFF3E0).withValues(alpha: 0.35);
    canvas.drawCircle(const Offset(16, 16), 14.5, outerStroke);

    final innerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFF3E0).withValues(alpha: 0.22);
    canvas.drawCircle(const Offset(16, 16), 11.2, innerStroke);

    canvas.translate(16, 16);
    canvas.rotate(-25 * math.pi / 180);
    canvas.scale(0.7);
    final arrow = Path()
      ..moveTo(10, 0)
      ..lineTo(-10, -8)
      ..lineTo(0, 0)
      ..lineTo(-10, 8)
      ..close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFF3A2413));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
