import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/home_discovery_provider.dart';

const _items = [
  ItemModel(
    id: 'plant',
    title: 'Monstera Plant',
    priceNzd: '25',
    location: 'Auckland',
    imageUrl: '',
    isSustainable: true,
    category: 'Plants',
    status: ItemStatus.active,
  ),
  ItemModel(
    id: 'chair',
    title: 'Armchair',
    priceNzd: '80',
    location: 'Wellington',
    imageUrl: '',
    isSustainable: false,
    category: 'Furniture',
    status: ItemStatus.active,
  ),
  ItemModel(
    id: 'bike',
    title: 'Commuter Bike',
    priceNzd: '120',
    location: 'Hamilton',
    imageUrl: '',
    isSustainable: true,
    category: 'vehicle',
    status: ItemStatus.active,
  ),
];

void main() {
  group('HomeDiscoveryProvider', () {
    test('category tabs filter Home products and toggle back to all', () {
      final provider = HomeDiscoveryProvider();

      provider.toggleCategory('Plants');
      expect(provider.selectedCategory, 'Plants');
      expect(provider.filterAndSort(_items).map((item) => item.id), ['plant']);

      provider.toggleCategory('Plants');
      expect(provider.selectedCategory, 'All');
      expect(provider.filterAndSort(_items), hasLength(3));
    });

    test('supports manual and approximate nearby location context', () {
      final provider = HomeDiscoveryProvider();

      provider.setLocation('Wellington');
      expect(provider.selectedLocation, 'Wellington');
      expect(provider.isNearYou, isFalse);
      expect(provider.userLatitude, -41.2866);

      provider.setLocation(
        'Auckland',
        nearYou: true,
        latitude: -36.85,
        longitude: 174.76,
      );
      expect(provider.selectedLocation, 'Auckland');
      expect(provider.isNearYou, isTrue);
      expect(provider.userLongitude, 174.76);
    });

    test('price presets and sort work together', () {
      final provider = HomeDiscoveryProvider()
        ..setPriceRange(HomePriceRange.from25To50)
        ..setSort(HomeProductSort.priceHighToLow);

      final results = provider.filterAndSort(_items);

      expect(results.map((item) => item.id), ['plant']);
      expect(provider.minimumPrice, 25);
      expect(provider.maximumPrice, 50);
    });

    test('transport pilot category includes legacy vehicle data', () {
      final provider = HomeDiscoveryProvider()..toggleCategory('Transport');

      expect(provider.filterAndSort(_items).map((item) => item.id), ['bike']);
    });

    test('keeps Home map state while a detail route is open', () {
      final provider = HomeDiscoveryProvider()
        ..setQuery('monstera')
        ..toggleCategory('Plants')
        ..setCustomPriceRange(minimum: 20, maximum: 80)
        ..setView(HomeProductView.map)
        ..selectPreview('plant');

      expect(provider.query, 'monstera');
      expect(provider.selectedCategory, 'Plants');
      expect(provider.minimumPrice, 20);
      expect(provider.maximumPrice, 80);
      expect(provider.view, HomeProductView.map);
      expect(provider.previewItemId, 'plant');
    });

    test('reset restores the default Home discovery view', () {
      final provider = HomeDiscoveryProvider()
        ..toggleCategory('Furniture')
        ..setLocation('Dunedin')
        ..setSort(HomeProductSort.priceHighToLow)
        ..setSustainableOnly(true)
        ..setView(HomeProductView.map);

      provider.resetFilters();

      expect(provider.selectedCategory, 'All');
      expect(provider.selectedLocation, 'All NZ');
      expect(provider.selectedSort, HomeProductSort.recommended);
      expect(provider.selectedPriceRange, HomePriceRange.any);
      expect(provider.sustainableOnly, isFalse);
      expect(provider.view, HomeProductView.grid);
    });
  });
}
