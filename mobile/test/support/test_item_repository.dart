import 'dart:math' as math;

import 'package:kiwishare/models/discovery_options_model.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/repositories/item_repository.dart';

const testCatalogItems = <ItemModel>[
  ItemModel(
    id: 'item_1',
    title: 'Monstera Plant',
    priceNzd: '25',
    location: 'Auckland',
    imageUrl: '',
    isSustainable: true,
    category: 'Plants',
    status: ItemStatus.active,
    description: 'Healthy indoor monstera in a reusable ceramic pot.',
    latitude: -36.8509,
    longitude: 174.7645,
  ),
  ItemModel(
    id: 'item_2',
    title: 'Armchair',
    priceNzd: '80',
    location: 'Wellington',
    imageUrl: '',
    isSustainable: false,
    category: 'Furniture',
    status: ItemStatus.active,
    latitude: -41.2902,
    longitude: 174.7787,
  ),
  ItemModel(
    id: 'item_3',
    title: 'Bike',
    priceNzd: '120',
    location: 'Hamilton',
    imageUrl: '',
    isSustainable: false,
    category: 'Transport',
    status: ItemStatus.active,
    latitude: -37.7878,
    longitude: 175.2810,
  ),
  ItemModel(
    id: 'item_4',
    title: 'Tent - 2 Person',
    priceNzd: '65',
    location: 'Christchurch',
    imageUrl: '',
    isSustainable: true,
    category: 'Camping',
    status: ItemStatus.active,
    latitude: -43.5309,
    longitude: 172.6346,
  ),
  ItemModel(
    id: 'item_5',
    title: 'Sleeping Bag',
    priceNzd: '40',
    location: 'Wellington',
    imageUrl: '',
    isSustainable: true,
    category: 'Camping',
    status: ItemStatus.active,
    latitude: -41.2821,
    longitude: 174.7694,
  ),
  ItemModel(
    id: 'item_6',
    title: 'Camping Stove',
    priceNzd: '35',
    location: 'Auckland',
    imageUrl: '',
    isSustainable: false,
    category: 'Camping',
    status: ItemStatus.active,
    latitude: -36.8624,
    longitude: 174.7541,
  ),
  ItemModel(
    id: 'item_7',
    title: 'Lantern',
    priceNzd: '25',
    location: 'Dunedin',
    imageUrl: '',
    isSustainable: false,
    category: 'Camping',
    status: ItemStatus.active,
    latitude: -45.8758,
    longitude: 170.5006,
  ),
];

class TestItemRepository implements ItemRepository {
  final List<ItemModel> items;

  TestItemRepository({List<ItemModel>? items})
    : items = List.unmodifiable(items ?? testCatalogItems);

  @override
  Future<ItemModel?> fetchItemById(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    final match = items.where((i) => i.id == trimmed);
    return match.isNotEmpty ? match.first : null;
  }

  @override
  Future<DiscoveryOptionsModel> fetchDiscoveryOptions() async {
    final categories = <String, int>{};
    final locations = <String, List<ItemModel>>{};
    for (final item in items.where(
      (item) => item.status == ItemStatus.active,
    )) {
      categories.update(item.category, (count) => count + 1, ifAbsent: () => 1);
      locations.putIfAbsent(item.location, () => []).add(item);
    }

    final categoryOptions =
        categories.entries
            .map(
              (entry) =>
                  DiscoveryCategoryOption(value: entry.key, count: entry.value),
            )
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    final locationOptions = locations.entries.map((entry) {
      final mapped = entry.value.where((item) => item.hasMapLocation).toList();
      return DiscoveryLocationOption(
        value: entry.key,
        count: entry.value.length,
        latitude: mapped.isEmpty
            ? null
            : mapped.map((item) => item.latitude!).reduce((a, b) => a + b) /
                  mapped.length,
        longitude: mapped.isEmpty
            ? null
            : mapped.map((item) => item.longitude!).reduce((a, b) => a + b) /
                  mapped.length,
      );
    }).toList()..sort((a, b) => a.value.compareTo(b.value));
    final prices = items.map((item) => item.numericPrice).toList();

    return DiscoveryOptionsModel(
      categories: categoryOptions,
      locations: locationOptions,
      minimumPrice: prices.isEmpty ? null : prices.reduce(math.min),
      maximumPrice: prices.isEmpty ? null : prices.reduce(math.max),
    );
  }

  @override
  Future<List<ItemModel>> fetchDiscoveryItems(DiscoveryQuery query) async {
    final search = query.query.trim().toLowerCase();
    final results = items.where((item) {
      if (item.status != ItemStatus.active) return false;
      if (search.isNotEmpty &&
          !item.title.toLowerCase().contains(search) &&
          !item.description.toLowerCase().contains(search) &&
          !item.category.toLowerCase().contains(search) &&
          !item.location.toLowerCase().contains(search)) {
        return false;
      }
      if (query.category != null &&
          item.category.toLowerCase() != query.category!.toLowerCase()) {
        return false;
      }
      if (query.location != null &&
          !item.location.toLowerCase().contains(
            query.location!.toLowerCase(),
          )) {
        return false;
      }
      if (query.minimumPrice != null &&
          item.numericPrice < query.minimumPrice!) {
        return false;
      }
      if (query.maximumPrice != null &&
          item.numericPrice > query.maximumPrice!) {
        return false;
      }
      if (query.sustainableOnly && !item.isSustainable) return false;
      if (query.latitude != null &&
          query.longitude != null &&
          query.radiusKm != null) {
        if (!item.hasMapLocation) return false;
        return _distanceKm(
              query.latitude!,
              query.longitude!,
              item.latitude!,
              item.longitude!,
            ) <=
            query.radiusKm!;
      }
      return true;
    }).toList();

    if (query.sort == 'price_asc') {
      results.sort((a, b) => a.numericPrice.compareTo(b.numericPrice));
    } else if (query.sort == 'price_desc') {
      results.sort((a, b) => b.numericPrice.compareTo(a.numericPrice));
    }
    return results;
  }

  @override
  Future<List<ItemModel>> fetchPopularItems() async {
    final results = await fetchDiscoveryItems(const DiscoveryQuery());
    return results.take(3).toList(growable: false);
  }

  @override
  Future<List<ItemModel>> fetchRecommendedItems({int limit = 10}) async {
    final active = items
        .where((item) => item.status == ItemStatus.active)
        .toList();
    // Sort with sustainable items first, then by title
    active.sort((a, b) {
      if (a.isSustainable != b.isSustainable) {
        return a.isSustainable ? -1 : 1;
      }
      return a.title.compareTo(b.title);
    });
    return active.take(limit).toList(growable: false);
  }

  @override
  Stream<List<ItemModel>> searchItems({
    String? query,
    String? category,
  }) async* {
    yield await fetchDiscoveryItems(
      DiscoveryQuery(query: query ?? '', category: category),
    );
  }

  @override
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  }) async {
    return items
        .where(
          (item) => sold
              ? item.status == ItemStatus.sold
              : item.status != ItemStatus.sold,
        )
        .toList(growable: false);
  }
}

double _distanceKm(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  const earthRadiusKm = 6371.0;
  final latDelta = _radians(latitudeB - latitudeA);
  final lonDelta = _radians(longitudeB - longitudeA);
  final a =
      math.sin(latDelta / 2) * math.sin(latDelta / 2) +
      math.cos(_radians(latitudeA)) *
          math.cos(_radians(latitudeB)) *
          math.sin(lonDelta / 2) *
          math.sin(lonDelta / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;
