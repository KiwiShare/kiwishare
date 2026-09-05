import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/repositories/push_device_repository.dart';
import 'package:kiwishare/services/push_notification_service.dart';

const _itemId = '64f000000000000000000001';

PushEnvelope _priceDrop({
  String type = 'watchlist_price_drop',
  Object? itemId = _itemId,
}) => PushEnvelope(
  data: {
    'type': type,
    'itemId': ?itemId,
    'eventId': 'evt-1',
    'itemTitle': 'Test chair',
    'oldPrice': '50.00',
    'newPrice': '40.00',
  },
  body: 'Price dropped',
);

PushEnvelope _chatMessage({
  String conversationId = 'conversation-1',
  String recipientId = 'user-1',
}) => PushEnvelope(
  data: {
    'type': 'chat_message',
    'recipientId': recipientId,
    'conversationId': conversationId,
    'itemId': _itemId,
    'itemTitle': 'Test chair',
    'participantId': 'participant-1',
    'participantName': 'Test Seller',
  },
  body: 'New chat message',
);

PushEnvelope _chatRead({
  String conversationId = 'conversation-1',
  String recipientId = 'user-1',
}) => PushEnvelope(
  data: {
    'type': 'chat_read',
    'recipientId': recipientId,
    'conversationId': conversationId,
  },
);

void main() {
  group('PushNotificationService', () {
    late _FakeMessagingClient messaging;
    late _FakePushDeviceRepository repository;
    late List<String> openedItems;
    late List<String> foregroundItems;
    late List<String> openedChats;
    late List<String> foregroundChats;
    late List<String> foregroundChatReads;
    late PushNotificationService service;

    setUp(() {
      messaging = _FakeMessagingClient();
      repository = _FakePushDeviceRepository();
      openedItems = [];
      foregroundItems = [];
      openedChats = [];
      foregroundChats = [];
      foregroundChatReads = [];
      service = PushNotificationService(
        messagingClient: messaging,
        deviceRepository: repository,
        platform: 'android',
        onNavigateToItem: openedItems.add,
        onForegroundMessage: (message, _) =>
            foregroundItems.add(message.itemId),
        onNavigateToChat: (message) => openedChats.add(message.conversationId),
        onForegroundChatMessage: (message, _) =>
            foregroundChats.add(message.conversationId),
        onForegroundChatRead: (message) =>
            foregroundChatReads.add(message.conversationId),
      );
    });

    test('price-drop payload provides a clear foreground summary', () {
      final message = WatchlistPriceDropMessage.fromData(_priceDrop().data);

      expect(message, isNotNull);
      expect(message!.itemTitle, 'Test chair');
      expect(
        message.notificationSummary,
        'Test chair dropped from \$50.00 to \$40.00',
      );
    });

    tearDown(() async {
      await service.dispose();
      await messaging.dispose();
    });

    test(
      'authorized and provisional permissions synchronize initial token',
      () async {
        for (final permission in [
          PushPermissionStatus.authorized,
          PushPermissionStatus.provisional,
        ]) {
          messaging.permission = permission;
          await service.activate('jwt-${permission.name}');
        }

        expect(repository.registrations, hasLength(2));
        expect(repository.registrations.last.platform, 'android');
        expect(repository.registrations.last.token, 'initial-token-1234567890');
      },
    );

    test(
      'denied and unavailable permissions do not request or register token',
      () async {
        messaging.permission = PushPermissionStatus.denied;
        await service.activate('jwt-denied');
        messaging.permission = PushPermissionStatus.unavailable;
        await service.activate('jwt-unavailable');

        expect(messaging.getTokenCalls, 0);
        expect(repository.registrations, isEmpty);
      },
    );

    test(
      'refresh removes the old token and logout removes the new token',
      () async {
        await service.activate('jwt-user');
        messaging.tokenRefresh.add('refreshed-token-1234567890');
        await _drainEvents();
        await service.waitForPendingTokenOperations();

        expect(
          repository.registrations.last.token,
          'refreshed-token-1234567890',
        );
        expect(repository.removals, hasLength(1));
        expect(repository.removals.single.token, 'initial-token-1234567890');
        expect(repository.removals.single.jwtToken, 'jwt-user');

        await service.deactivate('jwt-user');
        expect(repository.removals.map((entry) => entry.token), [
          'initial-token-1234567890',
          'refreshed-token-1234567890',
        ]);
      },
    );

    test(
      'failed refreshed-token registration preserves the old logout target',
      () async {
        await service.activate('jwt-user');
        repository.registrationFailures.add('bad-refresh-token-1234567890');

        messaging.tokenRefresh.add('bad-refresh-token-1234567890');
        await _drainEvents();
        await service.waitForPendingTokenOperations();
        await service.deactivate('jwt-user');

        expect(repository.removals, hasLength(1));
        expect(repository.removals.single.token, 'initial-token-1234567890');
      },
    );

    test('failed refresh cleanup is retried during logout', () async {
      await service.activate('jwt-user');
      repository.removalFailuresRemaining['initial-token-1234567890'] = 1;

      messaging.tokenRefresh.add('refreshed-token-1234567890');
      await _drainEvents();
      await service.waitForPendingTokenOperations();
      await service.deactivate('jwt-user');

      expect(
        repository.removals.where(
          (entry) => entry.token == 'initial-token-1234567890',
        ),
        hasLength(2),
      );
      expect(
        repository.removals.where(
          (entry) => entry.token == 'refreshed-token-1234567890',
        ),
        hasLength(1),
      );
    });

    test('foreground messages are parsed without navigating', () async {
      await service.activate('jwt-user');
      messaging.foreground.add(_priceDrop());
      await _drainEvents();

      expect(foregroundItems, [_itemId]);
      expect(openedItems, isEmpty);
    });

    test(
      'foreground chat messages are dispatched without navigating',
      () async {
        await service.activate('jwt-user', userId: 'user-1');
        messaging.foreground.add(_chatMessage());
        await _drainEvents();

        expect(foregroundChats, ['conversation-1']);
        expect(openedChats, isEmpty);
        expect(foregroundItems, isEmpty);
      },
    );

    test('chat notification taps navigate to the conversation', () async {
      messaging.initialMessage = _chatMessage(conversationId: 'initial-chat');
      await service.initialize();
      await service.activate('jwt-user', userId: 'user-1');
      messaging.opened.add(_chatMessage(conversationId: 'opened-chat'));
      await _drainEvents();

      expect(openedChats, ['initial-chat', 'opened-chat']);
      expect(openedItems, isEmpty);
    });

    test('foreground read receipts refresh only the current account', () async {
      await service.activate('jwt-user', userId: 'user-1');
      messaging.foreground
        ..add(_chatRead())
        ..add(_chatRead(conversationId: 'wrong-user', recipientId: 'user-2'));
      await _drainEvents();

      expect(foregroundChatReads, ['conversation-1']);
      expect(foregroundChats, isEmpty);
      expect(openedChats, isEmpty);
    });

    test('read receipt notification taps never navigate', () async {
      messaging.initialMessage = _chatRead(conversationId: 'initial-read');
      await service.initialize();
      await service.activate('jwt-user', userId: 'user-1');
      messaging.opened.add(_chatRead(conversationId: 'opened-read'));
      await _drainEvents();

      expect(openedChats, isEmpty);
      expect(openedItems, isEmpty);
      expect(foregroundChatReads, isEmpty);
    });

    test('chat notifications for a previous account are ignored', () async {
      await service.activate('jwt-user-b', userId: 'user-b');
      messaging.foreground.add(_chatMessage(recipientId: 'user-a'));
      messaging.opened.add(_chatMessage(recipientId: 'user-a'));
      await _drainEvents();

      expect(foregroundChats, isEmpty);
      expect(openedChats, isEmpty);
    });

    test(
      'background and terminated taps navigate to canonical item id',
      () async {
        messaging.initialMessage = _priceDrop();
        await service.initialize();
        await service.activate('jwt-user');
        messaging.opened.add(_priceDrop());
        await _drainEvents();

        expect(openedItems, [_itemId, _itemId]);
      },
    );

    test(
      'unsupported, missing, and malformed payloads are ignored safely',
      () async {
        await service.activate('jwt-user');
        messaging.opened
          ..add(_priceDrop(type: 'chat_message'))
          ..add(_priceDrop(itemId: null))
          ..add(_priceDrop(itemId: 'not-an-object-id'));
        await _drainEvents();

        expect(openedItems, isEmpty);
      },
    );

    test('repeated initialization does not duplicate listeners', () async {
      await service.initialize();
      await service.initialize();
      await service.activate('jwt-user');
      messaging.opened.add(_priceDrop());
      messaging.tokenRefresh.add('one-refresh-token-1234567890');
      await _drainEvents();

      expect(openedItems, [_itemId]);
      expect(
        repository.registrations.where(
          (entry) => entry.token == 'one-refresh-token-1234567890',
        ),
        hasLength(1),
      );
      expect(messaging.initialMessageCalls, 1);
    });
  });
}

