import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// View Imports
import 'views/splash/splash_screen.dart';
import 'views/home/home_screen.dart';
import 'views/search/search_screen.dart';
import 'views/post/post_item_screen.dart';
import 'views/messages/messages_screen.dart';
import 'views/profile/profile_screen.dart';
import 'views/auth/login_view.dart';
import 'views/products/product_detail_screen.dart';
import 'models/item_model.dart';

// State and Repositories
import 'providers/providers.dart';
import 'repositories/user_repository.dart';
import 'repositories/item_repository.dart';
import 'services/remote_config_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

// Global keys for routing
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (DefaultFirebaseOptions.isConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await RemoteConfigService.instance.initialize();
    } catch (e) {
      debugPrint('Firebase/RemoteConfig initialization failed: $e');
    }
  } else {
    debugPrint(
      'ℹ️ [Firebase] Placeholder credentials detected. Skipping Firebase init and using in-app local defaults.',
    );
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(userRepository: RestUserRepository()),
          //@@@For mock test: uncomment below code to login with mock user
          // create: (_) => AuthProvider(userRepository: MockUserRepository()),
        ),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => ListingProvider(itemRepository: RestItemRepository()),
        ),
      ],
      child: const KiwiShareApp(),
    ),
  );
}

class KiwiShareApp extends StatelessWidget {
  const KiwiShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Declarative GoRouter setup
    final GoRouter router = GoRouter(
      initialLocation: '/splash',
      navigatorKey: _rootNavigatorKey,
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => SplashScreen(
            onSplashComplete: () {
              context.go('/home');
            },
          ),
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            return KiwiShareShell(child: child);
          },
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => HomeScreen(
                onNavigateToSearch: () {
                  context.go('/search');
                },
              ),
            ),
            GoRoute(
              path: '/search',
              builder: (context, state) => SearchScreen(
                requestNearby: state.uri.queryParameters['nearby'] == 'true',
                openMap: state.uri.queryParameters['map'] == 'true',
              ),
            ),
            GoRoute(
              path: '/post',
              builder: (context, state) => PostItemScreen(
                onCancel: () {
                  context.go('/home');
                },
              ),
            ),
            GoRoute(
              path: '/messages',
              builder: (context, state) => const MessagesScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/items/:itemId',
          builder: (context, state) => ProductDetailScreen(
            item: state.extra is ItemModel ? state.extra as ItemModel : null,
          ),
        ),
      ],
    );

    final themeMode = context.watch<ThemeProvider>().themeMode;
    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4E8878),
      brightness: Brightness.dark,
    );

    return MaterialApp.router(
      title: 'KiwiShare - Buy. Sell. Share. Sustain.',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildKiwiShareTheme(),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkScheme.surface,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      routerConfig: router,
    );
  }
}

class KiwiShareShell extends StatelessWidget {
  final Widget child;

  const KiwiShareShell({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/post')) return 2;
    if (location.startsWith('/messages')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _showLoginBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F2), // Off-White surface
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LoginView(
                  onLoginSuccess: () {
                    Navigator.pop(context);
                    // Route to post screen after successful authentication
                    context.go('/post');
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/post')) {
      return child;
    }

    final activeIndex = _getSelectedIndex(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F1F1F).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: activeIndex,
          onTap: (index) {
            if (index == 2 && !authProvider.isLoggedIn) {
              // Intercept Post click if not logged in
              _showLoginBottomSheet(context);
              return;
            }

            // GoRouter navigation mapping
            switch (index) {
              case 0:
                context.go('/home');
                break;
              case 1:
                context.go('/search');
                break;
              case 2:
                context.go('/post');
                break;
              case 3:
                context.go('/messages');
                break;
              case 4:
                context.go('/profile');
                break;
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFFAF7F2), // Off-White Surface
          selectedItemColor: const Color(0xFF2E5E4E), // Sage Green Active
          unselectedItemColor: const Color(
            0xFF1F1F1F,
          ).withOpacity(0.5), // Charcoal Inactive
          selectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          items: [
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.home_outlined, size: 24),
              ),
              activeIcon: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.home, size: 26),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.search, size: 24),
              ),
              activeIcon: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.search, size: 26),
              ),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Container(
                margin: const EdgeInsets.only(top: 4.0),
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E5E4E), // Sage Green
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.chat_bubble_outline, size: 22),
              ),
              activeIcon: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.chat_bubble, size: 24),
              ),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.person_outline, size: 24),
              ),
              activeIcon: const Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.person, size: 26),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
