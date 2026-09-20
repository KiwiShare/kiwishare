import 'dart:math';
import 'package:flutter/material.dart';

/// A crisp, vector-rendered gold coin icon for KiwiGold.
/// Scales smoothly from 10px to 64px+ without text clipping or platform font issues.
class KiwiGoldCoinIcon extends StatelessWidget {
  final double size;

  const KiwiGoldCoinIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _KiwiGoldCoinPainter(),
      ),
    );
  }
}

class _KiwiGoldCoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = min(w, h) / 2;

    // 1. Drop shadow / Outer glow
    final shadowPaint = Paint()
      ..color = const Color(0xFFB45309).withOpacity(0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(1.0, radius * 0.3));
    canvas.drawCircle(
      center + Offset(0, radius * 0.12),
      radius * 0.92,
      shadowPaint,
    );

    // 2. Coin body gradient
    final coinRect = Rect.fromCircle(center: center, radius: radius * 0.95);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFDF00), // bright gold
          Color(0xFFF59E0B), // warm amber
          Color(0xFFD97706), // deep gold
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(coinRect);
    canvas.drawCircle(center, radius * 0.95, bodyPaint);

    // 3. Outer rim highlight border
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, radius * 0.16)
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFBEB), Color(0xFFFDE68A), Color(0xFFB45309)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(coinRect);
    canvas.drawCircle(center, radius * 0.90, rimPaint);

    // 4. Inner grooved ring
    final groovePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.5, radius * 0.08)
      ..color = const Color(0xFF78350F).withOpacity(0.25);
    canvas.drawCircle(center, radius * 0.72, groovePaint);

    // 5. Specular shine arc on top-left
    final shinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, radius * 0.12)
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.55);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.80),
      -2.5,
      1.2,
      false,
      shinePaint,
    );

    // 6. Geometric 'K' glyph drawn with crisp vector paths
    final glyphPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.1, radius * 0.32)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Vertical stem
    path.moveTo(w * 0.37, h * 0.28);
    path.lineTo(w * 0.37, h * 0.72);
    canvas.drawPath(path, glyphPaint);

    // Upper diagonal arm
    final upperPath = Path()
      ..moveTo(w * 0.37, h * 0.50)
      ..lineTo(w * 0.65, h * 0.29);
    canvas.drawPath(upperPath, glyphPaint);

    // Lower diagonal leg
    final lowerPath = Path()
      ..moveTo(w * 0.44, h * 0.46)
      ..lineTo(w * 0.66, h * 0.71);
    canvas.drawPath(lowerPath, glyphPaint);
  }

  @override
  bool shouldRepaint(covariant _KiwiGoldCoinPainter oldDelegate) => false;
}
