import 'dart:async';

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
import 'views/profile/user_meetups_screen.dart';
import 'views/profile/user_orders_screen.dart';
import 'views/meetups/meetup_qr_screen.dart';
import 'views/auth/login_view.dart';
import 'views/products/product_detail_screen.dart';
import 'models/item_model.dart';
import 'navigation/app_route_observer.dart';

// State and Repositories
import 'providers/providers.dart';
import 'repositories/user_repository.dart';
import 'repositories/item_repository.dart';
import 'repositories/watchlist_repository.dart';
import 'repositories/notification_preferences_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/meetup_repository.dart';
import 'repositories/order_repository.dart';
import 'repositories/push_device_repository.dart';
import 'repositories/report_repository.dart';
import 'services/remote_config_service.dart';
import 'services/firebase_runtime_configuration.dart';
import 'services/push_notification_service.dart';
import 'services/notification_permission_coordinator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'widgets/top_notification_banner.dart';

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
  observers: [appRouteObserver],
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
        return ChatConversationScreen(
          conversation: conversation,
          enablePolling: true,
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/meetups',
      builder: (context, state) => const UserMeetupsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/orders',
      builder: (context, state) => const UserOrdersScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/meetups/:orderId/qr',
      builder: (context, state) {
        final orderId = state.pathParameters['orderId'] ?? '';
        return MeetupQrScreen(orderId: orderId);
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
      onForegroundChatRead: _handleForegroundChatRead,
      onNavigateToMeetupQrCode: _openMeetupQrNotification,
      onForegroundMeetupMessage: _showForegroundMeetupNotification,
    );
    unawaited(pushNotifications.initialize());
  }

  final notificationCoordinator = NotificationPermissionCoordinator(
    permissionController: pushNotifications,
  );

  final userRepository = RestUserRepository();

  runApp(
    MultiProvider(
      providers: [
        Provider<UserRepository>.value(value: userRepository),
        Provider<NotificationPermissionCoordinator>.value(
          value: notificationCoordinator,
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            userRepository: userRepository,
            pushNotifications: pushNotifications,
          ),
        ),
        Provider<ItemRepository>(create: (_) => RestItemRepository()),
        Provider<ReportRepository>(create: (_) => RestReportRepository()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProxyProvider<AuthProvider, WatchlistProvider>(
          create: (_) => WatchlistProvider(
            repository: RestWatchlistRepository(),
            preferencesRepository: RestNotificationPreferencesRepository(),
          ),
          update: (_, auth, watchlist) => syncWatchlistAuth(
            watchlist ??
                WatchlistProvider(
                  repository: RestWatchlistRepository(),
                  preferencesRepository:
                      RestNotificationPreferencesRepository(),
                ),
            auth.jwtToken,
          ),
        ),
        ChangeNotifierProvider(create: (_) => HomeDiscoveryProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => ListingProvider(itemRepository: RestItemRepository()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(
            repository: RestChatRepository(),
            enablePolling: true,
          ),
          update: (_, auth, chat) => syncChatAuth(
            chat ??
                ChatProvider(
                  repository: RestChatRepository(),
                  enablePolling: true,
                ),
            auth.jwtToken,
            onIncomingChatMessage: (conversation) {
              final token = auth.jwtToken ?? '';
              if (chatVisibilityTracker.isVisible(
                conversationId: conversation.id,
                sessionToken: token,
              )) {
                return;
              }
              _showInAppChatNotification(conversation);
            },
          ),
        ),
        Provider<MeetupRepository>(create: (_) => RestMeetupRepository()),
        ChangeNotifierProxyProvider<AuthProvider, MeetupProvider>(
          create: (_) => MeetupProvider(repository: RestMeetupRepository()),
          update: (_, auth, meetup) => syncMeetupAuth(
            meetup ?? MeetupProvider(repository: RestMeetupRepository()),
            auth.jwtToken,
          ),
        ),
        Provider<OrderRepository>(create: (_) => RestOrderRepository()),
        ChangeNotifierProxyProvider<AuthProvider, OrderProvider>(
          create: (_) => OrderProvider(repository: RestOrderRepository()),
          update: (_, auth, order) => syncOrderAuth(
            order ?? OrderProvider(repository: RestOrderRepository()),
            auth.jwtToken,
          ),
        ),
      ],
      child: const KiwiShareApp(),
    ),
  );
}

@visibleForTesting
MeetupProvider syncMeetupAuth(MeetupProvider meetup, String? authToken) {
  meetup.updateAuthToken(authToken);
  return meetup;
}

@visibleForTesting
OrderProvider syncOrderAuth(OrderProvider order, String? authToken) {
  order.updateAuthToken(authToken);
  return order;
}

