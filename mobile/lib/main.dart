import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

// View Imports
import 'views/splash/splash_screen.dart';
import 'views/home/home_screen.dart';
import 'views/search/search_screen.dart';
import 'views/watchlist/watchlist_screen.dart';
import 'views/post/post_item_screen.dart';
import 'views/messages/messages_screen.dart';
import 'views/messages/chat_conversation_screen.dart';
import 'views/profile/profile_screen.dart';
import 'views/auth/login_view.dart';
import 'views/products/product_detail_screen.dart';
import 'models/item_model.dart';

// State and Repositories
import 'providers/providers.dart';
import 'repositories/user_repository.dart';
import 'repositories/item_repository.dart';
import 'repositories/watchlist_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/push_device_repository.dart';
import 'services/remote_config_service.dart';
import 'services/firebase_runtime_configuration.dart';
import 'services/push_notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'widgets/kiwishare_notification_content.dart';

// Global keys for routing
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);
final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// This router must live longer than a single widget build. ThemeProvider
// notifies MaterialApp when the user selects Light/Dark/System; recreating a
// GoRouter in build() made it start again at /splash every time.
final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  navigatorKey: _rootNavigatorKey,
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) =>
          SplashScreen(onSplashComplete: () => context.go('/home')),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => KiwiShareShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/watchlist',
          builder: (context, state) => const WatchlistScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/post',
          builder: (context, state) => PostItemScreen(
            onCancel: () => context.go('/home'),
            onPostItem: () => context.go('/home'),
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
        itemId: state.pathParameters['itemId'],
        item: state.extra is ItemModel ? state.extra as ItemModel : null,
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/messages/:conversationId',
      builder: (context, state) {
        final conversationId = state.pathParameters['conversationId'] ?? '';
        final authToken = context.read<AuthProvider>().jwtToken;
        final cachedConversation = context
            .read<ChatProvider>()
            .conversationByIdForSession(conversationId, authToken);
        final conversation =
            cachedConversation ??
            (state.extra is ChatConversationModel
                ? state.extra as ChatConversationModel
                : ChatConversationModel(
                    id: conversationId,
                    itemId: '',
                    itemTitle: 'Item conversation',
                    itemImageUrl: '',
                    participantId: '',
                    participantName: 'Kiwi member',
                    direction: ChatDirection.buying,
                    status: 'active',
                    lastMessage: '',
                    unreadCount: 0,
                  ));
        return ChatConversationScreen(conversation: conversation);
      },
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseInitialized = false;
  FirebaseOptions? firebaseOptions;
  try {
    final candidate = DefaultFirebaseOptions.currentPlatform;
    if (hasUsableFirebaseOptions(candidate)) firebaseOptions = candidate;
  } catch (error) {
    debugPrint('[Firebase] Configuration lookup failed: $error');
  }
  if (firebaseOptions != null) {
    try {
      await Firebase.initializeApp(options: firebaseOptions);
      firebaseInitialized = true;
      await RemoteConfigService.instance.initialize();
    } catch (e) {
      debugPrint('Firebase/RemoteConfig initialization failed: $e');
    }
  } else {
    debugPrint(
      'ℹ️ [Firebase] FlutterFire configuration is absent. Firebase and push notifications are disabled; the app will continue with local defaults.',
    );
  }

  PushNotificationService? pushNotifications;
  if (firebaseInitialized &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    pushNotifications = PushNotificationService(
      messagingClient: FirebasePushMessagingClient(),
      deviceRepository: RestPushDeviceRepository(),
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      onNavigateToItem: _openWatchlistPriceDrop,
      onForegroundMessage: _showForegroundPriceDrop,
      onNavigateToChat: _openChatNotification,
      onForegroundChatMessage: _showForegroundChatNotification,
    );
    await pushNotifications.initialize();
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            userRepository: RestUserRepository(),
            pushNotifications: pushNotifications,
          ),
        ),
        Provider<ItemRepository>(create: (_) => RestItemRepository()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProxyProvider<AuthProvider, WatchlistProvider>(
          create: (_) =>
              WatchlistProvider(repository: RestWatchlistRepository()),
          update: (_, auth, watchlist) => syncWatchlistAuth(
            watchlist ??
                WatchlistProvider(repository: RestWatchlistRepository()),
            auth.jwtToken,
          ),
        ),
        ChangeNotifierProvider(create: (_) => HomeDiscoveryProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => ListingProvider(itemRepository: RestItemRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(repository: RestChatRepository()),
        ),
      ],
      child: const KiwiShareApp(),
    ),
  );
}

