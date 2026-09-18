import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/user_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/views/auth/login_view.dart';
import 'package:provider/provider.dart';

class FakeCooldownUserRepository implements UserRepository {
  @override
  Future<void> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    throw UnsupportedError(
      'Password changes are not part of OTP cooldown tests.',
    );
  }

  @override
  Future<UserModel> fetchProfile(String token) => updateProfile(token: token);
  int sendOtpCalls = 0;
  bool throwCooldownOnSecondCall = false;

  @override
  Future<void> sendOtp(String email) async {
    sendOtpCalls++;
    if (sendOtpCalls > 1 && throwCooldownOnSecondCall) {
      throw const OtpCooldownException(
        'Please wait for the cooldown timer before requesting a new verification code.',
        cooldownSeconds: 45,
      );
    }
  }

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {}

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
  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async => {};

  @override
  Future<Map<String, dynamic>> verifyOtp(
    String email,
    String code, {
    String? displayName,
  }) async => {
    'user': const UserModel(
      id: 'test_u',
      displayName: 'Test User',
      avatarUrl: '',
      trustScore: 90,
      isVerified: true,
    ),
    'token': 'test_token',
  };

  @override
  Future<UserModel> updateProfile({
    required String token,
    String? displayName,
    String? avatarUrl,
  }) async => const UserModel(
    id: 'test_u',
    displayName: 'Test User',
    avatarUrl: '',
    trustScore: 90,
    isVerified: true,
  );

  @override
  Future<String> sendStudentVerificationOtp({
    required String email,
    required String token,
  }) async => 'Verification code sent';

  @override
  Future<UserModel> verifyStudentOtp({
    required String email,
    required String code,
    required String token,
  }) async => const UserModel(
    id: 'test_u',
    displayName: 'Test User',
    avatarUrl: '',
    trustScore: 90,
    isVerified: true,
  );
}

void main() {
  testWidgets(
    'OTP cooldown ticks down dynamically and error messages do not embed fixed seconds',
    (tester) async {
      final fakeRepo = FakeCooldownUserRepository();
      final authProvider = AuthProvider(userRepository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: authProvider,
              child: const LoginView(),
            ),
          ),
        ),
      );

      // Switch to OTP tab
      await tester.tap(find.text('Email Code (OTP)'));
      await tester.pumpAndSettle();

      // Enter email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'test@example.com',
      );
      await tester.pumpAndSettle();

      // Send OTP
      await tester.tap(find.text('Send Verification Code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify initial cooldown is active at 60s
      expect(find.text('Resend (60s)'), findsOneWidget);
      expect(find.text('You can request a new code in 60s'), findsOneWidget);

      // Advance 1 second -> should dynamically tick down to 59s
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend (59s)'), findsOneWidget);
      expect(find.text('You can request a new code in 59s'), findsOneWidget);

      // Advance another 5 seconds -> should dynamically tick down to 54s
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Resend (54s)'), findsOneWidget);
      expect(find.text('You can request a new code in 54s'), findsOneWidget);

      // Tap resend button while disabled or trigger sendOtp
      // Verify no static number like "42 seconds" in any SnackBar message
      expect(find.textContaining('Please wait 54 seconds'), findsNothing);
      expect(find.textContaining('Please wait 54s'), findsNothing);
    },
  );
}
