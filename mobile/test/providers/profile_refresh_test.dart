import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/user_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends MockUserRepository {
  Completer<UserModel>? pending;
  Object? failure;
  @override
  Future<UserModel> fetchProfile(String token) {
    final failure = this.failure;
    if (failure != null) return Future<UserModel>.error(failure);
    return pending?.future ??
        Future.value(
          const UserModel(
            id: 'user-1',
            displayName: 'Fresh name',
            trustScore: 76,
            isVerified: true,
          ),
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<AuthProvider> restore(_Repository repo) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'token',
      'current_user':
          '{"id":"user-1","displayName":"Cached name","trustScore":100,"isVerified":false}',
    });
    final auth = AuthProvider(userRepository: repo);
    await Future<void>.delayed(Duration.zero);
    return auth;
  }

  test('refresh replaces cached score and persists server profile', () async {
    final auth = await restore(_Repository());
    await auth.refreshProfile();
    expect(auth.currentUser!.trustScore, 76);
    expect(auth.currentUser!.displayName, 'Fresh name');
    expect(
      (await SharedPreferences.getInstance()).getString('current_user'),
      contains('Fresh name'),
    );
    auth.dispose();
  });
  test('late refresh cannot restore a logged-out account', () async {
    final repo = _Repository()..pending = Completer<UserModel>();
    final auth = await restore(repo);
    final refresh = auth.refreshProfile();
    await auth.clearSession();
    repo.pending!.complete(
      const UserModel(
        id: 'user-1',
        displayName: 'Old account',
        trustScore: 99,
        isVerified: true,
      ),
    );
    await refresh;
    expect(auth.currentUser, isNull);
    expect(
      (await SharedPreferences.getInstance()).getString('current_user'),
      isNull,
    );
    auth.dispose();
  });
  test('expired profile refresh can clear the active session', () async {
    final repo = _Repository()..failure = const UserAuthenticationException();
    final auth = await restore(repo);
    await expectLater(
      auth.refreshProfile(),
      throwsA(isA<UserAuthenticationException>()),
    );
    await auth.clearSession();
    expect(auth.currentUser, isNull);
    expect(auth.jwtToken, isNull);
    auth.dispose();
  });
}
