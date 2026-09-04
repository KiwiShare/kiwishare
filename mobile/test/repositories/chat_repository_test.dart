import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/repositories/chat_repository.dart';

void main() {
  test('loads authenticated conversation previews from the API', () async {
    late http.Request captured;
    final repository = RestChatRepository(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'conversations': [
              {
                'id': 'conversation-1',
                'direction': 'buying',
                'status': 'active',
                'unreadCount': 2,
                'lastMessageText': 'Is this available?',
                'lastMessageAt': '2026-08-27T08:30:00.000Z',
                'item': {
                  'id': 'item-1',
                  'title': 'Wood Desk',
                  'imageUrl': 'https://example.com/desk.jpg',
                },
                'participant': {
                  'id': 'seller-1',
                  'displayName': 'Sam Seller',
                  'avatarUrl': null,
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final conversations = await repository.fetchConversations(
      token: 'valid-token',
    );

    expect(captured.url.path, '/api/conversations');
    expect(captured.headers['Authorization'], 'Bearer valid-token');
    expect(conversations.single.id, 'conversation-1');
    expect(conversations.single.itemTitle, 'Wood Desk');
    expect(conversations.single.participantName, 'Sam Seller');
    expect(conversations.single.unreadCount, 2);
  });

  test(
    'creates an item conversation using the authenticated identity',
    () async {
      late http.Request captured;
      final repository = RestChatRepository(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'status': 'created',
              'conversation': {
                'id': 'conversation-1',
                'direction': 'buying',
                'status': 'active',
                'unreadCount': 0,
                'lastMessageText': '',
                'item': {'id': 'item-1', 'title': 'Wood Desk', 'imageUrl': ''},
                'participant': {'id': 'seller-1', 'displayName': 'Sam Seller'},
              },
            }),
            201,
          );
        }),
      );

      final conversation = await repository.createConversation(
        itemId: 'item-1',
        token: 'valid-token',
      );

      expect(captured.method, 'POST');
      expect(jsonDecode(captured.body), {'itemId': 'item-1'});
      expect(conversation.id, 'conversation-1');
    },
  );

  test(
    'loads pagination and sends trimmed text to the message endpoint',
    () async {
      final requests = <http.Request>[];
      final repository = RestChatRepository(
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'status': 'success',
                'messages': [
                  {
                    'id': 'message-1',
                    'conversationId': 'conversation-1',
                    'senderId': 'buyer-1',
                    'receiverId': 'seller-1',
                    'text': 'Hello',
                    'status': 'sent',
                    'isMine': true,
                    'createdAt': '2026-08-27T08:30:00.000Z',
                  },
                ],
                'pagination': {
                  'hasMore': true,
                  'nextBefore': '2026-08-27T08:30:00.000Z',
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'status': 'created',
              'message': {
                'id': 'message-2',
                'conversationId': 'conversation-1',
                'senderId': 'buyer-1',
                'receiverId': 'seller-1',
                'text': 'Can I collect tomorrow?',
                'status': 'sent',
                'isMine': true,
                'createdAt': '2026-08-27T08:31:00.000Z',
              },
            }),
            201,
          );
        }),
      );

      final page = await repository.fetchMessages(
        conversationId: 'conversation-1',
        token: 'valid-token',
        limit: 20,
      );
      final sent = await repository.sendTextMessage(
        conversationId: 'conversation-1',
        text: 'Can I collect tomorrow?',
        token: 'valid-token',
      );

      expect(
        requests.first.url.path,
        '/api/conversations/conversation-1/messages',
      );
      expect(requests.first.url.queryParameters['limit'], '20');
      expect(page.hasMore, isTrue);
      expect(page.messages.single.isMine, isTrue);
      expect(jsonDecode(requests.last.body), {
        'text': 'Can I collect tomorrow?',
      });
      expect(sent.text, 'Can I collect tomorrow?');
    },
  );

  test('sends an R2 image URL and parses the image message', () async {
    late http.Request captured;
    const imageUrl = 'https://assets.kiwishare.online/images/chat/chair.png';
    final repository = RestChatRepository(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'status': 'created',
            'message': {
              'id': 'message-image-1',
              'conversationId': 'conversation-1',
              'senderId': 'buyer-1',
              'receiverId': 'seller-1',
              'type': 'image',
              'text': '',
              'imageUrl': imageUrl,
              'status': 'sent',
              'isMine': true,
              'createdAt': '2026-08-27T08:31:00.000Z',
            },
          }),
          201,
        );
      }),
    );

    final message = await repository.sendImageMessage(
      conversationId: 'conversation-1',
      imageUrl: imageUrl,
      token: 'valid-token',
    );

    expect(captured.method, 'POST');
    expect(jsonDecode(captured.body), {'type': 'image', 'imageUrl': imageUrl});
    expect(message.isImage, isTrue);
    expect(message.imageUrl, imageUrl);
  });

  test('sends voice metadata and parses the voice message', () async {
    late http.Request captured;
    const audioUrl = 'https://assets.kiwishare.online/audio/chat/voice.m4a';
    final repository = RestChatRepository(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'status': 'created',
            'message': {
              'id': 'message-voice-1',
              'conversationId': 'conversation-1',
              'senderId': 'buyer-1',
              'receiverId': 'seller-1',
              'type': 'voice',
              'text': '',
              'audioUrl': audioUrl,
              'durationMs': 3200,
              'status': 'sent',
              'isMine': true,
              'createdAt': '2026-08-27T08:31:00.000Z',
            },
          }),
          201,
        );
      }),
    );

    final message = await repository.sendVoiceMessage(
      conversationId: 'conversation-1',
      audioUrl: audioUrl,
      durationMs: 3200,
      token: 'valid-token',
    );

    expect(captured.method, 'POST');
    expect(jsonDecode(captured.body), {
      'type': 'voice',
      'audioUrl': audioUrl,
      'durationMs': 3200,
    });
    expect(message.isVoice, isTrue);
    expect(message.durationMs, 3200);
  });

  test('forwards the history cursor and marks a conversation read', () async {
    final requests = <http.Request>[];
    final repository = RestChatRepository(
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'status': 'success',
              'messages': <Map<String, dynamic>>[],
              'pagination': {'hasMore': false, 'nextBefore': null},
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'status': 'success'}), 200);
      }),
    );
    final before = DateTime.utc(2026, 8, 27, 8, 30);

    await repository.fetchMessages(
      conversationId: 'conversation-1',
      token: 'valid-token',
      before: before,
      limit: 25,
    );
    await repository.markConversationRead(
      conversationId: 'conversation-1',
      token: 'valid-token',
    );

    expect(requests.first.url.queryParameters, {
      'limit': '25',
      'before': '2026-08-27T08:30:00.000Z',
    });
    expect(requests.last.method, 'PATCH');
    expect(requests.last.url.path, '/api/conversations/conversation-1/read');
    expect(requests.last.headers['Authorization'], 'Bearer valid-token');
  });

  test('rejects malformed successful chat responses', () async {
    final repository = RestChatRepository(
      client: MockClient(
        (_) async => http.Response(jsonEncode({'status': 'success'}), 200),
      ),
    );

    expect(
      () => repository.fetchConversations(token: 'valid-token'),
      throwsA(
        isA<ChatRepositoryException>().having(
          (error) => error.message,
          'message',
          'The chat service returned an invalid conversation list.',
        ),
      ),
    );
  });

  test('preserves safe API errors and identifies an expired session', () async {
    var requestCount = 0;
    final repository = RestChatRepository(
      client: MockClient((request) async {
        requestCount += 1;
        if (requestCount == 1) {
          return http.Response(
            jsonEncode({
              'status': 'error',
              'message': 'Invalid or expired authorization token.',
            }),
            403,
          );
        }
        return http.Response(
          jsonEncode({
            'status': 'error',
            'message': 'This conversation is not active.',
          }),
          409,
        );
      }),
    );

    expect(
      () => repository.fetchConversations(token: 'expired-token'),
      throwsA(isA<ChatAuthenticationException>()),
    );
    expect(
      () => repository.sendTextMessage(
        conversationId: 'conversation-1',
        text: 'Hello',
        token: 'valid-token',
      ),
      throwsA(
        isA<ChatRepositoryException>().having(
          (error) => error.message,
          'message',
          'This conversation is not active.',
        ),
      ),
    );
  });

  test('preserves the server moderation message for rejected content', () async {
    final repository = RestChatRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'status': 'error',
            'code': 'MESSAGE_CONTENT_NOT_ALLOWED',
            'message':
                'Your message contains language that is not allowed. Please edit it and try again.',
          }),
          422,
        ),
      ),
    );

    expect(
      () => repository.sendTextMessage(
        conversationId: 'conversation-1',
        text: 'Rejected draft',
        token: 'valid-token',
      ),
      throwsA(
        isA<ChatRepositoryException>().having(
          (error) => error.message,
          'message',
          'Your message contains language that is not allowed. Please edit it and try again.',
        ),
      ),
    );
  });
}
