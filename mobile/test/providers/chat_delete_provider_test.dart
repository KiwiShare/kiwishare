import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';

import '../support/fake_chat_repository.dart';

void main() {
  test('removes a conversation after the API confirms deletion', () async {
    final conversation = testConversation();
    final repository = FakeChatRepository(conversations: [conversation]);
    final provider = ChatProvider(repository: repository);
    await provider.loadConversations('valid-token');
    expect(provider.conversationRenderVersionFor(conversation.id), 0);

    final removed = await provider.deleteConversation(
      conversation: conversation,
      token: 'valid-token',
    );

    expect(removed, isTrue);
    expect(provider.conversations, isEmpty);
    expect(repository.deletedConversationIds, [conversation.id]);
    expect(provider.isDeletingConversation(conversation.id), isFalse);
  });

  test('restores the conversation when deletion fails', () async {
    final conversation = testConversation();
    final repository = FakeChatRepository(conversations: [conversation])
      ..deleteError = const ChatRepositoryException(
        'Chat could not be removed from the server.',
      );
    final provider = ChatProvider(repository: repository);
    await provider.loadConversations('valid-token');

    final removed = await provider.deleteConversation(
      conversation: conversation,
      token: 'valid-token',
    );

    expect(removed, isFalse);
    expect(provider.conversations.single.id, conversation.id);
    expect(provider.conversationRenderVersionFor(conversation.id), 1);
    expect(
      provider.conversationDeleteErrorFor(conversation.id),
      'Chat could not be removed from the server.',
    );
  });
}
