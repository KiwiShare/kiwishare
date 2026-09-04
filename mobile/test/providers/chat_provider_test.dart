import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/models/chat_message_model.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';
import 'package:kiwishare/services/chat_photo_upload_service.dart';

import '../support/fake_chat_repository.dart';
import '../support/fake_chat_photo_uploader.dart';
import '../support/fake_chat_voice_service.dart';

void main() {
  test('sums unread messages across conversations', () async {
    final provider = ChatProvider(
      repository: FakeChatRepository(
        conversations: [
          testConversation(unreadCount: 2),
          testConversation(id: 'conversation-2', unreadCount: 3),
        ],
      ),
    );

    await provider.loadConversations('valid-token');

    expect(provider.totalUnreadCount, 5);
  });

  test('auth token updates preload chats and logout clears them', () async {
    final repository = FakeChatRepository(
      conversations: [testConversation(unreadCount: 2)],
    );
    final provider = ChatProvider(repository: repository);

    provider.updateAuthToken('valid-token');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.conversationFetches, 1);
    expect(provider.totalUnreadCount, 2);

    provider.updateAuthToken(null);
    await Future<void>.delayed(Duration.zero);

    expect(provider.conversations, isEmpty);
    expect(provider.totalUnreadCount, 0);
  });

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

  test('session switch clears history and isolates in-flight loads', () async {
    final conversation = testConversation();
    final accountALoad = Completer<ChatMessagePage>();
    final accountBLoad = Completer<ChatMessagePage>();
    final repository = FakeChatRepository()
      ..messageCompletersByToken['account-a-token'] = accountALoad
      ..messageCompletersByToken['account-b-token'] = accountBLoad;
    final provider = ChatProvider(repository: repository);

    final pendingA = provider.loadMessages(
      conversation: conversation,
      token: 'account-a-token',
    );
    final pendingB = provider.loadMessages(
      conversation: conversation,
      token: 'account-b-token',
    );
    expect(repository.messageFetches, 2);

    accountALoad.complete(
      ChatMessagePage(
        messages: [testMessage(id: '1', text: 'A', isMine: true)],
        hasMore: false,
      ),
    );
    await pendingA;
    expect(provider.messagesFor(conversation.id), isEmpty);
    expect(provider.isLoadingMessages(conversation.id), isTrue);

    accountBLoad.complete(
      ChatMessagePage(
        messages: [testMessage(id: '2', text: 'B', isMine: false)],
        hasMore: false,
      ),
    );
    await pendingB;
    expect(provider.messagesFor(conversation.id).single.id, '2');
    expect(provider.isLoadingMessages(conversation.id), isFalse);
  });

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
    expect(
      provider.messageReadErrorFor(conversation.id),
      'Messages could not be marked as read. Try again.',
    );
    expect(repository.markReadCalls, 1);
  });

  test('clears unread immediately while the read request is pending', () async {
    final conversation = testConversation(unreadCount: 4);
    final pendingRead = Completer<void>();
    final repository = FakeChatRepository(conversations: [conversation])
      ..markReadCompleter = pendingRead;
    final provider = ChatProvider(repository: repository);
    await provider.loadConversations('valid-token');

    final operation = provider.markConversationRead(
      conversation: conversation,
      token: 'valid-token',
    );

    expect(provider.conversations.single.unreadCount, 0);
    expect(provider.totalUnreadCount, 0);
    expect(repository.markReadCalls, 1);

    pendingRead.complete();
    expect(await operation, isTrue);
    expect(provider.messageReadErrorFor(conversation.id), isNull);
  });

  test('deduplicates concurrent read requests for one conversation', () async {
    final conversation = testConversation(unreadCount: 2);
    final pendingRead = Completer<void>();
    final repository = FakeChatRepository(conversations: [conversation])
      ..markReadCompleter = pendingRead;
    final provider = ChatProvider(repository: repository);
    await provider.loadConversations('valid-token');

    final first = provider.markConversationRead(
      conversation: conversation,
      token: 'valid-token',
    );
    final second = provider.markConversationRead(
      conversation: conversation,
      token: 'valid-token',
    );

    expect(repository.markReadCalls, 1);
    pendingRead.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
  });

  test(
    'successful read reconciles a stale in-flight conversation load',
    () async {
      final conversation = testConversation(unreadCount: 4);
      final staleLoad = Completer<List<ChatConversationModel>>();
      final pendingRead = Completer<void>();
      final repository = FakeChatRepository(conversations: [conversation]);
      final provider = ChatProvider(repository: repository);
      await provider.loadConversations('valid-token');
      repository
        ..conversationCompleters.add(staleLoad)
        ..markReadCompleter = pendingRead;

      final loading = provider.loadConversations('valid-token');
      final markingRead = provider.markConversationRead(
        conversation: conversation,
        token: 'valid-token',
      );
      expect(provider.totalUnreadCount, 0);

      staleLoad.complete([conversation]);
      await loading;
      expect(provider.totalUnreadCount, 4);

      repository.conversations = [conversation.copyWith(unreadCount: 0)];
      pendingRead.complete();
      expect(await markingRead, isTrue);
      expect(provider.totalUnreadCount, 0);
      expect(repository.conversationFetches, 3);
    },
  );

  test('successful read preserves unread state from a newer load', () async {
    final conversation = testConversation(unreadCount: 2);
    final newerLoad = Completer<List<ChatConversationModel>>();
    final pendingRead = Completer<void>();
    final repository = FakeChatRepository(conversations: [conversation]);
    final provider = ChatProvider(repository: repository);
    await provider.loadConversations('valid-token');
    repository
      ..conversationCompleters.add(newerLoad)
      ..markReadCompleter = pendingRead;

    final markingRead = provider.markConversationRead(
      conversation: conversation,
      token: 'valid-token',
    );
    final loading = provider.loadConversations('valid-token');
    newerLoad.complete([conversation.copyWith(unreadCount: 1)]);
    await loading;
    expect(provider.totalUnreadCount, 1);

    repository.conversations = [conversation.copyWith(unreadCount: 1)];
    pendingRead.complete();
    expect(await markingRead, isTrue);
    expect(provider.totalUnreadCount, 1);
  });

  test('read success queues revalidation behind a later stale load', () async {
    final conversation = testConversation(unreadCount: 2);
    final staleLoad = Completer<List<ChatConversationModel>>();
    final pendingRead = Completer<void>();
    final repository = FakeChatRepository(conversations: [conversation]);
    final provider = ChatProvider(repository: repository);
    await provider.loadConversations('valid-token');
    repository
      ..conversationCompleters.add(staleLoad)
      ..markReadCompleter = pendingRead
      ..conversations = [conversation.copyWith(unreadCount: 0)];

    final markingRead = provider.markConversationRead(
      conversation: conversation,
      token: 'valid-token',
    );
    final loading = provider.loadConversations('valid-token');

    pendingRead.complete();
    await Future<void>.delayed(Duration.zero);
    staleLoad.complete([conversation]);
    await loading;
    expect(await markingRead, isTrue);

    expect(repository.conversationFetches, 3);
    expect(provider.totalUnreadCount, 0);
  });

  test(
    'retry immediately clears a read error without a canonical chat',
    () async {
      final conversation = testConversation(unreadCount: 0);
      final repository = FakeChatRepository()
        ..markReadError = Exception('read failed');
      final provider = ChatProvider(repository: repository);

      expect(
        await provider.markConversationRead(
          conversation: conversation,
          token: 'valid-token',
        ),
        isFalse,
      );
      expect(provider.messageReadErrorFor(conversation.id), isNotNull);

      repository.markReadError = null;
      var notifications = 0;
      provider.addListener(() => notifications += 1);
      final retry = provider.markConversationRead(
        conversation: conversation,
        token: 'valid-token',
      );

      expect(provider.messageReadErrorFor(conversation.id), isNull);
      expect(notifications, 1);
      expect(await retry, isTrue);
    },
  );

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

  test('uploads, sends, and appends a bounded voice message', () async {
    final conversation = testConversation();
    final repository = FakeChatRepository(conversations: [conversation]);
    final uploader = FakeChatVoiceUploader();
    final provider = ChatProvider(
      repository: repository,
      voiceUploader: uploader,
    );
    await provider.loadConversations('valid-token');

    final sent = await provider.sendVoice(
      conversation: conversation,
      bytes: Uint8List.fromList([7, 8, 9]),
      fileName: 'voice.m4a',
      contentType: 'audio/mp4',
      durationMs: 3200,
      token: 'valid-token',
    );

    expect(sent, isTrue);
    expect(uploader.uploadCalls, 1);
    expect(repository.sentAudioUrls, [uploader.url]);
    expect(repository.sentVoiceDurations, [3200]);
    expect(provider.messagesFor(conversation.id).single.isVoice, isTrue);
    expect(provider.conversations.single.lastMessage, 'Voice message');
  });

  test('rejects voice messages over 60 seconds before upload', () async {
    final conversation = testConversation();
    final uploader = FakeChatVoiceUploader();
    final provider = ChatProvider(
      repository: FakeChatRepository(conversations: [conversation]),
      voiceUploader: uploader,
    );

    final sent = await provider.sendVoice(
      conversation: conversation,
      bytes: Uint8List.fromList([1]),
      fileName: 'voice.m4a',
      contentType: 'audio/mp4',
      durationMs: 60001,
      token: 'valid-token',
    );

    expect(sent, isFalse);
    expect(uploader.uploadCalls, 0);
    expect(
      provider.messageSendErrorFor(conversation.id),
      'Voice messages can be up to 60 seconds long.',
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