Future<void> _drainEvents() => Future<void>.delayed(Duration.zero);

class _Registration {
  const _Registration(this.token, this.platform, this.jwtToken);
  final String token;
  final String platform;
  final String jwtToken;
}

class _Removal {
  const _Removal(this.token, this.jwtToken);
  final String token;
  final String jwtToken;
}

class _FakePushDeviceRepository implements PushDeviceRepository {
  final registrations = <_Registration>[];
  final removals = <_Removal>[];
  final registrationFailures = <String>{};
  final removalFailuresRemaining = <String, int>{};

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
    required String jwtToken,
  }) async {
    registrations.add(_Registration(token, platform, jwtToken));
    if (registrationFailures.contains(token)) {
      throw Exception('Registration failed');
    }
  }

  @override
  Future<void> unregisterToken({
    required String token,
    required String jwtToken,
  }) async {
    removals.add(_Removal(token, jwtToken));
    final failures = removalFailuresRemaining[token] ?? 0;
    if (failures > 0) {
      removalFailuresRemaining[token] = failures - 1;
      throw Exception('Removal failed');
    }
  }
}

class _FakeMessagingClient implements PushMessagingClient {
  PushPermissionStatus permission = PushPermissionStatus.authorized;
  String? token = 'initial-token-1234567890';
  PushEnvelope? initialMessage;
  int getTokenCalls = 0;
  int initialMessageCalls = 0;

  final tokenRefresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushEnvelope>.broadcast();
  final opened = StreamController<PushEnvelope>.broadcast();

  @override
  Future<String?> getToken() async {
    getTokenCalls += 1;
    return token;
  }

  @override
  Future<PushEnvelope?> getInitialMessage() async {
    initialMessageCalls += 1;
    return initialMessage;
  }

  @override
  Stream<PushEnvelope> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushEnvelope> get onMessageOpened => opened.stream;

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Future<PushPermissionStatus> requestPermission() async => permission;

  Future<void> dispose() async {
    await tokenRefresh.close();
    await foreground.close();
    await opened.close();
  }
}
