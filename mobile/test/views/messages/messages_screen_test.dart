import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/views/messages/messages_screen.dart';

Widget _buildSubject({
  VoidCallback? onComposePressed,
  ValueChanged<ChatPreview>? onConversationPressed,
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
    home: MessagesScreen(
      onComposePressed: onComposePressed,
      onConversationPressed: onConversationPressed,
    ),
  );
}

void main() {
  testWidgets('renders the Figma chat list content', (tester) async {
    await tester.pumpWidget(_buildSubject());

    expect(find.byKey(const Key('chat_title')), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);
    expect(find.text('Buying'), findsOneWidget);
    expect(find.text('Selling'), findsOneWidget);
    expect(
      find.byKey(const Key('chat_conversation_Sophie M.')),
      findsOneWidget,
    );
    expect(find.text('Ergonomic Office Chair'), findsOneWidget);
    expect(find.byKey(const Key('chat_unread_badge')), findsOneWidget);
  });

  testWidgets('filters the chat list by unread conversations', (tester) async {
    await tester.pumpWidget(_buildSubject());

    await tester.tap(find.byKey(const Key('chat_filter_unread')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('chat_conversation_Sophie M.')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat_conversation_James K.')), findsNothing);
    expect(find.byKey(const Key('chat_unread_badge')), findsOneWidget);
  });

  testWidgets('filters the chat list by buying and selling', (tester) async {
    await tester.pumpWidget(_buildSubject());

    await tester.tap(find.byKey(const Key('chat_filter_selling')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_conversation_Maya L.')), findsOneWidget);
    expect(find.byKey(const Key('chat_conversation_Liam R.')), findsOneWidget);
    expect(find.byKey(const Key('chat_conversation_Noah W.')), findsOneWidget);
    expect(find.byKey(const Key('chat_conversation_Sophie M.')), findsNothing);

    await tester.tap(find.byKey(const Key('chat_filter_buying')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('chat_conversation_Sophie M.')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat_conversation_Maya L.')), findsNothing);
  });

  testWidgets('exposes compose and conversation callbacks', (tester) async {
    var composePressed = false;
    ChatPreview? selectedChat;

    await tester.pumpWidget(
      _buildSubject(
        onComposePressed: () => composePressed = true,
        onConversationPressed: (chat) => selectedChat = chat,
      ),
    );

    await tester.tap(find.byKey(const Key('chat_compose_button')));
    await tester.tap(find.byKey(const Key('chat_conversation_Sophie M.')));

    expect(composePressed, isTrue);
    expect(selectedChat?.name, 'Sophie M.');
  });

  testWidgets('fits a narrow Android viewport without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildSubject());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('chat_list')), findsOneWidget);
  });
}
