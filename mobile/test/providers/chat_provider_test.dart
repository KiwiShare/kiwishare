import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/providers/chat_provider.dart';

import '../support/fake_chat_repository.dart';

void main() {
  test(
    'does not expose a conversation created by a previous account',
    () async {
      final repository = FakeChatRepository()
        ..createCompleter = Completer()
        ..createdConversation = testConversation(id: 'old-account-chat');
      final provider = ChatProvider(repository: repository);

      final pending = provider.startConversation(
        itemId: 'item-1',
        token: 'old-account-token',
      );
      await provider.loadConversations('new-account-token');
      repository.createCompleter!.complete(repository.createdConversation!);

      expect(await pending, isNull);
      expect(provider.conversations, isEmpty);
      expect(provider.ownsSession('new-account-token'), isTrue);
    },
  );
}
