import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../repositories/push_device_repository.dart';

enum PushPermissionStatus { authorized, denied, provisional, unavailable }

class PushEnvelope {
  const PushEnvelope({required this.data, this.title, this.body});

  final Map<String, dynamic> data;
  final String? title;
  final String? body;
}

class ChatPushMessage {
  const ChatPushMessage({
    required this.conversationId,
    required this.recipientId,
    required this.itemId,
    required this.itemTitle,
    required this.participantId,
    required this.participantName,
  });

  final String conversationId;
  final String recipientId;
  final String itemId;
  final String itemTitle;
  final String participantId;
  final String participantName;

  bool isForRecipient(String? userId) {
    final normalizedUserId = userId?.trim();
    return normalizedUserId != null &&
        normalizedUserId.isNotEmpty &&
        recipientId == normalizedUserId;
  }

  static ChatPushMessage? fromData(Map<String, dynamic> data) {
    if (data['type'] != 'chat_message') return null;
    final conversationId = data['conversationId']?.toString().trim() ?? '';
    final recipientId = data['recipientId']?.toString().trim() ?? '';
    if (conversationId.isEmpty || recipientId.isEmpty) return null;
    return ChatPushMessage(
      conversationId: conversationId,
      recipientId: recipientId,
      itemId: data['itemId']?.toString() ?? '',
      itemTitle: data['itemTitle']?.toString() ?? 'Item conversation',
      participantId: data['participantId']?.toString() ?? '',
      participantName: data['participantName']?.toString() ?? 'Kiwi member',
    );
  }
}

class WatchlistPriceDropMessage {
  const WatchlistPriceDropMessage({
    required this.itemId,
    required this.eventId,
    required this.oldPrice,
    required this.newPrice,
  });

  final String itemId;
  final String eventId;
  final String oldPrice;
  final String newPrice;

  static final RegExp _objectId = RegExp(r'^[0-9a-fA-F]{24}$');

  static WatchlistPriceDropMessage? fromData(Map<String, dynamic> data) {
    if (data['type'] != 'watchlist_price_drop') return null;
    final itemId = data['itemId']?.toString().trim() ?? '';
    if (!_objectId.hasMatch(itemId)) return null;
    return WatchlistPriceDropMessage(
      itemId: itemId,
      eventId: data['eventId']?.toString().trim() ?? '',
      oldPrice: data['oldPrice']?.toString().trim() ?? '',
      newPrice: data['newPrice']?.toString().trim() ?? '',
    );
  }
}

/// Firebase Messaging boundary. Tests implement this without initializing
/// Firebase or constructing plugin-specific message/settings objects.
abstract class PushMessagingClient {
  Future<PushPermissionStatus> requestPermission();
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
    data: Map<String, dynamic>.from(message.data),
    title: message.notification?.title,
    body: message.notification?.body,
  );

  @override
  Future<PushPermissionStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PushPermissionStatus.authorized,
      AuthorizationStatus.provisional => PushPermissionStatus.provisional,
      AuthorizationStatus.denied => PushPermissionStatus.denied,
      AuthorizationStatus.notDetermined => PushPermissionStatus.unavailable,
    };
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

abstract class PushNotificationSession {
  Future<void> activate(String jwtToken, {String? userId});
  Future<void> deactivate(String jwtToken);
}

class PushNotificationService implements PushNotificationSession {
  PushNotificationService({
    required this.messagingClient,
    required this.deviceRepository,
    required this.platform,
    required this.onNavigateToItem,
    this.onNavigateToChat,
    void Function(WatchlistPriceDropMessage message, PushEnvelope envelope)?
    onForegroundMessage,
    void Function(ChatPushMessage message, PushEnvelope envelope)?
    onForegroundChatMessage,
  }) : foregroundMessageHandler = onForegroundMessage,
       foregroundChatMessageHandler = onForegroundChatMessage;

  final PushMessagingClient messagingClient;
  final PushDeviceRepository deviceRepository;
  final String platform;
  final void Function(String itemId) onNavigateToItem;
  final void Function(ChatPushMessage message)? onNavigateToChat;
  final void Function(WatchlistPriceDropMessage, PushEnvelope)?
  foregroundMessageHandler;
  final void Function(ChatPushMessage, PushEnvelope)?
  foregroundChatMessageHandler;

  String? _currentToken;
  String? _currentJwt;
  String? _currentUserId;
  final Set<String> _registeredSessionTokens = <String>{};
  Future<void> _tokenOperations = Future<void>.value();
  int _sessionGeneration = 0;
  bool _initialized = false;
  PushEnvelope? _pendingInitialMessage;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<PushEnvelope>? _foregroundSubscription;
  StreamSubscription<PushEnvelope>? _openedSubscription;

