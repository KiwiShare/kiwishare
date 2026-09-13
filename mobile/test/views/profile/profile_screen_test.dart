import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/theme_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/services/notification_permission_coordinator.dart';
import 'package:kiwishare/views/profile/notification_settings_screen.dart';
import 'package:kiwishare/views/profile/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('signed-in Profile opens notification recovery from Preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'restored-token',
      'current_user':
          '{"id":"user-1","displayName":"Riley","trustScore":100,"isVerified":true}',
    });
    final auth = AuthProvider(userRepository: MockUserRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          Provider<NotificationPermissionCoordinator>.value(
            value: NotificationPermissionCoordinator(
              permissionController: null,
              storage: _Storage(),
            ),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  });

  testWidgets('signed-in Profile renders Xianyu marketplace grid and trust badge', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'restored-token',
      'current_user':
          '{"id":"user-1","displayName":"Riley","trustScore":95,"isVerified":true}',
    });
    final auth = AuthProvider(userRepository: MockUserRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          Provider<NotificationPermissionCoordinator>.value(
            value: NotificationPermissionCoordinator(
              permissionController: null,
              storage: _Storage(),
            ),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify user info and trust badge
    expect(find.text('Riley'), findsOneWidget);
    expect(find.text('Trust score 95/100'), findsOneWidget);
    expect(find.byKey(const Key('profile-scan-qr-button')), findsOneWidget);

    // Verify Xianyu 3-column marketplace action grid
    expect(find.text('My marketplace'), findsOneWidget);
    expect(find.text('Selling'), findsOneWidget);
    expect(find.text('Sold'), findsOneWidget);
    expect(find.text('Meetups'), findsOneWidget);

    // Verify preference & safety sections
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Safety & support'), findsOneWidget);
    expect(find.text('Report a safety issue'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Log out'), 200);
    expect(find.text('Log out'), findsOneWidget);

    // Check that Divider widgets are wrapped with left padding (56) to avoid full-width black cut lines
    final dividerFinder = find.byType(Divider);
    expect(dividerFinder, findsOneWidget);
    final nearestPadding = tester.widget<Padding>(
      find.ancestor(of: dividerFinder, matching: find.byType(Padding)).first,
    );
    final insets = nearestPadding.padding as EdgeInsets;
    expect(insets.left, 56.0);
    expect(insets.right, 16.0);
  });
}

class _Storage implements NotificationPermissionStorage {
  @override
  Future<int?> getNextEligibleAtMs() async => null;

  @override
  Future<void> setNextEligibleAtMs(int value) async {}

  @override
  Future<void> removeObsoleteDismissal() async {}
}
