import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'authenticated login activates push and logout deactivates it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final pushSession = _FakePushNotificationSession();
      final auth = AuthProvider(
        userRepository: MockUserRepository(),
        pushNotifications: pushSession,
      );
      await Future<void>.delayed(Duration.zero);

      await auth.login('watcher@example.com', 'password');
      await Future<void>.delayed(Duration.zero);
      expect(pushSession.activatedTokens, ['mock_jwt_token']);

      await auth.logout();
      expect(pushSession.deactivatedTokens, ['mock_jwt_token']);
    },
  );
}

class _FakePushNotificationSession implements PushNotificationSession {
  final activatedTokens = <String>[];
  final deactivatedTokens = <String>[];

  @override
  Future<void> activate(String jwtToken) async {
    activatedTokens.add(jwtToken);
  }

  @override
  Future<void> deactivate(String jwtToken) async {
    deactivatedTokens.add(jwtToken);
  }
}
