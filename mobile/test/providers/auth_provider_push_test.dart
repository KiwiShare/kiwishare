import 'dart:async';

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
      expect(pushSession.activatedUserIds, ['mock_user_1']);

      await auth.logout();
      expect(pushSession.deactivatedTokens, ['mock_jwt_token']);
    },
  );

  test('session listeners are notified before logout cleanup awaits', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(
      userRepository: MockUserRepository(),
      pushNotifications: _FakePushNotificationSession(),
    );
    await Future<void>.delayed(Duration.zero);
    await auth.login('watcher@example.com', 'password');

    var notifications = 0;
    auth.addListener(() => notifications += 1);

    final clearing = auth.clearSession();

    expect(auth.isLoggedIn, isFalse);
    expect(auth.currentUser, isNull);
    expect(auth.jwtToken, isNull);
    expect(notifications, 1);

    await clearing;
    expect(notifications, 1);
  });

  test('a new login waits for pending logout cleanup', () async {
    SharedPreferences.setMockInitialValues({});
    final deactivationGate = Completer<void>();
    final pushSession = _FakePushNotificationSession(
      deactivationGate: deactivationGate,
    );
    final repository = _RecordingUserRepository();
    final auth = AuthProvider(
      userRepository: repository,
      pushNotifications: pushSession,
    );
    await Future<void>.delayed(Duration.zero);
    await auth.login('first@example.com', 'password');
    expect(repository.passwordLoginCalls, 1);

    final logout = auth.logout();
    await Future<void>.delayed(Duration.zero);
    final nextLogin = auth.login('second@example.com', 'password');
    await Future<void>.delayed(Duration.zero);

    expect(repository.passwordLoginCalls, 1);
    deactivationGate.complete();
    await logout;
    await nextLogin;

    expect(repository.passwordLoginCalls, 2);
    expect(auth.currentUser?.displayName, 'second');
  });
}

class _FakePushNotificationSession implements PushNotificationSession {
  _FakePushNotificationSession({this.deactivationGate});

  final Completer<void>? deactivationGate;
  final activatedTokens = <String>[];
  final activatedUserIds = <String?>[];
  final deactivatedTokens = <String>[];

  @override
  Future<void> activate(String jwtToken, {String? userId}) async {
    activatedTokens.add(jwtToken);
    activatedUserIds.add(userId);
  }

  @override
  Future<void> deactivate(String jwtToken) async {
    deactivatedTokens.add(jwtToken);
    await deactivationGate?.future;
  }
}

class _RecordingUserRepository extends MockUserRepository {
  int passwordLoginCalls = 0;

  @override
  Future<Map<String, dynamic>> loginWithPassword({
    required String email,
    required String password,
  }) {
    passwordLoginCalls += 1;
    return super.loginWithPassword(email: email, password: password);
  }
}
