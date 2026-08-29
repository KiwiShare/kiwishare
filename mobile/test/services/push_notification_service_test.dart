import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/services/push_notification_service.dart';

class FakeMessagingClient implements PushMessagingClient {
  bool permissionGranted = true;
  String? token = 'device-token-value-123456789';
  PushEnvelope? initialMessage;
  final tokenController = StreamController<String>.broadcast();
  final foregroundController = StreamController<PushEnvelope>.broadcast();
  final openedController = StreamController<PushEnvelope>.broadcast();

  @override
  Future<PushEnvelope?> getInitialMessage() async => initialMessage;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<PushEnvelope> get onForegroundMessage => foregroundController.stream;

  @override
  Stream<PushEnvelope> get onMessageOpened => openedController.stream;

  @override
  Stream<String> get onTokenRefresh => tokenController.stream;

  @override
  Future<bool> requestPermission() async => permissionGranted;

  Future<void> close() async {
    await tokenController.close();
    await foregroundController.close();
    await openedController.close();
  }
}

class FakePushDeviceRepository implements PushDeviceRepository {
  final registrations = <({String jwt, String token, String platform})>[];
  final removals = <({String jwt, String token})>[];

  @override
  Future<void> register({
    required String jwt,
    required String token,
    required String platform,
  }) async {
    registrations.add((jwt: jwt, token: token, platform: platform));
  }

  @override
  Future<void> unregister({required String jwt, required String token}) async {
    removals.add((jwt: jwt, token: token));
  }
}

PushEnvelope chatEnvelope({String conversationId = 'conversation-1'}) {
  return PushEnvelope(
    title: 'New KiwiShare message',
    body: 'A member sent you a message.',
    data: {
      'type': 'chat_message',
      'conversationId': conversationId,
      'itemId': 'item-1',
      'itemTitle': 'Desk',
      'participantId': 'user-2',
      'participantName': 'Sam',
    },
  );
}

void main() {
  test(
    'REST repository sends authenticated registration and removal requests',
    () async {
      final requests = <http.Request>[];
      final repository = RestPushDeviceRepository(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        }),
      );

      await repository.register(
        jwt: 'jwt-1',
        token: 'device-token-value-123456789',
        platform: 'android',
      );
      await repository.unregister(
        jwt: 'jwt-1',
        token: 'device-token-value-123456789',
      );

      expect(requests.map((request) => request.method), ['POST', 'DELETE']);
      expect(
        requests.every(
          (request) => request.url.path.endsWith('/api/notifications/devices'),
        ),
        isTrue,
      );
      expect(
        requests.every(
          (request) => request.headers['Authorization'] == 'Bearer jwt-1',
        ),
        isTrue,
      );
      expect(jsonDecode(requests.first.body), {
        'token': 'device-token-value-123456789',
        'platform': 'android',
      });
      expect(jsonDecode(requests.last.body), {
        'token': 'device-token-value-123456789',
      });
    },
  );

  test('parses only valid chat notification data', () {
    expect(ChatPushMessage.fromData({'type': 'other'}), isNull);
    expect(ChatPushMessage.fromData({'type': 'chat_message'}), isNull);
    final parsed = ChatPushMessage.fromData(chatEnvelope().data);
    expect(parsed?.conversationId, 'conversation-1');
    expect(parsed?.itemTitle, 'Desk');
    expect(parsed?.participantName, 'Sam');
  });

  test('does not register when notification permission is denied', () async {
    final messaging = FakeMessagingClient()..permissionGranted = false;
    final repository = FakePushDeviceRepository();
    final service = PushNotificationService(
      messaging: messaging,
      repository: repository,
      platform: 'android',
      onForegroundMessage: (_, _) {},
      onNotificationOpened: (_) {},
    );

    await service.activate('jwt-1');

    expect(repository.registrations, isEmpty);
    await service.dispose();
    await messaging.close();
  });

  test('registers, refreshes, and removes the current device token', () async {
    final messaging = FakeMessagingClient();
    final repository = FakePushDeviceRepository();
    final service = PushNotificationService(
      messaging: messaging,
      repository: repository,
      platform: 'ios',
      onForegroundMessage: (_, _) {},
      onNotificationOpened: (_) {},
    );

    await service.activate('jwt-1');
    expect(repository.registrations.single.platform, 'ios');

    messaging.tokenController.add('refreshed-device-token-123456789');
    await Future<void>.delayed(Duration.zero);
    expect(
      repository.registrations.last.token,
      'refreshed-device-token-123456789',
    );

    await service.deactivate('jwt-1');
    expect(
      repository.removals.single.token,
      'refreshed-device-token-123456789',
    );

    messaging.tokenController.add('token-after-logout-123456789');
    await Future<void>.delayed(Duration.zero);
    expect(repository.registrations, hasLength(2));
    await service.dispose();
    await messaging.close();
  });

  test('handles foreground, opened, and initial chat notifications', () async {
    final messaging = FakeMessagingClient()
      ..initialMessage = chatEnvelope(conversationId: 'initial');
    final repository = FakePushDeviceRepository();
    final foreground = <String>[];
    final opened = <String>[];
    final service = PushNotificationService(
      messaging: messaging,
      repository: repository,
      platform: 'android',
      onForegroundMessage: (message, _) {
        foreground.add(message.conversationId);
      },
      onNotificationOpened: (message) {
        opened.add(message.conversationId);
      },
    );

    await service.activate('jwt-1');
    expect(opened, ['initial']);

    messaging.foregroundController.add(
      chatEnvelope(conversationId: 'foreground'),
    );
    messaging.openedController.add(chatEnvelope(conversationId: 'opened'));
    messaging.foregroundController.add(
      const PushEnvelope(data: {'type': 'unrelated'}),
    );
    await Future<void>.delayed(Duration.zero);

    expect(foreground, ['foreground']);
    expect(opened, ['initial', 'opened']);
    await service.dispose();
    await messaging.close();
  });
}
