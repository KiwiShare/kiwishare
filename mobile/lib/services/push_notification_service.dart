import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ChatPushMessage {
  const ChatPushMessage({
    required this.conversationId,
    required this.itemId,
    required this.itemTitle,
    required this.participantId,
    required this.participantName,
  });

  final String conversationId;
  final String itemId;
  final String itemTitle;
  final String participantId;
  final String participantName;

  static ChatPushMessage? fromData(Map<String, dynamic> data) {
    if (data['type'] != 'chat_message') return null;
    final conversationId = data['conversationId']?.toString().trim() ?? '';
    if (conversationId.isEmpty) return null;
    return ChatPushMessage(
      conversationId: conversationId,
      itemId: data['itemId']?.toString() ?? '',
      itemTitle: data['itemTitle']?.toString() ?? 'Item conversation',
      participantId: data['participantId']?.toString() ?? '',
      participantName: data['participantName']?.toString() ?? 'Kiwi member',
    );
  }
}

class PushEnvelope {
  const PushEnvelope({required this.data, this.title, this.body});

  final Map<String, dynamic> data;
  final String? title;
  final String? body;
}

abstract class PushMessagingClient {
  Future<bool> requestPermission();
  Future<String?> getToken();
  Future<PushEnvelope?> getInitialMessage();
  Stream<String> get onTokenRefresh;
  Stream<PushEnvelope> get onForegroundMessage;
  Stream<PushEnvelope> get onMessageOpened;
}

class FirebasePushMessagingClient implements PushMessagingClient {
  FirebasePushMessagingClient({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  static PushEnvelope _map(RemoteMessage message) => PushEnvelope(
    data: message.data,
    title: message.notification?.title,
    body: message.notification?.body,
  );

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _messaging.getToken();

  @override
  Future<PushEnvelope?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _map(message);
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushEnvelope> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_map);

  @override
  Stream<PushEnvelope> get onMessageOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_map);
}

abstract class PushDeviceRepository {
  Future<void> register({
    required String jwt,
    required String token,
    required String platform,
  });
  Future<void> unregister({required String jwt, required String token});
}

class RestPushDeviceRepository implements PushDeviceRepository {
  RestPushDeviceRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _devicesUrl =>
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/devices');

  Map<String, String> _headers(String jwt) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $jwt',
  };

  @override
  Future<void> register({
    required String jwt,
    required String token,
    required String platform,
  }) async {
    final response = await _client.post(
      _devicesUrl,
      headers: _headers(jwt),
      body: jsonEncode({'token': token, 'platform': platform}),
    );
    if (response.statusCode != 200) {
      throw Exception('Push notification registration failed.');
    }
  }

  @override
  Future<void> unregister({required String jwt, required String token}) async {
    final request = http.Request('DELETE', _devicesUrl)
      ..headers.addAll(_headers(jwt))
      ..body = jsonEncode({'token': token});
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw Exception('Push notification removal failed.');
    }
  }
}

abstract class PushNotificationSession {
  Future<void> activate(String jwt);
  Future<void> deactivate(String jwt);
}

class PushNotificationService implements PushNotificationSession {
  PushNotificationService({
    required this.messaging,
    required this.repository,
    required this.platform,
    required void Function(ChatPushMessage message, PushEnvelope envelope)
    onForegroundMessage,
    required void Function(ChatPushMessage message) onNotificationOpened,
  }) : foregroundMessageHandler = onForegroundMessage,
       notificationOpenedHandler = onNotificationOpened;

  final PushMessagingClient messaging;
  final PushDeviceRepository repository;
  final String platform;
  final void Function(ChatPushMessage, PushEnvelope) foregroundMessageHandler;
  final void Function(ChatPushMessage) notificationOpenedHandler;

  String? _jwt;
  String? _deviceToken;
  int _sessionGeneration = 0;
  bool _listenersStarted = false;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<PushEnvelope>? _foregroundSubscription;
  StreamSubscription<PushEnvelope>? _openedSubscription;

  @override
  Future<void> activate(String jwt) async {
    final generation = ++_sessionGeneration;
    _jwt = jwt;
    try {
      if (!await messaging.requestPermission()) return;
      if (!_isCurrentSession(jwt, generation)) return;
      _startListeners();
      final token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _registerForSession(jwt, token, generation);
      }
      if (!_isCurrentSession(jwt, generation)) return;
      final initial = await messaging.getInitialMessage();
      if (_isCurrentSession(jwt, generation) && initial != null) {
        _open(initial);
      }
    } catch (error) {
      debugPrint('Push notification setup failed: $error');
    }
  }

  bool _isCurrentSession(String jwt, int generation) =>
      _jwt == jwt && _sessionGeneration == generation;

  void _startListeners() {
    if (_listenersStarted) return;
    _listenersStarted = true;
    _tokenSubscription = messaging.onTokenRefresh.listen((token) async {
      final jwt = _jwt;
      if (jwt == null) return;
      final generation = _sessionGeneration;
      try {
        await _registerForSession(jwt, token, generation);
      } catch (error) {
        debugPrint('Push token refresh could not be registered: $error');
      }
    });
    _foregroundSubscription = messaging.onForegroundMessage.listen((message) {
      if (_jwt == null) return;
      final chat = ChatPushMessage.fromData(message.data);
      if (chat != null) foregroundMessageHandler(chat, message);
    });
    _openedSubscription = messaging.onMessageOpened.listen(_open);
  }

  void _open(PushEnvelope envelope) {
    if (_jwt == null) return;
    final chat = ChatPushMessage.fromData(envelope.data);
    if (chat != null) notificationOpenedHandler(chat);
  }

  Future<void> _registerForSession(
    String jwt,
    String token,
    int generation,
  ) async {
    await repository.register(jwt: jwt, token: token, platform: platform);
    if (!_isCurrentSession(jwt, generation)) {
      // Registration may finish after logout. Compensate with a removal using
      // the same signed session; the backend accepts an expired but otherwise
      // valid JWT for this exact-token cleanup endpoint only.
      if (_jwt != jwt) {
        try {
          await repository.unregister(jwt: jwt, token: token);
        } catch (error) {
          debugPrint('Late push registration could not be removed: $error');
        }
      }
      return;
    }
    _deviceToken = token;
  }

  @override
  Future<void> deactivate(String jwt) async {
    _sessionGeneration += 1;
    final token = _deviceToken;
    _jwt = null;
    _deviceToken = null;
    if (token == null) return;
    try {
      await repository.unregister(jwt: jwt, token: token);
    } catch (error) {
      debugPrint('Push token could not be removed during logout: $error');
    }
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
