import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiwishare/main.dart';
import 'package:kiwishare/services/push_notification_service.dart';
import 'package:kiwishare/views/splash/splash_screen.dart';

void main() {
  test('foreground chat action revalidates the active account', () {
    const message = ChatPushMessage(
      conversationId: 'conversation-1',
      recipientId: 'account-a',
      itemId: 'item-1',
      itemTitle: 'Chair',
      participantId: 'seller-1',
      participantName: 'Seller',
    );

    expect(shouldOpenChatNotificationForUser(message, 'account-a'), isTrue);
    expect(shouldOpenChatNotificationForUser(message, 'account-b'), isFalse);
    expect(shouldOpenChatNotificationForUser(message, null), isFalse);
  });

  testWidgets('cold-start notification replaces the pending splash route', (
    tester,
  ) async {
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) =>
              SplashScreen(onSplashComplete: () => context.go('/home')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/messages/:conversationId',
          builder: (_, state) => Scaffold(
            body: Text('Chat ${state.pathParameters['conversationId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    navigateToNotificationRoute(router, '/messages/conversation-1');
    await tester.pumpAndSettle();
    expect(find.text('Chat conversation-1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300));
    expect(find.text('Chat conversation-1'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('warm notification preserves the existing route stack', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/messages/:conversationId',
          builder: (_, state) => Scaffold(
            body: Text('Chat ${state.pathParameters['conversationId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    navigateToNotificationRoute(router, '/messages/conversation-1');
    await tester.pumpAndSettle();
    expect(find.text('Chat conversation-1'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
