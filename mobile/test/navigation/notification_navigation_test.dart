import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiwishare/main.dart';
import 'package:kiwishare/views/splash/splash_screen.dart';

void main() {
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
