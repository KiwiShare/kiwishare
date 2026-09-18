import 'dart:math';
import 'package:flutter/material.dart';

/// A crisp, vector-rendered royal crown icon for KiwiShare VIP.
/// Renders with luxury gold gradient, sculpted peaks, and jewels.
/// Scales seamlessly without font glyph dependencies or clipping.
class VipCrownIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final List<Color>? gradientColors;

  const VipCrownIcon({
    super.key,
    this.size = 18,
    this.color,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _VipCrownPainter(
          solidColor: color,
          customGradient: gradientColors,
        ),
      ),
    );
  }
}

class _VipCrownPainter extends CustomPainter {
  final Color? solidColor;
  final List<Color>? customGradient;

  _VipCrownPainter({this.solidColor, this.customGradient});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // If solid color is provided, use it. Otherwise use the rich royal gold gradient.
    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    if (solidColor != null) {
      fillPaint.color = solidColor!;
    } else {
      fillPaint.shader = LinearGradient(
        colors:
            customGradient ??
            const [
              Color(0xFFFFFBEB), // Pale champagne highlight
              Color(0xFFFFDF73), // Brilliant gold
              Color(0xFFF59E0B), // Warm amber gold
              Color(0xFFD97706), // Deep burnished gold
            ],
        stops: const [0.0, 0.35, 0.75, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    }

    // 1. Soft ambient shadow under crown
    if (solidColor == null && w >= 14) {
      final shadowPaint = Paint()
        ..color = const Color(0xFF78350F).withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(1.0, w * 0.1));
      final baseShadow = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.12, h * 0.76, w * 0.76, h * 0.14),
            Radius.circular(w * 0.06),
          ),
        );
      canvas.drawPath(baseShadow, shadowPaint);
    }

    // 2. Crown Peaks Body Path (Regal 5-peak royal crown)
    final crownPath = Path();
    // Start at bottom-left of body
    crownPath.moveTo(w * 0.13, h * 0.73);

    // Left outer peak (flared slightly)
    crownPath.lineTo(w * 0.10, h * 0.34);
    // Valley between left & mid-left
    crownPath.quadraticBezierTo(w * 0.22, h * 0.56, w * 0.31, h * 0.44);
    // Mid-left peak
    crownPath.lineTo(w * 0.33, h * 0.30);
    // Valley to center peak
    crownPath.quadraticBezierTo(w * 0.41, h * 0.54, w * 0.50, h * 0.18);
    // Valley from center to mid-right
    crownPath.quadraticBezierTo(w * 0.59, h * 0.54, w * 0.67, h * 0.30);
    // Mid-right peak
    crownPath.lineTo(w * 0.69, h * 0.44);
    // Valley between mid-right & right outer
    crownPath.quadraticBezierTo(w * 0.78, h * 0.56, w * 0.90, h * 0.34);
    // Right outer peak
    crownPath.lineTo(w * 0.87, h * 0.73);
    // Bottom curve of crown body
    crownPath.quadraticBezierTo(w * 0.50, h * 0.78, w * 0.13, h * 0.73);
    crownPath.close();

    canvas.drawPath(crownPath, fillPaint);

    // 3. Crown Base Band (Arch-shaped headband)
    final bandRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.74, w * 0.76, h * 0.14),
      Radius.circular(w * 0.05),
    );
    final bandPaint = Paint()..style = PaintingStyle.fill;
    if (solidColor != null) {
      bandPaint.color = solidColor!;
    } else {
      bandPaint.shader = const LinearGradient(
        colors: [Color(0xFFFFF7C2), Color(0xFFF59E0B), Color(0xFFB45309)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
    }
    canvas.drawRRect(bandRect, bandPaint);

    // 4. Base band border/trim
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.6, w * 0.04)
      ..color = solidColor != null
          ? solidColor!.withValues(alpha: 0.6)
          : const Color(0xFF78350F).withValues(alpha: 0.4);
    canvas.drawRRect(bandRect, strokePaint);

    // 5. Crown jewels on peak tips (golden spheres / pearls)
    final jewelPaint = Paint()..style = PaintingStyle.fill;
    if (solidColor != null) {
      jewelPaint.color = solidColor!;
    } else {
      jewelPaint.color = const Color(0xFFFFFBEB);
    }

    final double centerR = max(1.0, w * 0.075);
    final double midR = max(0.8, w * 0.06);
    final double sideR = max(0.8, w * 0.06);

    // Center tall peak jewel
    canvas.drawCircle(Offset(w * 0.50, h * 0.18), centerR, jewelPaint);
    // Mid-left peak jewel
    canvas.drawCircle(Offset(w * 0.33, h * 0.30), midR, jewelPaint);
    // Mid-right peak jewel
    canvas.drawCircle(Offset(w * 0.67, h * 0.30), midR, jewelPaint);
    // Outer-left peak jewel
    canvas.drawCircle(Offset(w * 0.10, h * 0.34), sideR, jewelPaint);
    // Outer-right peak jewel
    canvas.drawCircle(Offset(w * 0.90, h * 0.34), sideR, jewelPaint);

    // 6. Jewels on the base headband (3 micro diamond studs)
    if (w >= 14) {
      final studPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = solidColor != null
            ? Colors.white.withValues(alpha: 0.8)
            : const Color(0xFFFFFBEB);
      final studR = max(0.6, w * 0.035);
      canvas.drawCircle(Offset(w * 0.30, h * 0.81), studR, studPaint);
      canvas.drawCircle(Offset(w * 0.50, h * 0.81), studR * 1.2, studPaint);
      canvas.drawCircle(Offset(w * 0.70, h * 0.81), studR, studPaint);
    }

    // 7. Specular highlight across left side for metallic 3D sheen
    if (solidColor == null && w >= 16) {
      final shinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(0.7, w * 0.04)
        ..color = Colors.white.withValues(alpha: 0.6);
      final shinePath = Path();
      shinePath.moveTo(w * 0.14, h * 0.40);
      shinePath.lineTo(w * 0.20, h * 0.65);
      canvas.drawPath(shinePath, shinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VipCrownPainter oldDelegate) {
    return oldDelegate.solidColor != solidColor ||
        oldDelegate.customGradient != customGradient;
  }
}
