import 'dart:math';
import 'package:flutter/material.dart';

/// A crisp, vector-rendered KiwiGold "K" badge icon for KiwiShare VIP.
/// Renders with luxury gold metallic gradient, sculpted bevel, and crisp "K" emblem.
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
    final center = Offset(w / 2, h / 2);
    final radius = min(w, h) * 0.46;

    // 1. Base Coin / Rounded Badge with Gold Gradient
    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    if (solidColor != null) {
      fillPaint.color = solidColor!;
    } else {
      fillPaint.shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.9,
        colors:
            customGradient ??
            const [
              Color(0xFFFFFBEB), // Pale champagne highlight
              Color(0xFFFFDF73), // Brilliant gold
              Color(0xFFF59E0B), // Warm amber gold
              Color(0xFFB45309), // Burnished deep gold
            ],
        stops: const [0.0, 0.4, 0.75, 1.0],
      ).createShader(rect);
    }

    final badgeRRect = RRect.fromRectAndRadius(
      Rect.fromCircle(center: center, radius: radius),
      Radius.circular(radius * 0.45),
    );

    // Soft drop shadow under the badge
    if (solidColor == null && w >= 14) {
      final shadowPaint = Paint()
        ..color = const Color(0xFF78350F).withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, max(1.0, w * 0.08));
      canvas.drawRRect(badgeRRect.shift(Offset(0, h * 0.04)), shadowPaint);
    }

    canvas.drawRRect(badgeRRect, fillPaint);

    // 2. Metallic Outer Rim
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, w * 0.07);
    if (solidColor != null) {
      rimPaint.color = solidColor!.withValues(alpha: 0.7);
    } else {
      rimPaint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFFFFFBEB), Color(0xFFF59E0B), Color(0xFF78350F)],
      ).createShader(rect);
    }
    canvas.drawRRect(badgeRRect, rimPaint);

    // 3. Crisp Sculpted "K" Vector Glyph in Center
    final kPaint = Paint()..style = PaintingStyle.fill;
    if (solidColor != null) {
      kPaint.color = Colors.white;
    } else {
      kPaint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
      ).createShader(rect);
    }

    // Shadow behind the "K" for 3D embossed depth
    if (solidColor == null && w >= 14) {
      final kShadowPaint = Paint()
        ..color = const Color(0xFF78350F).withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      final kShadowPath = _createKPath(w, h, offset: Offset(0, h * 0.03));
      canvas.drawPath(kShadowPath, kShadowPaint);
    }

    final kPath = _createKPath(w, h);
    canvas.drawPath(kPath, kPaint);

    // 4. Subtle Top-left Specular Sheen
    if (solidColor == null && w >= 14) {
      final sheenPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(0.6, w * 0.05)
        ..color = Colors.white.withValues(alpha: 0.65);
      final sheenPath = Path()
        ..addArc(
          Rect.fromCircle(center: center, radius: radius * 0.75),
          -2.6,
          0.8,
        );
      canvas.drawPath(sheenPath, sheenPaint);
    }
  }

  Path _createKPath(double w, double h, {Offset offset = Offset.zero}) {
    final path = Path();
    final ox = offset.dx;
    final oy = offset.dy;

    // Stem: vertical bar on left
    final stemLeft = w * 0.30 + ox;
    final stemRight = w * 0.42 + ox;
    final stemTop = h * 0.24 + oy;
    final stemBottom = h * 0.76 + oy;

    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(stemLeft, stemTop, stemRight, stemBottom),
        Radius.circular(w * 0.03),
      ),
    );

    // Upper diagonal branch of "K"
    final upPath = Path()
      ..moveTo(w * 0.39 + ox, h * 0.52 + oy)
      ..lineTo(w * 0.64 + ox, h * 0.25 + oy)
      ..lineTo(w * 0.75 + ox, h * 0.25 + oy)
      ..lineTo(w * 0.48 + ox, h * 0.55 + oy)
      ..close();
    path.addPath(upPath, Offset.zero);

    // Lower diagonal branch of "K"
    final downPath = Path()
      ..moveTo(w * 0.43 + ox, h * 0.49 + oy)
      ..lineTo(w * 0.53 + ox, h * 0.49 + oy)
      ..lineTo(w * 0.76 + ox, h * 0.76 + oy)
      ..lineTo(w * 0.63 + ox, h * 0.76 + oy)
      ..close();
    path.addPath(downPath, Offset.zero);

    return path;
  }

  @override
  bool shouldRepaint(covariant _VipCrownPainter oldDelegate) {
    return oldDelegate.solidColor != solidColor ||
        oldDelegate.customGradient != customGradient;
  }
}
