import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/user_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/meetup_provider.dart';
import 'package:kiwishare/providers/theme_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/profile/profile_screen.dart';
import 'package:kiwishare/views/scanner/qr_scanner_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../meetups/meetup_flow_test.dart';

void main() {
  group('QR Scanner and Profile Screen Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'test-jwt-token',
        'current_user': jsonEncode({
          'id': 'buyer-user-id',
          'displayName': 'Buyer User',
          'trustScore': 100,
          'isVerified': true,
        }),
      });
    });

    testWidgets('ProfileScreen renders scan QR button in AppBar', (
      tester,
    ) async {
      final fakeRepo = FakeMeetupRepository();
      final meetupProvider = MeetupProvider(repository: fakeRepo);
      final authProvider = AuthProvider(userRepository: MockUserRepository());
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: meetupProvider),
            ChangeNotifierProvider.value(value: authProvider),
            ChangeNotifierProvider.value(value: themeProvider),
          ],
          child: MaterialApp(
            theme: buildKiwiShareTheme(),
            home: const ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('profile-scan-qr-button')), findsOneWidget);
    });

    testWidgets(
      'QrScannerScreen renders manual code input and successfully claims handover',
      (tester) async {
        final fakeRepo = FakeMeetupRepository();
        final meetupProvider = MeetupProvider(repository: fakeRepo);
        final userRepository = _RefreshingUserRepository();
        final authProvider = AuthProvider(userRepository: userRepository);
        final themeProvider = ThemeProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: meetupProvider),
              ChangeNotifierProvider.value(value: authProvider),
              ChangeNotifierProvider.value(value: themeProvider),
            ],
            child: MaterialApp(
              theme: buildKiwiShareTheme(),
              home: const QrScannerScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Verify screen controls exist
        expect(find.text('Scan QR Code'), findsOneWidget);
        expect(find.text('Enter Code'), findsOneWidget);
        expect(find.text('Album'), findsOneWidget);

        // 2. Tap "Enter Code" to open manual entry dialog
        await tester.tap(find.text('Enter Code'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Enter Handover Code'), findsOneWidget);
        expect(find.text('Verify & Claim'), findsOneWidget);

        // 3. Enter token and verify
        await tester.enterText(
          find.byType(TextField),
          'QR_HANDOVER_TOKEN_ORDER999_XYZ',
        );
        await tester.tap(find.text('Verify & Claim'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 4. Verify success dialog displayed with item details
        expect(find.text('Handover Complete!'), findsOneWidget);
        expect(find.text('Test Item'), findsOneWidget);
        expect(find.text('\$50 NZD'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(userRepository.fetchProfileCalls, 1);
        expect(authProvider.currentUser?.trustScore, 105);

        // 5. Dismiss dialog
        await tester.tap(find.text('Done'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });
}

class _RefreshingUserRepository extends MockUserRepository {
  int fetchProfileCalls = 0;

  @override
  Future<UserModel> fetchProfile(String token) async {
    fetchProfileCalls++;
    return const UserModel(
      id: 'buyer-user-id',
      displayName: 'Buyer User',
      trustScore: 105,
      isVerified: true,
    );
  }
}
