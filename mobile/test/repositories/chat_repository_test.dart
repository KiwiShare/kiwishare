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
}