@visibleForTesting
WatchlistProvider syncWatchlistAuth(
  WatchlistProvider watchlist,
  String? authToken,
) {
  watchlist.updateAuthToken(authToken);
  return watchlist;
}

void _openWatchlistPriceDrop(String itemId) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigateToNotificationRoute(_router, '/items/$itemId');
  });
}

void _openChatNotification(ChatPushMessage message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigateToNotificationRoute(
      _router,
      '/messages/${message.conversationId}',
      extra: ChatConversationModel(
        id: message.conversationId,
        itemId: message.itemId,
        itemTitle: message.itemTitle,
        itemImageUrl: '',
        participantId: message.participantId,
        participantName: message.participantName,
        direction: ChatDirection.buying,
        status: 'active',
        lastMessage: '',
        unreadCount: 0,
      ),
    );
  });
}

void navigateToNotificationRoute(
  GoRouter router,
  String location, {
  Object? extra,
}) {
  final currentPath = router.routerDelegate.currentConfiguration.uri.path;
  if (currentPath == '/splash') {
    // A cold-start notification owns initial navigation. Replacing Splash
    // disposes its delayed Home timer instead of leaving it under this route.
    router.go(location, extra: extra);
    return;
  }
  router.push(location, extra: extra);
}

void _showForegroundChatNotification(
  ChatPushMessage message,
  PushEnvelope envelope,
) {
  final messenger = _scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(envelope.body ?? 'You have a new KiwiShare message.'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            final activeUserId = _scaffoldMessengerKey.currentContext
                ?.read<AuthProvider>()
                .currentUser
                ?.id;
            if (shouldOpenChatNotificationForUser(message, activeUserId)) {
              _openChatNotification(message);
            }
          },
        ),
      ),
    );
}

bool shouldOpenChatNotificationForUser(
  ChatPushMessage message,
  String? activeUserId,
) => message.isForRecipient(activeUserId);

void _showForegroundPriceDrop(
  WatchlistPriceDropMessage message,
  PushEnvelope envelope,
) {
  final messenger = _scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: KiwiShareNotificationContent(
          title: envelope.title ?? 'Price drop on a saved item',
          body: envelope.body ?? message.notificationSummary,
          icon: Icons.trending_down_rounded,
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _openWatchlistPriceDrop(message.itemId),
        ),
      ),
    );
}

class KiwiShareApp extends StatelessWidget {
  const KiwiShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp.router(
      title: 'KiwiShare - Buy. Sell. Share. Sustain.',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      themeMode: themeMode,
      theme: buildKiwiShareTheme(),
      darkTheme: buildKiwiShareDarkTheme(),
      routerConfig: _router,
    );
  }
}

class KiwiShareShell extends StatelessWidget {
  final Widget child;

  const KiwiShareShell({super.key, required this.child});

  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/watchlist') || location.startsWith('/search')) {
      return 1;
    }
    if (location.startsWith('/post')) return 2;
    if (location.startsWith('/messages')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _showLoginBottomSheet(BuildContext shellContext) {
    showModalBottomSheet(
      context: shellContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LoginView(
                  onLoginSuccess: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (shellContext.mounted) shellContext.go('/post');
                    });
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
    final homeDiscovery = context.watch<HomeDiscoveryProvider>();

    final shell = Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
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
                context.go('/watchlist');
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(
            context,
          ).colorScheme.onSurface.withOpacity(0.5),
          selectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.home_outlined, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.home, size: 26),
              ),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.bookmark_outline, size: 24),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.bookmark, size: 26),
              ),
              label: 'Watchlist',
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
              label: 'Chat',
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

    final shouldDismissHomePreview =
        location.startsWith('/home') && homeDiscovery.previewItemId != null;
    return PopScope<void>(
      canPop: !shouldDismissHomePreview,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && shouldDismissHomePreview) {
          homeDiscovery.selectPreview(null);
        }
      },
      child: shell,
    );
  }
}
