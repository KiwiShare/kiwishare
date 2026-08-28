import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';
import 'package:kiwishare/views/messages/messages_screen.dart';

import '../../support/fake_chat_repository.dart';

Widget _buildSubject(FakeChatRepository repository) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B4F)),
    ),
    home: MessagesScreen(
      authToken: 'valid-token',
      chatProvider: ChatProvider(repository: repository),
      onConversationPressed: (_) {},
    ),
  );
}

void main() {
  testWidgets('left swipe requires confirmation before removing a chat', (
    tester,
  ) async {
    final conversation = testConversation();
    final repository = FakeChatRepository(conversations: [conversation]);
    await tester.pumpWidget(_buildSubject(repository));
    await tester.pumpAndSettle();

    final dismissible = find.byKey(
      Key('chat_dismissible_${conversation.id}_0'),
    );
    await tester.drag(dismissible, const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Remove chat?'), findsOneWidget);
    expect(
      find.textContaining('It will return if a new message arrives.'),
      findsOneWidget,
    );
    expect(repository.deleteCalls, 0);

    await tester.tap(find.byKey(const Key('chat_delete_cancel')));
    await tester.pumpAndSettle();
    expect(dismissible, findsOneWidget);

    await tester.drag(dismissible, const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repository.deletedConversationIds, [conversation.id]);
    expect(dismissible, findsNothing);
    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('an immediate deletion failure restores a fresh chat row', (
    tester,
  ) async {
    final conversation = testConversation();
    final repository = FakeChatRepository(conversations: [conversation])
      ..deleteError = const ChatRepositoryException(
        'Chat could not be removed from the server.',
      );
    await tester.pumpWidget(_buildSubject(repository));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(Key('chat_dismissible_${conversation.id}_0')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_delete_confirm')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(Key('chat_dismissible_${conversation.id}_1')),
      findsOneWidget,
    );
    expect(find.text(conversation.participantName), findsOneWidget);
    expect(
      find.text('Chat could not be removed from the server.'),
      findsOneWidget,
    );
  });

  testWidgets('right swipe does not offer deletion', (tester) async {
    final conversation = testConversation();
    final repository = FakeChatRepository(conversations: [conversation]);
    await tester.pumpWidget(_buildSubject(repository));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(Key('chat_dismissible_${conversation.id}_0')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remove chat?'), findsNothing);
    expect(repository.deleteCalls, 0);
  });
}
