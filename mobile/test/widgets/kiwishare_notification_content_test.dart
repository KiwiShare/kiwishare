import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/widgets/kiwishare_notification_content.dart';

void main() {
  testWidgets('notification content scales and exposes one live-region label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKiwiShareTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            child: KiwiShareNotificationContent(
              title: 'Price drop on a saved item',
              body: 'Oak chair dropped from \$100.00 to \$80.00',
              icon: Icons.trending_down_rounded,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Price drop on a saved item'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(KiwiShareNotificationContent)).label,
      equals(
        'Price drop on a saved item. Oak chair dropped from \$100.00 to \$80.00',
      ),
    );
    semantics.dispose();
  });
}
