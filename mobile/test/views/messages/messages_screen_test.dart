import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';
import 'package:kiwishare/views/messages/messages_screen.dart';

import '../../support/fake_chat_repository.dart';

Widget _buildSubject({
  required FakeChatRepository repository,
  ChatProvider? chatProvider,
  String? authToken = 'valid-token',
  VoidCallback? onComposePressed,
  ValueChanged<ChatConversationModel>? onConversationPressed,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFBFAF6),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF006B4F),
        surface: const Color(0xFFFBFAF6),
      ),
    ),
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: MessagesScreen(
        authToken: authToken,
        chatProvider: chatProvider ?? ChatProvider(repository: repository),
        onComposePressed: onComposePressed,
        onConversationPressed: onConversationPressed,
      ),
    ),
  );
}

List<ChatConversationModel> _conversations() => [
  testConversation(unreadCount: 2),
  testConversation(
    id: 'conversation-2',
    participantName: 'Maya L.',
    itemTitle: 'Solid Wood Desk',
    direction: ChatDirection.selling,
    lastMessage: 'Thanks! See you then.',
  ),
  testConversation(
    id: 'conversation-3',
    participantName: 'James K.',
    itemTitle: 'Giant Escape Bike',
    direction: ChatDirection.buying,
    lastMessage: 'I can pick it up tomorrow.',
  ),
];

void main() {
  testWidgets('loads real conversation previews and unread state', (
    tester,
  ) async {
    final repository = FakeChatRepository(conversations: _conversations());
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_title')), findsOneWidget);
    expect(repository.conversationFetches, 1);
    expect(
      find.byKey(const Key('chat_conversation_conversation-1')),
      findsOneWidget,
    );
    expect(find.text('Ergonomic Office Chair'), findsOneWidget);
    expect(find.text('Is this still available?'), findsOneWidget);
    expect(find.byKey(const Key('chat_unread_badge')), findsOneWidget);
  });

  testWidgets('filters server conversations by unread, buying, and selling', (
    tester,
  ) async {
    final repository = FakeChatRepository(conversations: _conversations());
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_filter_unread')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('chat_conversation_conversation-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('chat_conversation_conversation-2')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('chat_filter_selling')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('chat_conversation_conversation-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('chat_conversation_conversation-1')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('chat_filter_buying')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('chat_conversation_conversation-3')),
      findsOneWidget,
    );
  });

  testWidgets('exposes compose and conversation callbacks', (tester) async {
    final repository = FakeChatRepository(conversations: _conversations());
    var composePressed = false;
    ChatConversationModel? selectedChat;

    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        onComposePressed: () => composePressed = true,
        onConversationPressed: (chat) => selectedChat = chat,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_compose_button')));
    await tester.tap(find.byKey(const Key('chat_conversation_conversation-1')));

    expect(composePressed, isTrue);
    expect(selectedChat?.participantName, 'Sophie M.');
  });

  testWidgets('opening a conversation does not mark unseen history as read', (
    tester,
  ) async {
    final repository = FakeChatRepository(conversations: _conversations());
    final provider = ChatProvider(repository: repository);

    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        chatProvider: provider,
        onConversationPressed: (_) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat_unread_badge')), findsOneWidget);
    final initialUnreadCount = provider.totalUnreadCount;

    await tester.tap(find.byKey(const Key('chat_conversation_conversation-1')));
    await tester.pump();

    expect(find.byKey(const Key('chat_unread_badge')), findsOneWidget);
    expect(provider.totalUnreadCount, initialUnreadCount);
    expect(repository.markReadCalls, 0);
  });

  testWidgets('shows private signed-out and authenticated empty states', (
    tester,
  ) async {
    final signedOutRepository = FakeChatRepository();
    await tester.pumpWidget(
      _buildSubject(repository: signedOutRepository, authToken: null),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_signed_out_state')), findsOneWidget);
    expect(signedOutRepository.conversationFetches, 0);

    final emptyRepository = FakeChatRepository();
    await tester.pumpWidget(_buildSubject(repository: emptyRepository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat_empty_state')), findsOneWidget);
    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('explains a load failure and allows retry', (tester) async {
    final repository = FakeChatRepository()
      ..conversationError = const ChatRepositoryException(
        'Chat service unavailable.',
      );
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_error_state')), findsOneWidget);
    expect(find.text('Chat service unavailable.'), findsOneWidget);

    repository
      ..conversationError = null
      ..conversations = _conversations();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.conversationFetches, 2);
    expect(
      find.byKey(const Key('chat_conversation_conversation-1')),
      findsOneWidget,
    );
  });

  testWidgets('does not expose cached chats while accounts are switching', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      conversations: [testConversation(participantName: 'Account A seller')],
    );
    final provider = ChatProvider(repository: repository);

    Widget subject(String token) => MaterialApp(
      home: MessagesScreen(
        authToken: token,
        chatProvider: provider,
        onConversationPressed: (_) {},
      ),
    );

    await tester.pumpWidget(subject('account-a-token'));
    await tester.pumpAndSettle();
    expect(find.text('Account A seller'), findsOneWidget);

    repository.conversations = [
      testConversation(
        id: 'conversation-b',
        participantName: 'Account B seller',
      ),
    ];
    await tester.pumpWidget(subject('account-b-token'));
    await tester.pump();

    expect(find.text('Account A seller'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Account B seller'), findsOneWidget);
  });

  testWidgets('fits a narrow viewport at 200 percent text scaling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSubject(
        repository: FakeChatRepository(conversations: _conversations()),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat_list')), findsOneWidget);
  });
}
