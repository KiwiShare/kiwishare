import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kiwishare/main.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/home_discovery_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'opens Publish after signing in from the centre navigation action',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          ShellRoute(
            builder: (context, state, child) => KiwiShareShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const Scaffold(
                  body: Center(child: Text('Home test destination')),
                ),
              ),
              GoRoute(
                path: '/post',
                builder: (context, state) => const Scaffold(
                  body: Center(
                    child: Text(
                      'Post test destination',
                      key: Key('post_test_destination'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(userRepository: MockUserRepository()),
            ),
            ChangeNotifierProvider(create: (_) => HomeDiscoveryProvider()),
          ],
          child: MaterialApp.router(
            theme: buildKiwiShareTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      if (find.text('Use Username & Password Login').evaluate().isNotEmpty) {
        await tester.tap(find.text('Use Username & Password Login'));
        await tester.pumpAndSettle();
      }

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username or Email'),
        'jack@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log In'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('post_test_destination')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
