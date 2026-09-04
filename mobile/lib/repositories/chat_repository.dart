import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/chat_conversation_model.dart';
import '../models/chat_message_model.dart';

class ChatRepositoryException implements Exception {
  const ChatRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatAuthenticationException extends ChatRepositoryException {
  const ChatAuthenticationException()
    : super('Your session has expired. Please sign in again.');
}

abstract class ChatRepository {
  Future<List<ChatConversationModel>> fetchConversations({
    required String token,
  });

  Future<ChatConversationModel> createConversation({
    required String itemId,
    required String token,
  });

  Future<ChatMessagePage> fetchMessages({
    required String conversationId,
    required String token,
    DateTime? before,
    int limit = 50,
  });

  Future<ChatMessageModel> sendTextMessage({
    required String conversationId,
    required String text,
    required String token,
  });

  Future<ChatMessageModel> sendImageMessage({
    required String conversationId,
    required String imageUrl,
    required String token,
  });

  Future<ChatMessageModel> sendVoiceMessage({
    required String conversationId,
    required String audioUrl,
    required int durationMs,
    required String token,
  });

  Future<ChatMessageModel> sendLocationMessage({
    required String conversationId,
    required String name,
    required double latitude,
    required double longitude,
    required String token,
  });

  Future<int> markConversationRead({
    required String conversationId,
    required String throughMessageId,
    required String token,
  });

  Future<void> deleteConversation({
    required String conversationId,
    required String token,
  });
}

class RestChatRepository implements ChatRepository {
  RestChatRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  @override
  Future<List<ChatConversationModel>> fetchConversations({
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/conversations'),
      headers: _headers(token),
    );
    final data = _responseMap(response);
    final conversations = data['conversations'];
    if (conversations is! List) {
      throw const ChatRepositoryException(
        'The chat service returned an invalid conversation list.',
      );
    }
    return conversations
        .whereType<Map>()
        .map(
          (value) =>
              ChatConversationModel.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false);
  }

  @override
  Future<ChatConversationModel> createConversation({
    required String itemId,
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/conversations'),
      headers: _headers(token),
      body: jsonEncode({'itemId': itemId}),
    );
    final data = _responseMap(response);
    final conversation = data['conversation'];
    if (conversation is! Map) {
      throw const ChatRepositoryException(
        'The chat service returned an invalid conversation.',
      );
    }
    return ChatConversationModel.fromJson(
      Map<String, dynamic>.from(conversation),
    );
  }

  @override
  Future<ChatMessagePage> fetchMessages({
    required String conversationId,
    required String token,
    DateTime? before,
    int limit = 50,
  }) async {
    final parameters = <String, String>{'limit': limit.toString()};
    if (before != null) parameters['before'] = before.toUtc().toIso8601String();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/conversations/$conversationId/messages',
    ).replace(queryParameters: parameters);
    final response = await _client.get(uri, headers: _headers(token));
    final data = _responseMap(response);
    final rawMessages = data['messages'];
    final pagination = data['pagination'];
    if (rawMessages is! List || pagination is! Map) {
      throw const ChatRepositoryException(
        'The chat service returned invalid message history.',
      );
    }
    return ChatMessagePage(
      messages: rawMessages
          .whereType<Map>()
          .map(
            (value) =>
                ChatMessageModel.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(growable: false),
      hasMore: pagination['hasMore'] == true,
      nextBefore: DateTime.tryParse(pagination['nextBefore']?.toString() ?? ''),
    );
  }

  @override
  Future<ChatMessageModel> sendTextMessage({
    required String conversationId,
    required String text,
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/conversations/$conversationId/messages',
      ),
      headers: _headers(token),
      body: jsonEncode({'text': text}),
    );
    final data = _responseMap(response);
    final message = data['message'];
    if (message is! Map) {
      throw const ChatRepositoryException(
        'The chat service returned an invalid message.',
      );
    }
    return ChatMessageModel.fromJson(Map<String, dynamic>.from(message));
  }

  @override
  Future<ChatMessageModel> sendImageMessage({
    required String conversationId,
    required String imageUrl,
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/conversations/$conversationId/messages',
      ),
      headers: _headers(token),
      body: jsonEncode({'type': 'image', 'imageUrl': imageUrl}),
    );
    final data = _responseMap(response);
    final message = data['message'];
    if (message is! Map) {
      throw const ChatRepositoryException(
        'The chat service returned an invalid message.',
      );
    }
    return ChatMessageModel.fromJson(Map<String, dynamic>.from(message));
  }

  @override
  Future<ChatMessageModel> sendVoiceMessage({
    required String conversationId,
    required String audioUrl,
    required int durationMs,
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/conversations/$conversationId/messages',
      ),
      headers: _headers(token),
      body: jsonEncode({
        'type': 'voice',
        'audioUrl': audioUrl,
        'durationMs': durationMs,
      }),
    );
    final data = _responseMap(response);
    final message = data['message'];
    if (message is! Map) {
      throw const ChatRepositoryException(
        'The chat service returned an invalid message.',
      );
    }
    return ChatMessageModel.fromJson(Map<String, dynamic>.from(message));
  }

  @override
  Future<ChatMessageModel> sendLocationMessage({
    required String conversationId,
    required String name,
    required double latitude,
    required double longitude,
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse(
        '${ApiConfig.baseUrl}/api/conversations/$conversationId/messages',
      ),
      headers: _headers(token),
      body: jsonEncode({
        'type': 'location',
        'location': {
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
        },
      }),
    );
    final data = _responseMap(response);
    final message = data['message'];
    if (message is! Map) {
      throw const ChatRepositoryException(
        'The chat service returned an invalid message.',
      );
    }
    return ChatMessageModel.fromJson(Map<String, dynamic>.from(message));
  }

  @override
  Future<int> markConversationRead({
    required String conversationId,
    required String throughMessageId,
    required String token,
  }) async {
    final response = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/conversations/$conversationId/read'),
      headers: _headers(token),
      body: jsonEncode({'throughMessageId': throughMessageId}),
    );
    final data = _responseMap(response);
    final unreadCount = data['unreadCount'];
    if (unreadCount is! int || unreadCount < 0) {
      throw const ChatRepositoryException('Invalid unread count response.');
    }
    return unreadCount;
  }

  @override
  Future<void> deleteConversation({
    required String conversationId,
    required String token,
  }) async {
    final response = await _client.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/conversations/$conversationId'),
      headers: _headers(token),
    );
    _responseMap(response);
  }

  Map<String, dynamic> _responseMap(http.Response response) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    if (response.statusCode == 401 ||
        (response.statusCode == 403 &&
            (data?['message']?.toString().contains('authorization token') ??
                false))) {
      throw const ChatAuthenticationException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatRepositoryException(
        data?['message']?.toString() ??
            'Chat is unavailable right now. Please try again.',
      );
    }
    if (data == null) {
      throw const ChatRepositoryException(
        'The chat service returned an invalid response.',
      );
    }
    return data;
  }
}
