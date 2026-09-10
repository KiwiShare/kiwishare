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
}

class _Storage implements NotificationPermissionStorage {
  @override
  Future<int?> getNextEligibleAtMs() async => null;

  @override
  Future<void> setNextEligibleAtMs(int value) async {}

  @override
  Future<void> removeObsoleteDismissal() async {}
}
