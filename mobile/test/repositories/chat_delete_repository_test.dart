import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/repositories/chat_repository.dart';

void main() {
  test('deletes only the authenticated member conversation view', () async {
    late http.Request captured;
    final repository = RestChatRepository(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'status': 'success', 'conversationId': 'conversation-1'}),
          200,
        );
      }),
    );

    await repository.deleteConversation(
      conversationId: 'conversation-1',
      token: 'valid-token',
    );

    expect(captured.method, 'DELETE');
    expect(captured.url.path, '/api/conversations/conversation-1');
    expect(captured.headers['Authorization'], 'Bearer valid-token');
  });
}
