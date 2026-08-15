import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/listing_query.dart';
import 'package:kiwishare/providers/search_provider.dart';

void main() {
  group('SearchProvider', () {
    test('builds a conventional search, category, location and sort query', () {
      final provider = SearchProvider();
      provider.setQuery('  chair  ');
      provider.setCategory('Furniture');
      provider.setLocation('Auckland');
      provider.setSortOrder(ListingSortOrder.priceLowToHigh);

      expect(provider.listingQuery.query, 'chair');
      expect(provider.listingQuery.category, 'Furniture');
      expect(provider.listingQuery.location, 'Auckland');
      expect(provider.listingQuery.sortOrder, ListingSortOrder.priceLowToHigh);
    });

    test('nearby mode stores coordinates and defaults to nearest-first', () {
      final provider = SearchProvider();
      provider.setNearby(latitude: -36.8485, longitude: 174.7633);

      expect(provider.isNearby, isTrue);
      expect(provider.selectedLocation, 'Near me');
      expect(provider.listingQuery.isNearby, isTrue);
      expect(provider.listingQuery.sortOrder, ListingSortOrder.nearest);
    });

    test('category tabs toggle and reset clears all filters', () {
      final provider = SearchProvider();
      provider.toggleCategory('Camping');
      expect(provider.selectedCategory, 'Camping');
      provider.toggleCategory('Camping');
      expect(provider.selectedCategory, isNull);

      provider.setLocation('Dunedin');
      provider.toggleSavedOnly();
      provider.resetFilters();
      expect(provider.selectedLocation, 'All NZ');
      expect(provider.showSavedOnly, isFalse);
    });
  });
}
