import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/services/share_service.dart';

void main() {
  group('ShareService', () {
    const service = ShareService();

    const testItem = ItemModel(
      id: 'test-item-123',
      title: 'Ergonomic Office Chair',
      description: 'Comfortable mesh chair',
      category: 'Furniture',
      condition: 'Like new',
      priceNzd: '150',
      location: 'Auckland CBD',
      imageUrl: 'https://example.com/chair.jpg',
      images: ['https://example.com/chair.jpg'],
      isSustainable: true,
      status: ItemStatus.active,
      ownerId: 'user-1',
    );

    test('generates canonical share URL for item', () {
      final url = service.getItemShareUrl(testItem.id);
      expect(url, contains('/items/test-item-123'));
    });

    test('generates expected share text', () {
      final text = service.getItemShareText(testItem);
      expect(text, 'Check out "Ergonomic Office Chair" for \$150 NZD on KiwiShare!');
    });

    test('generates combined share text including title, price and url', () {
      final combined = service.getItemCombinedShareText(testItem);
      expect(combined, contains('Ergonomic Office Chair'));
      expect(combined, contains('\$150 NZD'));
      expect(combined, contains('/items/test-item-123'));
    });
  });
}
