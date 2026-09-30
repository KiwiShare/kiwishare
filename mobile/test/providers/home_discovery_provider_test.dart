import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/discovery_options_model.dart';
import 'package:kiwishare/providers/home_discovery_provider.dart';

const _options = DiscoveryOptionsModel(
  categories: [
    DiscoveryCategoryOption(value: 'Furniture', count: 2),
    DiscoveryCategoryOption(value: 'Plants', count: 1),
    DiscoveryCategoryOption(value: 'Bicycles', count: 3),
  ],
  locations: [
    DiscoveryLocationOption(
      value: 'Wellington',
      count: 2,
      latitude: -41.2866,
      longitude: 174.7756,
    ),
  ],
  minimumPrice: 12,
  maximumPrice: 240,
);

void main() {
  group('HomeDiscoveryProvider', () {
    test('uses category options supplied by the backend', () {
      final provider = HomeDiscoveryProvider()..applyOptions(_options);

      expect(provider.categories.map((option) => option.value), [
        'Furniture',
        'Plants',
        'Bicycles',
      ]);
      provider.toggleCategory('Bicycles');
      expect(provider.discoveryQuery.category, 'Bicycles');

      provider.toggleCategory('Bicycles');
      expect(provider.discoveryQuery.category, isNull);
    });

    test('manual locations use coordinates supplied by the backend', () {
      final provider = HomeDiscoveryProvider()..applyOptions(_options);

      provider.setLocation('Wellington');

      expect(provider.selectedLocation, 'Wellington');
      expect(provider.isNearYou, isFalse);
      expect(provider.userLatitude, -41.2866);
      expect(provider.discoveryQuery.location, 'Wellington');
    });

    test('current location creates an approximate nearby server query', () {
      final provider = HomeDiscoveryProvider()
        ..setLocation(
          'Auckland',
          nearYou: true,
          latitude: -36.85,
          longitude: 174.76,
        );

      expect(provider.discoveryQuery.location, isNull);
      expect(provider.discoveryQuery.latitude, -36.85);
      expect(provider.discoveryQuery.longitude, 174.76);
      expect(provider.discoveryQuery.radiusKm, 50);
    });

    test('price presets and sort are passed to the server', () {
      final provider = HomeDiscoveryProvider()
        ..setPriceRange(HomePriceRange.from25To50)
        ..setSort(HomeProductSort.priceHighToLow);

      expect(provider.discoveryQuery.minimumPrice, 25);
      expect(provider.discoveryQuery.maximumPrice, 50);
      expect(provider.discoveryQuery.sort, 'price_desc');
    });

    test('keeps Home map state while a detail route is open', () {
      final provider = HomeDiscoveryProvider()
        ..applyOptions(_options)
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
        ..applyOptions(_options)
        ..toggleCategory('Furniture')
        ..setLocation('Wellington')
        ..setSort(HomeProductSort.priceHighToLow)
        ..setSustainableOnly(true)
        ..setView(HomeProductView.map);

      provider.resetFilters();

      expect(
        provider.selectedCategory,
        HomeDiscoveryProvider.allCategoriesLabel,
      );
      expect(provider.selectedLocation, HomeDiscoveryProvider.defaultLocation);
      expect(provider.selectedSort, HomeProductSort.recommended);
      expect(provider.selectedPriceRange, HomePriceRange.any);
      expect(provider.sustainableOnly, isFalse);
      expect(provider.view, HomeProductView.grid);
      expect(provider.activeFilterCount, 0);
    });

    test('activeFilterCount tracks category and sort/filter options', () {
      final provider = HomeDiscoveryProvider()..applyOptions(_options);
      expect(provider.activeFilterCount, 0);

      // Auto-location or manual location does not affect filter modal count
      provider.setLocation(
        'Auckland',
        nearYou: true,
        latitude: -36.85,
        longitude: 174.76,
      );
      provider.setQuery('table');
      expect(provider.activeFilterCount, 0);
      provider.toggleCategory('Furniture');
      expect(provider.activeFilterCount, 1);

      // Setting Sort & filter sheet options increments count
      provider.setSort(HomeProductSort.priceLowToHigh);
      expect(provider.activeFilterCount, 2);

      provider.setPriceRange(HomePriceRange.under25);
      expect(provider.activeFilterCount, 3);

      provider.setSustainableOnly(true);
      expect(provider.activeFilterCount, 4);

      provider.resetFilters();
      expect(provider.activeFilterCount, 0);
    });
  });
}
