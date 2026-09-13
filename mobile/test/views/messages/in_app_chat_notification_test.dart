import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/providers/home_discovery_provider.dart';
import 'package:kiwishare/providers/navigation_provider.dart';
import 'package:kiwishare/providers/theme_provider.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/widgets/kiwishare_notification_content.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_chat_repository.dart';

void main() {
  group('In-App Chat Notification and Badge Synchronization', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'test-token',
        'current_user': jsonEncode({
          'id': 'user-1',
          'displayName': 'Test User',
          'trustScore': 100,
          'isVerified': true,
        }),
      });
    });

    testWidgets(
      'bottom navigation chat tab updates badge and shows floating notification',
      (tester) async {
        final chatRepo = FakeChatRepository(
          conversations: [
            testConversation(
              id: 'conv-1',
              unreadCount: 0,
              lastMessage: 'Hi',
              participantName: 'Alice',
            ),
          ],
        );
        final chatProvider = ChatProvider(
          repository: chatRepo,
          enablePolling: false,
        );
        final authProvider = AuthProvider(userRepository: MockUserRepository());
        final themeProvider = ThemeProvider();
        final navProvider = NavigationProvider();
        final homeDiscovery = HomeDiscoveryProvider();
        final watchlistProvider = WatchlistProvider(
          repository: RestWatchlistRepository(),
        );

        final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

        void showInAppNotification(ChatConversationModel conversation) {
          final messenger = scaffoldMessengerKey.currentState;
          if (messenger == null) return;
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: KiwiShareNotificationContent(
                  title: conversation.participantName,
                  body: conversation.lastMessage,
                  icon: Icons.chat_bubble_rounded,
                ),
                action: SnackBarAction(
                  label: 'Reply',
                  onPressed: () {},
                ),
              ),
            );
        }

        chatProvider.onIncomingChatMessage = (conversation) {
          showInAppNotification(conversation);
        };

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: authProvider),
              ChangeNotifierProvider.value(value: chatProvider),
              ChangeNotifierProvider.value(value: themeProvider),
              ChangeNotifierProvider.value(value: navProvider),
              ChangeNotifierProvider.value(value: homeDiscovery),
              ChangeNotifierProvider.value(value: watchlistProvider),
            ],
            child: MaterialApp(
              scaffoldMessengerKey: scaffoldMessengerKey,
              theme: buildKiwiShareTheme(),
              home: Scaffold(
                body: const Center(child: Text('Home Screen')),
                bottomNavigationBar: Consumer<ChatProvider>(
                  builder: (context, chat, _) {
                    final unreadCount = chat.totalUnreadCount;
                    return BottomNavigationBar(
                      currentIndex: 0,
                      items: [
                        const BottomNavigationBarItem(
                          icon: Icon(Icons.home),
                          label: 'Home',
                        ),
                        BottomNavigationBarItem(
                          icon: Badge(
                            key: const Key('chat_nav_badge'),
                            isLabelVisible: unreadCount > 0,
                            label: Text('$unreadCount'),
                            child: const Icon(Icons.chat_bubble_outline),
                          ),
                          label: 'Chat',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Load initial conversations
        await chatProvider.loadConversations('test-token');
        await tester.pump();

        // Initially 0 unread
        expect(chatProvider.totalUnreadCount, 0);
        final initialBadge = tester.widget<Badge>(
          find.byKey(const Key('chat_nav_badge')),
        );
        expect(initialBadge.isLabelVisible, isFalse);
        expect(find.byType(SnackBar), findsNothing);

        // Simulate incoming message
        chatRepo.conversations = [
          testConversation(
            id: 'conv-1',
            unreadCount: 1,
            lastMessage: 'Can you deliver this afternoon?',
            participantName: 'Alice',
          ),
        ];

        await chatProvider.loadConversations('test-token');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify badge updated to 1
        expect(chatProvider.totalUnreadCount, 1);
        final updatedBadge = tester.widget<Badge>(
          find.byKey(const Key('chat_nav_badge')),
        );
        expect(updatedBadge.isLabelVisible, isTrue);

        // Verify floating in-app notification banner appeared
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('Can you deliver this afternoon?'), findsOneWidget);
        expect(find.text('Reply'), findsOneWidget);

        // Simulate reading messages
        await chatProvider.markConversationRead(
          conversation: chatRepo.conversations.first,
          token: 'test-token',
          throughMessageId: 'msg-1',
        );
        await tester.pump();

        // Verify badge cleared
        expect(chatProvider.totalUnreadCount, 0);
        final clearedBadge = tester.widget<Badge>(
          find.byKey(const Key('chat_nav_badge')),
        );
        expect(clearedBadge.isLabelVisible, isFalse);
      },
    );
  });
}