@visibleForTesting
ChatProvider syncChatAuth(
  ChatProvider chat,
  String? authToken, {
  void Function(ChatConversationModel conversation)? onIncomingChatMessage,
}) {
  if (onIncomingChatMessage != null) {
    chat.onIncomingChatMessage = onIncomingChatMessage;
  }
  chat.updateAuthToken(authToken);
  return chat;
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

void _openMeetupQrNotification(MeetupPushMessage message) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigateToNotificationRoute(_router, '/meetups/${message.orderId}/qr');
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

void _showInAppChatNotification(ChatConversationModel conversation) {
  showTopNotification(
    context: _rootNavigatorKey.currentContext,
    navigatorKey: _rootNavigatorKey,
    fallbackMessenger: _scaffoldMessengerKey.currentState,
    title: conversation.participantName.isNotEmpty
        ? conversation.participantName
        : 'New message',
    body: conversation.lastMessage.isNotEmpty
        ? conversation.lastMessage
        : 'Sent you a message about ${conversation.itemTitle}',
    icon: Icons.chat_bubble_rounded,
    actionLabel: 'Reply',
    onTap: () {
      navigateToNotificationRoute(
        _router,
        '/messages/${conversation.id}',
        extra: conversation,
      );
    },
    onAction: () {
      navigateToNotificationRoute(
        _router,
        '/messages/${conversation.id}',
        extra: conversation,
      );
    },
  );
}

void _showForegroundChatNotification(
  ChatPushMessage message,
  PushEnvelope envelope,
) {
  final appContext = _scaffoldMessengerKey.currentContext;
  final auth = appContext?.read<AuthProvider>();
  final chat = appContext?.read<ChatProvider>();
  if (auth != null && chat != null) {
    unawaited(
      refreshChatUnreadForMessage(
        message: message,
        activeUserId: auth.currentUser?.id,
        authToken: auth.jwtToken,
        chatProvider: chat,
        activeConversationIdProvider: () => activeChatConversationId(_router),
        isConversationVisibleProvider: () => chatVisibilityTracker.isVisible(
          conversationId: message.conversationId,
          sessionToken: auth.jwtToken ?? '',
        ),
      ),
    );
  }
  showTopNotification(
    context: _rootNavigatorKey.currentContext,
    navigatorKey: _rootNavigatorKey,
    fallbackMessenger: _scaffoldMessengerKey.currentState,
    title: message.participantName.isNotEmpty
        ? message.participantName
        : 'New message',
    body:
        envelope.body ??
        (message.itemTitle.isNotEmpty
            ? 'Sent you a message about ${message.itemTitle}'
            : 'You have a new KiwiShare message.'),
    icon: Icons.chat_bubble_rounded,
    actionLabel: 'Reply',
    onTap: () {
      final activeUserId = _scaffoldMessengerKey.currentContext
          ?.read<AuthProvider>()
          .currentUser
          ?.id;
      if (shouldOpenChatNotificationForUser(message, activeUserId)) {
        _openChatNotification(message);
      }
    },
    onAction: () {
      final activeUserId = _scaffoldMessengerKey.currentContext
          ?.read<AuthProvider>()
          .currentUser
          ?.id;
      if (shouldOpenChatNotificationForUser(message, activeUserId)) {
        _openChatNotification(message);
      }
    },
  );
}

void _handleForegroundChatRead(ChatReadPushMessage message) {
  final appContext = _scaffoldMessengerKey.currentContext;
  final auth = appContext?.read<AuthProvider>();
  final chat = appContext?.read<ChatProvider>();
  if (auth == null || chat == null) return;
  unawaited(
    refreshChatReadReceipt(
      message: message,
      activeUserId: auth.currentUser?.id,
      authToken: auth.jwtToken,
      chatProvider: chat,
      activeConversationIdProvider: () => activeChatConversationId(_router),
      isConversationVisibleProvider: () => chatVisibilityTracker.isVisible(
        conversationId: message.conversationId,
        sessionToken: auth.jwtToken ?? '',
      ),
    ),
  );
}

void _showForegroundMeetupNotification(
  MeetupPushMessage message,
  PushEnvelope envelope,
) {
  showTopNotification(
    context: _rootNavigatorKey.currentContext,
    navigatorKey: _rootNavigatorKey,
    fallbackMessenger: _scaffoldMessengerKey.currentState,
    title: 'Meetup confirmed!',
    body: envelope.body ?? 'Meetup confirmed! View your QR code.',
    icon: Icons.qr_code_2_rounded,
    actionLabel: 'View QR',
    onTap: () => _openMeetupQrNotification(message),
    onAction: () => _openMeetupQrNotification(message),
  );
}

@visibleForTesting
Future<void> refreshChatUnreadForMessage({
  required ChatPushMessage message,
  required String? activeUserId,
  required String? authToken,
  required ChatProvider chatProvider,
  String? Function()? activeConversationIdProvider,
  bool Function()? isConversationVisibleProvider,
}) async {
  if (!shouldOpenChatNotificationForUser(message, activeUserId) ||
      authToken == null ||
      authToken.isEmpty) {
    return;
  }
  await chatProvider.loadConversations(authToken, queueIfBusy: true);
  if (activeConversationIdProvider?.call() != message.conversationId ||
      !(isConversationVisibleProvider?.call() ?? true)) {
    return;
  }
  final conversation = chatProvider.messageConversationByIdForSession(
    message.conversationId,
    authToken,
  );
  if (conversation == null) return;
  await chatProvider.loadMessages(
    conversation: conversation,
    token: authToken,
    queueIfBusy: true,
    shouldMarkRead: () =>
        activeConversationIdProvider?.call() == message.conversationId &&
        (isConversationVisibleProvider?.call() ?? true),
  );
}

@visibleForTesting
String? activeChatConversationId(GoRouter router) {
  final segments = router.routerDelegate.currentConfiguration.uri.pathSegments;
  if (segments.length != 2 || segments.first != 'messages') return null;
  final conversationId = segments.last.trim();
  return conversationId.isEmpty ? null : conversationId;
}

@visibleForTesting
Future<void> refreshChatReadReceipt({
  required ChatReadPushMessage message,
  required String? activeUserId,
  required String? authToken,
  required ChatProvider chatProvider,
  required String? Function() activeConversationIdProvider,
  bool Function()? isConversationVisibleProvider,
}) async {
  if (!message.isForRecipient(activeUserId) ||
      authToken == null ||
      authToken.isEmpty ||
      activeConversationIdProvider() != message.conversationId ||
      !(isConversationVisibleProvider?.call() ?? true)) {
    return;
  }
  final conversation = chatProvider.messageConversationByIdForSession(
    message.conversationId,
    authToken,
  );
  if (conversation == null) return;
  await chatProvider.loadMessages(
    conversation: conversation,
    token: authToken,
    queueIfBusy: true,
    shouldMarkRead: () =>
        activeConversationIdProvider() == message.conversationId &&
        (isConversationVisibleProvider?.call() ?? true),
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
  showTopNotification(
    context: _rootNavigatorKey.currentContext,
    navigatorKey: _rootNavigatorKey,
    fallbackMessenger: _scaffoldMessengerKey.currentState,
    title: envelope.title ?? 'Price drop on a saved item',
    body: envelope.body ?? message.notificationSummary,
    icon: Icons.trending_down_rounded,
    actionLabel: 'View',
    onTap: () => _openWatchlistPriceDrop(message.itemId),
    onAction: () => _openWatchlistPriceDrop(message.itemId),
  );
}

class KiwiShareApp extends StatefulWidget {
  const KiwiShareApp({super.key});

  @override
  State<KiwiShareApp> createState() => _KiwiShareAppState();
}

class _KiwiShareAppState extends State<KiwiShareApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        final chat = _scaffoldMessengerKey.currentContext
            ?.read<ChatProvider?>();
        chat?.resumePolling();
      },
      onPause: () {
        final chat = _scaffoldMessengerKey.currentContext
            ?.read<ChatProvider?>();
        chat?.pausePolling();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

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
    final unreadChatCount = context.select<ChatProvider?, int>(
      (provider) => provider?.totalUnreadCount ?? 0,
    );
    final colors = Theme.of(context).colorScheme;
    final navTheme = Theme.of(context).bottomNavigationBarTheme;

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
          backgroundColor: navTheme.backgroundColor ?? colors.surface,
          selectedItemColor: navTheme.selectedItemColor ?? colors.primary,
          unselectedItemColor:
              navTheme.unselectedItemColor ??
              colors.onSurface.withValues(alpha: 0.78),
          selectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            height: 1.2,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            height: 1.2,
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
                child: Icon(Icons.favorite_border, size: 23),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 2.0),
                child: Icon(Icons.favorite, size: 25, color: Color(0xFFEF4444)),
              ),
              label: 'Watchlist',
            ),
            BottomNavigationBarItem(
              icon: Container(
                margin: const EdgeInsets.only(bottom: 2.0),
                width: 38,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              activeIcon: Container(
                margin: const EdgeInsets.only(bottom: 2.0),
                width: 38,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF047857),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF047857).withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              label: 'Sell',
            ),
            BottomNavigationBarItem(
              icon: ChatNavigationIcon(
                unreadCount: unreadChatCount,
                active: false,
              ),
              activeIcon: ChatNavigationIcon(
                unreadCount: unreadChatCount,
                active: true,
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

@visibleForTesting
class ChatNavigationIcon extends StatelessWidget {
  const ChatNavigationIcon({
    super.key,
    required this.unreadCount,
    required this.active,
  });

  final int unreadCount;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final normalizedCount = unreadCount < 0 ? 0 : unreadCount;
    final badgeLabel = normalizedCount > 99 ? '99+' : '$normalizedCount';
    return Semantics(
      label: normalizedCount == 0
          ? 'Chat'
          : 'Chat, $normalizedCount unread messages',
      child: ExcludeSemantics(
        child: Badge(
          key: Key(
            active ? 'chat_navigation_badge_active' : 'chat_navigation_badge',
          ),
          isLabelVisible: normalizedCount > 0,
          label: Text(badgeLabel),
          backgroundColor: const Color(0xFFC96B4A),
          textColor: Colors.white,
          offset: const Offset(8, -5),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Icon(
              active ? Icons.chat_bubble : Icons.chat_bubble_outline,
              size: active ? 24 : 22,
            ),
          ),
        ),
      ),
    );
  }
}
