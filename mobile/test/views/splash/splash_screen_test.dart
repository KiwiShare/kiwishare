import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/views/splash/splash_screen.dart';
import 'package:kiwishare/widgets/kiwishare_logo.dart';

void main() {
  testWidgets('startup uses centered approved logo and retains timing', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(home: SplashScreen(onSplashComplete: () => completed++)),
    );
    expect(find.byIcon(Icons.spa), findsNothing);
    expect(find.text('KiwiShare'), findsOneWidget);
    expect(find.text('Buy. Sell. Share. Sustain.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.getSize(find.byType(KiwiShareLogo)), const Size(100, 100));
    expect(
      tester.getCenter(find.byType(KiwiShareLogo)).dx,
      tester.getCenter(find.byType(Scaffold)).dx,
    );
    await tester.pump(const Duration(milliseconds: 2199));
    expect(completed, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(completed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
