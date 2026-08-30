import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';
import 'package:kiwishare/services/chat_photo_upload_service.dart';

import '../support/fake_chat_repository.dart';
import '../support/fake_chat_photo_uploader.dart';

void main() {
  test(
    'loads conversations and exposes a recoverable repository error',
    () async {
      final repository = FakeChatRepository(
        conversations: [testConversation(unreadCount: 2)],
      );
      final provider = ChatProvider(repository: repository);

      await provider.loadConversations('valid-token');

      expect(provider.conversations.single.unreadCount, 2);
      expect(provider.conversationError, isNull);
      expect(provider.isLoadingConversations, isFalse);

      repository.conversationError = const ChatRepositoryException(
        'Chats are temporarily unavailable.',
      );
      await provider.loadConversations('valid-token');

      expect(provider.conversationError, 'Chats are temporarily unavailable.');
      expect(provider.isLoadingConversations, isFalse);
    },
  );

  test(
    'loads message history, marks it read, and clears unread state',
    () async {
      final conversation = testConversation(unreadCount: 3);
      final repository = FakeChatRepository(
        conversations: [conversation],
        messages: {
          conversation.id: [testMessage(id: '1', text: 'Hello', isMine: false)],
        },
      );
      final provider = ChatProvider(repository: repository);
      await provider.loadConversations('valid-token');

      await provider.loadMessages(
        conversation: conversation,
        token: 'valid-token',
      );

      expect(provider.messagesFor(conversation.id).single.text, 'Hello');
      expect(provider.conversations.single.unreadCount, 0);
      expect(repository.messageFetches, 1);
      expect(repository.markReadCalls, 1);
      expect(provider.messageLoadErrorFor(conversation.id), isNull);
    },
  );

  test(
    'notification snapshot cannot replace canonical conversation metadata',
    () async {
      final canonical = testConversation(
        direction: ChatDirection.selling,
        lastMessage: 'Canonical preview',
        unreadCount: 2,
      );
      final notificationSnapshot = testConversation(
        direction: ChatDirection.buying,
        lastMessage: '',
        unreadCount: 0,
      );
      final repository = FakeChatRepository(
        conversations: [canonical],
        messages: {
          canonical.id: [testMessage(id: '1', text: 'New', isMine: false)],
        },
      );
      final provider = ChatProvider(repository: repository);
      await provider.loadConversations('valid-token');

      await provider.loadMessages(
        conversation: notificationSnapshot,
        token: 'valid-token',
      );

      final updated = provider.conversations.single;
      expect(updated.direction, ChatDirection.selling);
      expect(updated.lastMessage, 'Canonical preview');
      expect(updated.lastMessageAt, canonical.lastMessageAt);
      expect(updated.unreadCount, 0);
      expect(provider.conversationById(canonical.id), same(updated));
    },
  );

  test(
    'does not expose a cached conversation to a different session',
    () async {
      final conversation = testConversation();
      final provider = ChatProvider(
        repository: FakeChatRepository(conversations: [conversation]),
      );
      await provider.loadConversations('account-a-token');

      expect(
        provider.conversationByIdForSession(conversation.id, 'account-a-token'),
        same(conversation),
      );
      expect(
        provider.conversationByIdForSession(conversation.id, 'account-b-token'),
        isNull,
      );
      expect(
        provider.conversationByIdForSession(conversation.id, null),
        isNull,
      );
    },
  );

  test(
    'loads a new empty conversation without an unnecessary read request',
    () async {
      final conversation = testConversation(unreadCount: 0);
      final repository = FakeChatRepository(conversations: [conversation]);
      final provider = ChatProvider(repository: repository);
      await provider.loadConversations('valid-token');

      await provider.loadMessages(
        conversation: conversation,
        token: 'valid-token',
      );

      expect(provider.messagesFor(conversation.id), isEmpty);
      expect(provider.messageLoadErrorFor(conversation.id), isNull);
      expect(repository.messageFetches, 1);
      expect(repository.markReadCalls, 0);
    },
  );

  test(
    'marks fetched incoming messages read when the conversation snapshot is stale',
    () async {
      final conversation = testConversation(unreadCount: 0);
      final repository = FakeChatRepository(
        conversations: [conversation],
        messages: {
          conversation.id: [testMessage(id: '1', text: 'New', isMine: false)],
        },
      );
      final provider = ChatProvider(repository: repository);
      await provider.loadConversations('valid-token');

      await provider.loadMessages(
        conversation: conversation,
        token: 'valid-token',
      );

      expect(provider.messagesFor(conversation.id).single.text, 'New');
      expect(repository.markReadCalls, 1);
      expect(provider.messageLoadErrorFor(conversation.id), isNull);
    },
  );

  test('keeps loaded history visible when marking it read fails', () async {
    final conversation = testConversation(unreadCount: 2);
    final repository = FakeChatRepository(
      conversations: [conversation],
      messages: {
        conversation.id: [testMessage(id: '1', text: 'Hello', isMine: false)],
      },
    )..markReadError = Exception('read update failed');
    final provider = ChatProvider(repository: repository);
    await provider.loadConversations('valid-token');

    await provider.loadMessages(
      conversation: conversation,
      token: 'valid-token',
    );

    expect(provider.messagesFor(conversation.id).single.text, 'Hello');
    expect(provider.conversations.single.unreadCount, 2);
    expect(provider.messageLoadErrorFor(conversation.id), isNull);
    expect(repository.markReadCalls, 1);
  });

  test('sends normalized text and updates conversation preview', () async {
    final conversation = testConversation();
    final repository = FakeChatRepository(conversations: [conversation]);
    final provider = ChatProvider(repository: repository);
    await provider.loadConversations('valid-token');

    final sent = await provider.sendText(
      conversation: conversation,
      text: '  Can I collect tomorrow?  ',
      token: 'valid-token',
    );

    expect(sent, isTrue);
    expect(repository.sentTexts, ['Can I collect tomorrow?']);
    expect(
      provider.messagesFor(conversation.id).single.text,
      'Can I collect tomorrow?',
    );
    expect(
      provider.conversations.single.lastMessage,
      'Can I collect tomorrow?',
    );
    expect(provider.isSending(conversation.id), isFalse);
  });

  test(
    'uploads and sends a photo URL without storing binary in chat',
    () async {
      final conversation = testConversation();
      final repository = FakeChatRepository(conversations: [conversation]);
      final uploader = FakeChatPhotoUploader();
      final provider = ChatProvider(
        repository: repository,
        photoUploader: uploader,
      );
      await provider.loadConversations('valid-token');

      final sent = await provider.sendPhoto(
        conversation: conversation,
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'chair.png',
        contentType: 'image/png',
        token: 'valid-token',
      );

      expect(sent, isTrue);
      expect(uploader.uploadCalls, 1);
      expect(uploader.uploadedBytes, [1, 2, 3]);
      expect(repository.sentImageUrls, [uploader.url]);
      expect(provider.messagesFor(conversation.id).single.isImage, isTrue);
      expect(provider.conversations.single.lastMessage, 'Photo');
    },
  );

  test('does not create an image message when its R2 upload fails', () async {
    final conversation = testConversation();
    final repository = FakeChatRepository(conversations: [conversation]);
    final provider = ChatProvider(
      repository: repository,
      photoUploader: FakeChatPhotoUploader(
        error: const ChatPhotoUploadException('Photo upload unavailable.'),
      ),
    );

    final sent = await provider.sendPhoto(
      conversation: conversation,
      bytes: Uint8List.fromList([1]),
      fileName: 'chair.jpg',
      contentType: 'image/jpeg',
      token: 'valid-token',
    );

    expect(sent, isFalse);
    expect(repository.sentImageUrls, isEmpty);
    expect(
      provider.messageSendErrorFor(conversation.id),
      'Photo upload unavailable.',
    );
  });

  test('rejects invalid text locally without calling the API', () async {
    final conversation = testConversation();
    final repository = FakeChatRepository(conversations: [conversation]);
    final provider = ChatProvider(repository: repository);

    expect(
      await provider.sendText(
        conversation: conversation,
        text: '   ',
        token: 'valid-token',
      ),
      isFalse,
    );
    expect(
      await provider.sendText(
        conversation: conversation,
        text: 'x' * 2001,
        token: 'valid-token',
      ),
      isFalse,
    );
    expect(repository.sendCalls, 0);
  });

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
