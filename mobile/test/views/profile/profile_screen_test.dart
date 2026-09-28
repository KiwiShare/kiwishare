import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/user_model.dart';
import 'package:go_router/go_router.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/theme_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/services/notification_permission_coordinator.dart';
import 'package:kiwishare/views/profile/notification_settings_screen.dart';
import 'package:kiwishare/views/profile/profile_screen.dart';
import 'package:kiwishare/views/profile/public_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed-in Profile opens the existing Watchlist route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'restored-token',
      'current_user':
          '{"id":"user-1","displayName":"Riley","trustScore":95,"isVerified":true}',
    });
    final auth = AuthProvider(userRepository: MockUserRepository());
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        GoRoute(
          path: '/watchlist',
          builder: (_, _) =>
              const Scaffold(body: Text('Watchlist destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watchlist'));
    await tester.pumpAndSettle();
    expect(find.text('Watchlist destination'), findsOneWidget);
  });

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

    await tester.scrollUntilVisible(find.text('Notifications'), 100);
    expect(find.text('Notifications'), findsOneWidget);
    await tester.ensureVisible(find.text('Notifications'));
    await tester.pump();
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
    expect(find.text('Riley'), findsWidgets);
    expect(find.text('Trust score 95'), findsOneWidget);
    expect(find.byKey(const Key('profile-support-button')), findsOneWidget);

    // Verify Xianyu 3-column marketplace action grid (6 modules)
    expect(find.text('My marketplace'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Meetups'), findsOneWidget);
    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('Listings'), findsOneWidget);
    expect(find.text('Sold'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);

    // Verify preference & safety sections
    await tester.scrollUntilVisible(find.text('Appearance'), 100);
    expect(find.text('Appearance'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Report a safety issue'), 100);
    expect(find.text('Safety & support'), findsOneWidget);
    expect(find.text('My reports'), findsOneWidget);
    expect(
      find.text('View your report history and review status'),
      findsOneWidget,
    );
    expect(find.text('Report a safety issue'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Log out'), 200);
    expect(find.text('Log out'), findsOneWidget);

    // Check that Divider widgets are wrapped with left padding (56) to avoid full-width black cut lines
    final dividerFinder = find.byType(Divider);
    expect(dividerFinder, findsNWidgets(3));
    final nearestPadding = tester.widget<Padding>(
      find.ancestor(of: dividerFinder, matching: find.byType(Padding)).first,
    );
    final insets = nearestPadding.padding as EdgeInsets;
    expect(insets.left, 56.0);
    expect(insets.right, 16.0);
  });

  testWidgets('public trust badge and semantics use 200+ above the ceiling', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'restored-token',
      'current_user':
          '{"id":"user-1","displayName":"Riley","trustScore":205,"isVerified":true}',
    });
    final auth = AuthProvider(
      userRepository: _FixedProfileRepository(trustScore: 205),
    );
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

    expect(find.text('Trust score 200+'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Trust score 200+')).label,
      contains('Trust score 200+'),
    );
    expect(find.textContaining('/100'), findsNothing);
    semantics.dispose();
  });

  testWidgets('Account & security exposes photo, nickname, and password', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'restored-token',
      'current_user':
          '{"id":"user-1","displayName":"Riley","username":"riley","trustScore":95,"isVerified":true,"authProvider":"email_password"}',
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

    await tester.scrollUntilVisible(find.text('Profile photo'), 100);
    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('@riley'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('password dialog supports visibility toggles and success message', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'restored-token',
      'current_user':
          '{"id":"user-1","displayName":"Riley","trustScore":95,"isVerified":true,"authProvider":"email_password"}',
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

    await tester.scrollUntilVisible(find.text('Change password'), 100);
    await tester.ensureVisible(find.text('Change password'));
    await tester.pump();
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();

    expect(find.text('Change password'), findsWidgets);
    expect(find.byTooltip('Show current password'), findsOneWidget);
    await tester.tap(find.byTooltip('Show current password'));
    await tester.pump();
    expect(find.byTooltip('Hide current password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Password changed successfully.'), findsOneWidget);
  });

  testWidgets('expired profile refresh clears session and explains re-login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'expired-token',
      'current_user':
          '{"id":"user-1","displayName":"Riley","trustScore":95,"isVerified":true}',
    });
    final auth = AuthProvider(
      userRepository: _FailingProfileRepository(
        const UserAuthenticationException(),
      ),
    );

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

    expect(auth.isLoggedIn, isFalse);
    expect(
      find.text('Your session has expired. Please sign in again.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'opens How KiwiShare Works and Help center from Safety & support',
    (tester) async {
      final auth = AuthProvider(userRepository: MockUserRepository());
      final theme = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ThemeProvider>.value(value: theme),
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

      await tester.scrollUntilVisible(find.text('How KiwiShare works'), 200);
      expect(find.text('How KiwiShare works'), findsOneWidget);
      expect(find.text('Help center & FAQs'), findsOneWidget);

      await tester.tap(find.text('How KiwiShare works'));
      await tester.pumpAndSettle();

      expect(find.text('Help & Guides'), findsOneWidget);
      expect(find.text('Welcome to KiwiShare'), findsOneWidget);
    },
  );

  testWidgets('signed-in Profile tapping avatar opens PublicProfileScreen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'restored-token',
      'current_user':
          '{"id":"user-1","displayName":"Riley","trustScore":95,"isVerified":true,"isVip":true}',
    });
    final userRepo = MockUserRepository();
    final auth = AuthProvider(userRepository: userRepo);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<UserRepository>.value(value: userRepo),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final avatarButton = find.byKey(const Key('profile_header_avatar_button'));
    expect(avatarButton, findsOneWidget);
    await tester.tap(avatarButton);
    await tester.pumpAndSettle();

    expect(find.byType(PublicProfileScreen), findsOneWidget);
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

class _FailingProfileRepository extends MockUserRepository {
  _FailingProfileRepository(this.error);

  final Object error;

  @override
  Future<UserModel> fetchProfile(String token) => Future.error(error);
}

class _FixedProfileRepository extends MockUserRepository {
  _FixedProfileRepository({required this.trustScore});

  final int trustScore;

  @override
  Future<UserModel> fetchProfile(String token) async => UserModel(
    id: 'user-1',
    displayName: 'Riley',
    trustScore: trustScore,
    isVerified: true,
  );
}
