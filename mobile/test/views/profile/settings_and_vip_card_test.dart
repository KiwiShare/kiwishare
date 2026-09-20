import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/theme_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/views/profile/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Profile renders Settings icon and Xianyu VIP banner card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'jwt_token': 'test-token',
      'current_user':
          '{"id":"user-1","displayName":"Sam","trustScore":90,"isVerified":true,"isVip":false,"kiwiGoldBalance":50}',
    });

    final auth = AuthProvider(userRepository: MockUserRepository());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Settings icon in top right
    expect(find.byKey(const Key('profile-settings-button')), findsOneWidget);

    // 2. Verify Xianyu-style KiwiGold VIP banner card
    expect(find.text('KiwiGold VIP'), findsOneWidget);
    expect(find.text('Get VIP'), findsOneWidget);

    // 3. Tap Settings icon -> navigates to SettingsScreen
    await tester.tap(find.byKey(const Key('profile-settings-button')));
    await tester.pumpAndSettle();

    // Verify SettingsScreen content
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Message Push Notifications'), findsOneWidget);
    expect(find.text('Watchlist Price Drop Alerts'), findsOneWidget);
    expect(
      find.byKey(const Key('settings-watchlist-price-alerts-switch')),
      findsOneWidget,
    );
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Student Verification'), findsOneWidget);

    // Tap Student Verification -> opens student verification sheet directly
    await tester.tap(find.text('Student Verification'));
    await tester.pumpAndSettle();
    expect(find.text('NZ Student Verification'), findsOneWidget);
    expect(find.text('Send Verification Code'), findsOneWidget);

    // Dismiss sheet
    Navigator.of(tester.element(find.text('NZ Student Verification'))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sign Out'), 100);
    expect(find.text('Sign Out'), findsOneWidget);

    // Go back to profile
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 4. Tap VIP card button -> opens KiwiGold TopUp / VIP sheet
    await tester.tap(find.text('Get VIP'));
    await tester.pumpAndSettle();

    // Verify VIP sheet opened
    expect(find.text('VIP Monthly Membership'), findsOneWidget);

    // Verify Boost & Perks is NOT rendered in profile
    expect(find.text('Boost & Perks'), findsNothing);
  });

  testWidgets(
    'VIP user can open management sheet and cancel next month renewal',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'jwt_token': 'test-token',
        'current_user':
            '{"id":"user-1","displayName":"VIP Sam","trustScore":95,"isVerified":true,"isVip":true,"vipAutoRenew":true,"vipExpiresAt":"2026-10-18T12:00:00.000Z","kiwiGoldBalance":100}',
      });

      final auth = AuthProvider(userRepository: MockUserRepository());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify VIP active banner & Manage button
      expect(find.text('KiwiGold VIP'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.text('Manage'), findsOneWidget);

      // 2. Tap Manage -> opens VIP management sheet
      await tester.tap(find.text('Manage'));
      await tester.pumpAndSettle();

      expect(find.text('KiwiGold VIP Membership'), findsOneWidget);
      expect(find.text('Cancel Next Month\'s Renewal'), findsOneWidget);

      // 3. Tap Cancel Next Month's Renewal -> shows confirmation dialog
      await tester.tap(find.text('Cancel Next Month\'s Renewal'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel VIP Auto-Renewal?'), findsOneWidget);
      expect(find.text('Confirm Cancellation'), findsOneWidget);

      // 4. Confirm cancellation
      await tester.tap(find.text('Confirm Cancellation'));
      await tester.pumpAndSettle();

      // Verify cancellation snackbar feedback
      expect(find.textContaining('VIP auto-renewal cancelled'), findsOneWidget);
    },
  );
}
