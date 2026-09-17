import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/widgets/kiwishare_logo.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [48.0, 100.0]) {
      testWidgets('approved $brightness mark at $size preserves artwork', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Center(child: KiwiShareLogo(size: size)),
          ),
        );
        await tester.pumpAndSettle();
        final image = tester.widget<Image>(find.byType(Image));
        final provider = image.image as ResizeImage;
        expect(
          (provider.imageProvider as AssetImage).assetName,
          brightness == Brightness.dark
              ? KiwiShareLogo.darkAsset
              : KiwiShareLogo.lightAsset,
        );
        expect(tester.getSize(find.byType(Image)), Size.square(size));
        expect(image.fit, BoxFit.contain);
        expect(image.color, isNull);
        expect(image.excludeFromSemantics, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
