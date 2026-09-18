import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/widgets/top_notification_banner.dart';

void main() {
  group('TopNotificationBanner', () {
    testWidgets('renders at the top and executes action callback', (
      tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showTopNotification(
                    navigatorKey: navKey,
                    title: 'New Message',
                    body: 'Hello Kiwi!',
                    icon: Icons.chat_bubble_rounded,
                    actionLabel: 'Reply',
                    onAction: () => actionTapped = true,
                  );
                },
                child: const Text('Trigger Notification'),
              ),
            ),
          ),
        ),
      );

      // Trigger notification
      await tester.tap(find.text('Trigger Notification'));
      await tester.pumpAndSettle();

      // Verify notification appears at top
      expect(find.text('New Message'), findsOneWidget);
      expect(find.text('Hello Kiwi!'), findsOneWidget);
      expect(find.text('Reply'), findsOneWidget);

      // Verify position is near top of screen
      final titleTop = tester.getTopLeft(find.text('New Message')).dy;
      expect(titleTop, lessThan(150));

      // Tap action
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();

      expect(actionTapped, isTrue);
    });

    testWidgets('dismisses immediately with dismissCurrentTopNotification', (
      tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showTopNotification(
                    navigatorKey: navKey,
                    title: 'Test Notification',
                    body: 'Body text',
                    icon: Icons.info,
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Test Notification'), findsOneWidget);

      dismissCurrentTopNotification();
      await tester.pumpAndSettle();
      expect(find.text('Test Notification'), findsNothing);
    });
  });
}
