import 'package:flutter/material.dart';

/// Displays the approved mark, including its original transparent clear space.
class KiwiShareLogo extends StatelessWidget {
  const KiwiShareLogo({super.key, required this.size});

  static const lightAsset =
      'assets/icons/kiwishare-app-icon_V1.5/master/kiwishare-mark-green-4096.png';
  static const darkAsset =
      'assets/icons/kiwishare-app-icon_V1.5/master/kiwishare-mark-ivory-4096.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Image.asset(
      Theme.of(context).brightness == Brightness.dark ? darkAsset : lightAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      cacheWidth: pixels,
      cacheHeight: pixels,
      // Both placements already have the adjacent KiwiShare wordmark.
      excludeFromSemantics: true,
    );
  }
}