  /// Starts listeners once. Repeated calls are safe and do not duplicate them.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _tokenSubscription = messagingClient.onTokenRefresh.listen(
      _handleTokenRefresh,
    );
    _foregroundSubscription = messagingClient.onForegroundMessage.listen(
      _handleForegroundMessage,
    );
    _openedSubscription = messagingClient.onMessageOpened.listen(
      _handleNotificationTap,
    );
    try {
      final initialMessage = await messagingClient.getInitialMessage();
      if (initialMessage != null) {
        if (_currentJwt == null) {
          _pendingInitialMessage = initialMessage;
        } else {
          _handleNotificationTap(initialMessage);
        }
      }
    } catch (error) {
      debugPrint('Push initial-message lookup failed: $error');
    }
  }

  @override
  Future<void> activate(String jwtToken, {String? userId}) async {
    await initialize();
    final generation = ++_sessionGeneration;
    _currentJwt = jwtToken;
    _currentUserId = userId?.trim();

    final pending = _pendingInitialMessage;
    _pendingInitialMessage = null;
    if (pending != null) _handleNotificationTap(pending);

    try {
      final permission = await messagingClient.requestPermission();
      if (permission != PushPermissionStatus.authorized &&
          permission != PushPermissionStatus.provisional) {
        return;
      }
      if (!_isCurrentSession(jwtToken, generation)) return;
      final token = (await messagingClient.getToken())?.trim();
      if (token != null && token.isNotEmpty) {
        await _queueTokenOperation(
          () => _registerForSession(jwtToken, token, generation),
        );
      }
    } catch (error) {
      debugPrint('Push permission/token synchronization failed: $error');
    }
  }

  bool _isCurrentSession(String jwtToken, int generation) =>
      _currentJwt == jwtToken && _sessionGeneration == generation;

  Future<void> _queueTokenOperation(Future<void> Function() operation) {
    final result = _tokenOperations.then((_) => operation());
    _tokenOperations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _registerForSession(
    String jwtToken,
    String token,
    int generation,
  ) async {
    await deviceRepository.registerToken(
      token: token,
      platform: platform,
      jwtToken: jwtToken,
    );
    if (!_isCurrentSession(jwtToken, generation)) {
      if (_currentJwt != jwtToken) {
        try {
          await deviceRepository.unregisterToken(
            token: token,
            jwtToken: jwtToken,
          );
        } catch (error) {
          debugPrint('Late push registration cleanup failed: $error');
        }
      }
      return;
    }

    final previousToken = _currentToken;
    _currentToken = token;
    _registeredSessionTokens.add(token);

    if (previousToken != null && previousToken != token) {
      try {
        await deviceRepository.unregisterToken(
          token: previousToken,
          jwtToken: jwtToken,
        );
        _registeredSessionTokens.remove(previousToken);
      } catch (error) {
        // Keep the old token tracked so deactivate can retry cleanup.
        debugPrint('Previous push token cleanup failed: $error');
      }
    }
  }

  void _handleTokenRefresh(String newToken) {
    final jwtToken = _currentJwt;
    final token = newToken.trim();
    if (jwtToken == null || token.isEmpty) return;
    final generation = _sessionGeneration;
    unawaited(
      _queueTokenOperation(
        () => _registerForSession(jwtToken, token, generation),
      ).catchError((error) {
        debugPrint('Refreshed push token synchronization failed: $error');
      }),
    );
  }

  void _handleForegroundMessage(PushEnvelope envelope) {
    if (_currentJwt == null) return;
    final chatMessage = ChatPushMessage.fromData(envelope.data);
    if (chatMessage != null && _isForCurrentUser(chatMessage)) {
      foregroundChatMessageHandler?.call(chatMessage, envelope);
      return;
    }
    final message = WatchlistPriceDropMessage.fromData(envelope.data);
    if (message != null) foregroundMessageHandler?.call(message, envelope);
  }

  void _handleNotificationTap(PushEnvelope envelope) {
    if (_currentJwt == null) return;
    final chatMessage = ChatPushMessage.fromData(envelope.data);
    if (chatMessage != null && _isForCurrentUser(chatMessage)) {
      onNavigateToChat?.call(chatMessage);
      return;
    }
    final message = WatchlistPriceDropMessage.fromData(envelope.data);
    if (message != null) onNavigateToItem(message.itemId);
  }

  @override
  Future<void> deactivate(String jwtToken) async {
    _sessionGeneration += 1;
    _currentJwt = null;
    _currentUserId = null;
    _currentToken = null;

    // Let registrations already in flight observe the ended session and
    // perform their late-registration cleanup before taking the final snapshot.
    await _tokenOperations;
    final tokens = Set<String>.from(_registeredSessionTokens);
    _registeredSessionTokens.clear();
    for (final token in tokens) {
      try {
        await deviceRepository.unregisterToken(
          token: token,
          jwtToken: jwtToken,
        );
      } catch (error) {
        debugPrint('Push token cleanup during logout failed: $error');
      }
    }
  }

  bool _isForCurrentUser(ChatPushMessage message) {
    return message.isForRecipient(_currentUserId);
  }

  @visibleForTesting
  Future<void> waitForPendingTokenOperations() => _tokenOperations;

  @visibleForTesting
  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
