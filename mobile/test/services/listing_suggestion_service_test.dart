import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/services/listing_suggestion_service.dart';

void main() {
  const validSuggestion = {
    'title': 'Solid wood study desk',
    'description': 'A sturdy pre-owned desk with light signs of use.',
    'category': 'Furniture',
    'condition': 'Good',
    'priceNzd': '120',
  };

  test('sends trimmed authenticated context and parses a suggestion', () async {
    late http.Request captured;
    final service = RestListingSuggestionService(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'status': 'success', 'suggestion': validSuggestion}),
          200,
        );
      }),
    );

    final suggestion = await service.suggest(
      authToken: 'valid-token',
      input: const ListingSuggestionInput(
        title: '  desk  ',
        description: '  scratched top  ',
        category: 'Furniture',
        condition: 'Good',
        location: 'Mount Eden, Auckland',
      ),
    );

    expect(captured.url.path, '/api/listing-suggestions');
    expect(captured.headers['Authorization'], 'Bearer valid-token');
    expect(jsonDecode(captured.body), {
      'title': 'desk',
      'description': 'scratched top',
      'category': 'Furniture',
      'condition': 'Good',
      'location': 'Mount Eden, Auckland',
    });
    expect(suggestion.title, validSuggestion['title']);
    expect(suggestion.priceNzd, '120');
  });

  test('rejects malformed and adversarial suggestion responses', () async {
    for (final suggestion in [
      {...validSuggestion, 'title': 'TV'},
      {...validSuggestion, 'category': 'Weapons'},
      {...validSuggestion, 'priceNzd': '-10'},
      {...validSuggestion, 'description': 'Visit https://bad.example'},
      {...validSuggestion, 'title': 'Desk\u202Ehidden'},
    ]) {
      final service = RestListingSuggestionService(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode({'suggestion': suggestion}), 200),
        ),
      );

      expect(
        () => service.suggest(
          authToken: 'valid-token',
          input: const ListingSuggestionInput(title: 'Desk'),
        ),
        throwsA(isA<ListingSuggestionException>()),
      );
    }
  });

  test('allows normal line breaks in a plain-text description', () {
    final suggestion = ListingSuggestion.fromJson({
      ...validSuggestion,
      'description': 'Solid desk.\nMinor marks on the top.',
    });

    expect(suggestion.description, contains('\n'));
  });

  test('maps expired sessions and provider errors to safe messages', () async {
    final expired = RestListingSuggestionService(
      client: MockClient((_) async => http.Response('{}', 403)),
    );
    final unavailable = RestListingSuggestionService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'AI suggestions are temporarily unavailable.',
          }),
          503,
        ),
      ),
    );

    expect(
      () => expired.suggest(
        authToken: 'expired',
        input: const ListingSuggestionInput(title: 'Desk'),
      ),
      throwsA(isA<ListingSuggestionAuthenticationException>()),
    );
    expect(
      () => unavailable.suggest(
        authToken: 'valid',
        input: const ListingSuggestionInput(title: 'Desk'),
      ),
      throwsA(
        isA<ListingSuggestionException>().having(
          (error) => error.message,
          'message',
          'AI suggestions are temporarily unavailable.',
        ),
      ),
    );
  });

  test('times out without hanging the form', () async {
    final pending = Completer<http.Response>();
    final service = RestListingSuggestionService(
      client: MockClient((_) => pending.future),
      timeout: const Duration(milliseconds: 1),
    );

    expect(
      () => service.suggest(
        authToken: 'valid',
        input: const ListingSuggestionInput(title: 'Desk'),
      ),
      throwsA(
        isA<ListingSuggestionException>().having(
          (error) => error.message,
          'message',
          contains('took too long'),
        ),
      ),
    );
  });
}
