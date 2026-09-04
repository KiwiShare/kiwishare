import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/repositories/item_repository.dart';

void main() {
  group('RestItemRepository.fetchItemById', () {
    test(
      'returns ItemModel when server responds with 200 and item payload',
      () async {
        final client = MockClient((request) async {
          expect(request.url.path, '/api/usedItems/64f000000000000000000001');
          return http.Response(
            jsonEncode({
              'status': 'success',
              'item': {
                'id': '64f000000000000000000001',
                'title': 'Vintage Leather Jacket',
                'priceNzd': '150',
                'location': 'Auckland CBD',
                'imageUrl': 'https://example.com/jacket.jpg',
                'isSustainable': true,
                'category': 'Clothing',
                'status': 'active',
                'description': 'Classic brown leather jacket.',
                'ownerId': 'owner_1',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final repo = RestItemRepository(client: client);
        final item = await repo.fetchItemById('64f000000000000000000001');

        expect(item, isNotNull);
        expect(item!.id, '64f000000000000000000001');
        expect(item.title, 'Vintage Leather Jacket');
        expect(item.priceNzd, '150');
        expect(item.status, ItemStatus.active);
      },
    );

    test('returns null when server responds with 404', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'status': 'error', 'message': 'Used item not found.'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RestItemRepository(client: client);
      final item = await repo.fetchItemById('non_existent');

      expect(item, isNull);
    });

    test(
      'returns null immediately for blank or whitespace itemId without network request',
      () async {
        var requestMade = false;
        final client = MockClient((request) async {
          requestMade = true;
          return http.Response('{}', 200);
        });

        final repo = RestItemRepository(client: client);
        final itemEmpty = await repo.fetchItemById('');
        final itemWhitespace = await repo.fetchItemById('   ');

        expect(itemEmpty, isNull);
        expect(itemWhitespace, isNull);
        expect(requestMade, isFalse);
      },
    );

    test('throws Exception on 500 server error', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final repo = RestItemRepository(client: client);

      expect(() => repo.fetchItemById('item_error'), throwsException);
    });
  });
}
