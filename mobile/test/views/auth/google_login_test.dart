import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/user_model.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/models/public_profile_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/views/auth/login_view.dart';
import 'package:provider/provider.dart';

class MockGoogleUserRepository implements UserRepository {
  int googleLoginCalls = 0;
  String? lastIdToken;

  @override
  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    googleLoginCalls++;
    lastIdToken = idToken;
    return {
      'user': const UserModel(
        id: 'google_test_user_id',
        displayName: 'Google Kiwi',
        avatarUrl: 'https://example.com/avatar.jpg',
        trustScore: 100,
        kiwiGold: 100,
        isVerified: true,
        authProvider: 'google',
      ),
      'token': 'mock_jwt_token_for_google',
    };
  }

  @override
  Future<Map<String, dynamic>> loginWithPassword({
    required String email,
    required String password,
  }) async => {};

  @override
  Future<Map<String, dynamic>> registerWithPassword({
    required String email,
    required String password,
    required String displayName,
  }) async => {};

  @override
  Future<Map<String, dynamic>> verifyOtp(
    String email,
    String code, {
    String? displayName,
  }) async => {};

  @override
  Future<void> sendOtp(String email) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {}

  @override
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<UserModel> fetchProfile(String token) => updateProfile(token: token);

  @override
  Future<UserModel> updateProfile({
    required String token,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async => const UserModel(
    id: 'test_id',
    displayName: 'Test',
    trustScore: 100,
    kiwiGold: 100,
    isVerified: true,
  );

  @override
  Future<UserModel> updateBio(String bio, {required String token}) async => const UserModel(
    id: 'test_id',
    displayName: 'Test',
    trustScore: 100,
    kiwiGold: 100,
    isVerified: true,
  );

  @override
  Future<PublicProfileModel> fetchPublicProfile(String userId, {String? token}) async => const PublicProfileModel(
    id: 'test_id',
    displayName: 'Test',
    bio: '',
    city: 'Auckland',
    suburb: 'CBD',
    trustScore: 100,
    isVip: false,
    isVerified: true,
    isStudentVerified: false,
    rating: 5.0,
    reviewCount: 0,
    activeItemsCount: 0,
    soldItemsCount: 0,
  );

  @override
  Future<List<ItemModel>> fetchUserPublicItems(String userId, {String status = 'active', String? token}) async => [];

  @override
  Future<List<PublicReviewModel>> fetchUserPublicReviews(String userId, {String? token}) async => [];

  @override
  Future<String> sendStudentVerificationOtp({
    required String email,
    required String token,
  }) async => '';

  @override
  Future<UserModel> verifyStudentOtp({
    required String email,
    required String code,
    required String token,
  }) async => const UserModel(
    id: 'test_id',
    displayName: 'Test',
    trustScore: 100,
    kiwiGold: 100,
    isVerified: true,
  );
}

void main() {
  group('Google Login View and UserModel Tests', () {
    test('UserModel default constructor and JSON serialization assign 100 KiwiGold and 100 Trust Score', () {
      const user = UserModel(
        id: 'u1',
        displayName: 'Sam',
        trustScore: 100,
        isVerified: true,
      );

      expect(user.kiwiGold, equals(100));
      expect(user.trustScore, equals(100));

      final json = user.toJson();
      expect(json['kiwiGold'], equals(100));
      expect(json['trustScore'], equals(100));

      final parsed = UserModel.fromJson({
        'id': 'u2',
        'displayName': 'Alex',
        'isVerified': true,
      });
      expect(parsed.kiwiGold, equals(100));
      expect(parsed.trustScore, equals(100));
    });

    testWidgets('Google Sign-In button renders with proper label in login mode', (tester) async {
      final fakeRepo = MockGoogleUserRepository();
      final authProvider = AuthProvider(userRepository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: authProvider,
              child: const LoginView(isSignUp: false),
            ),
          ),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_in_button'));
      expect(googleButton, findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('Google Sign-In button renders with proper label in signup mode', (tester) async {
      final fakeRepo = MockGoogleUserRepository();
      final authProvider = AuthProvider(userRepository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: authProvider,
              child: const LoginView(isSignUp: true),
            ),
          ),
        ),
      );

      final googleButton = find.byKey(const Key('google_sign_in_button'));
      expect(googleButton, findsOneWidget);
      expect(find.text('Sign up with Google'), findsOneWidget);
    });
  });
}
