import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/providers/search_provider.dart';

void main() {
  group('SearchProvider', () {
    test('category tabs toggle without removing conventional browsing', () {
      final provider = SearchProvider();

      provider.toggleCategory('Camping');
      expect(provider.selectedCategory, 'Camping');

      provider.toggleCategory('Camping');
      expect(provider.selectedCategory, 'All');
    });

    test('stores manual and nearby location context', () {
      final provider = SearchProvider();

      provider.setLocation('Wellington');
      expect(provider.selectedLocation, 'Wellington');
      expect(provider.isNearYou, isFalse);

      provider.setLocation('Auckland', nearYou: true);
      expect(provider.selectedLocation, 'Auckland');
      expect(provider.isNearYou, isTrue);
    });

    test('reset restores the default products view', () {
      final provider = SearchProvider();
      provider.setCategory('Furniture');
      provider.setLocation('Dunedin');
      provider.setSort(ProductSort.priceHighToLow);
      provider.toggleSustainableOnly();

      provider.resetFilters();

      expect(provider.selectedCategory, 'All');
      expect(provider.selectedLocation, 'All NZ');
      expect(provider.selectedSort, ProductSort.recommended);
      expect(provider.sustainableOnly, isFalse);
    });

    test('keeps discovery state while a detail route is open', () {
      final provider = SearchProvider();

      provider.setQuery('camping stove');
      provider.setCategory('Camping');
      provider.setPriceRange(minimum: 20, maximum: 80);
      provider.setViewMode(ProductViewMode.map);
      provider.selectPreview('item_6');

      expect(provider.query, 'camping stove');
      expect(provider.selectedCategory, 'Camping');
      expect(provider.minimumPrice, 20);
      expect(provider.maximumPrice, 80);
      expect(provider.viewMode, ProductViewMode.map);
      expect(provider.previewItemId, 'item_6');
    });
  });
}
