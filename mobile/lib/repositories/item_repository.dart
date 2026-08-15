import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/item_model.dart';
import '../models/listing_query.dart';
import '../config/api_config.dart';

abstract class ItemRepository {
  Future<List<ItemModel>> fetchPopularItems();
  Future<List<ItemModel>> fetchListings(ListingQuery query);
  Future<ItemModel> fetchItemById(String id);
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  });
}

class MockItemRepository implements ItemRepository {
  // Seed data matching the mockup images
  final List<ItemModel> _allMockItems = [
    const ItemModel(
      id: 'item_1',
      title: 'Monstera Plant',
      priceNzd: '25',
      location: 'Auckland',
      imageUrl:
          'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?auto=format&fit=crop&q=80&w=400',
      isSustainable: true,
      category: 'Plants',
      status: ItemStatus.active,
      latitude: -36.8485,
      longitude: 174.7633,
      description: 'A healthy indoor plant ready for a new home.',
      condition: 'good',
    ),
    const ItemModel(
      id: 'item_2',
      title: 'Armchair',
      priceNzd: '80',
      location: 'Wellington',
      imageUrl:
          'https://images.unsplash.com/photo-1567538096630-e0c55bd6374c?auto=format&fit=crop&q=80&w=400',
      isSustainable: false,
      category: 'Furniture',
      status: ItemStatus.active,
      latitude: -41.2866,
      longitude: 174.7756,
      description: 'Comfortable armchair in good used condition.',
      condition: 'good',
    ),
    const ItemModel(
      id: 'item_3',
      title: 'Bike',
      priceNzd: '120',
      location: 'Hamilton',
      imageUrl:
          'https://images.unsplash.com/photo-1485965120184-e220f721d03e?auto=format&fit=crop&q=80&w=400',
      isSustainable: false,
      category: 'Transport',
      status: ItemStatus.active,
      latitude: -37.7870,
      longitude: 175.2793,
      description: 'Reliable commuter bike, recently serviced.',
      condition: 'good',
    ),
    const ItemModel(
      id: 'item_4',
      title: 'Tent - 2 Person',
      priceNzd: '65',
      location: 'Christchurch',
      imageUrl:
          'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?auto=format&fit=crop&q=80&w=400',
      isSustainable: true,
      category: 'Camping',
      status: ItemStatus.active,
      latitude: -43.5321,
      longitude: 172.6362,
    ),
    const ItemModel(
      id: 'item_5',
      title: 'Sleeping Bag',
      priceNzd: '40',
      location: 'Wellington',
      imageUrl:
          'https://images.unsplash.com/photo-1517643675306-0067ecb6fc9d?auto=format&fit=crop&q=80&w=400',
      isSustainable: true,
      category: 'Camping',
      status: ItemStatus.active,
      latitude: -41.2866,
      longitude: 174.7756,
    ),
    const ItemModel(
      id: 'item_6',
      title: 'Camping Stove',
      priceNzd: '35',
      location: 'Auckland',
      imageUrl:
          'https://images.unsplash.com/photo-1596751303335-742b20e5277b?auto=format&fit=crop&q=80&w=400',
      isSustainable: false,
      category: 'Camping',
      status: ItemStatus.active,
      latitude: -36.8485,
      longitude: 174.7633,
    ),
    const ItemModel(
      id: 'item_7',
      title: 'Lantern',
      priceNzd: '25',
      location: 'Dunedin',
      imageUrl:
          'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&q=80&w=400',
      isSustainable: false,
      category: 'Camping',
      status: ItemStatus.active,
      latitude: -45.8788,
      longitude: 170.5028,
    ),
  ];

  @override
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _allMockItems
        .where(
          (item) => sold
              ? item.status == ItemStatus.sold
              : item.status != ItemStatus.sold,
        )
        .toList();
  }

  @override
  Future<List<ItemModel>> fetchPopularItems() async {
    // Simulate 800ms network delay
    await Future.delayed(const Duration(milliseconds: 800));
    // Popular items are Monstera, Armchair, Bike
    return _allMockItems.sublist(0, 3);
  }

  @override
  Future<List<ItemModel>> fetchListings(ListingQuery query) async {
    // Simulate 600ms latency for real-time changes or query emissions
    await Future.delayed(const Duration(milliseconds: 600));

    List<ItemModel> results = List.from(_allMockItems);

    if (query.query.trim().isNotEmpty) {
      final queryLower = query.query.trim().toLowerCase();
      results = results
          .where(
            (item) =>
                item.title.toLowerCase().contains(queryLower) ||
                item.category.toLowerCase().contains(queryLower) ||
                item.location.toLowerCase().contains(queryLower),
          )
          .toList();
    }

    if (query.category != null && query.category!.trim().isNotEmpty) {
      final categoryLower = query.category!.trim().toLowerCase();
      results = results
          .where((item) => item.category.toLowerCase() == categoryLower)
          .toList();
    }

    if (query.location != null) {
      results = results
          .where(
            (item) => item.location.toLowerCase().contains(
              query.location!.toLowerCase(),
            ),
          )
          .toList();
    }
    if (query.isNearby) {
      results = results
          .map((item) {
            final distance = _distanceKm(
              query.latitude!,
              query.longitude!,
              item.latitude,
              item.longitude,
            );
            return item.copyWith(distanceKm: distance);
          })
          .where(
            (item) => (item.distanceKm ?? double.infinity) <= query.radiusKm,
          )
          .toList();
    }
    switch (query.sortOrder) {
      case ListingSortOrder.priceLowToHigh:
        results.sort((a, b) => a.priceValue.compareTo(b.priceValue));
      case ListingSortOrder.priceHighToLow:
        results.sort((a, b) => b.priceValue.compareTo(a.priceValue));
      case ListingSortOrder.nearest:
        results.sort(
          (a, b) => (a.distanceKm ?? double.infinity).compareTo(
            b.distanceKm ?? double.infinity,
          ),
        );
      case ListingSortOrder.popular:
      case ListingSortOrder.newest:
        break;
    }
    return query.limit == null ? results : results.take(query.limit!).toList();
  }

  @override
  Future<ItemModel> fetchItemById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _allMockItems.firstWhere((item) => item.id == id);
  }
}

class RestItemRepository implements ItemRepository {
  final http.Client _client;

  RestItemRepository({http.Client? client}) : _client = client ?? http.Client();
  @override
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/users/me/listings',
    ).replace(queryParameters: {'status': sold ? 'sold' : 'active,reserved'});
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch your listings.');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => ItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ItemModel>> fetchPopularItems() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/listings'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final items = data
          .map((item) => ItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return items.take(3).toList();
    } else {
      throw Exception('Failed to fetch popular items from server.');
    }
  }

  @override
  Future<List<ItemModel>> fetchListings(ListingQuery query) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/listings',
    ).replace(queryParameters: query.toQueryParameters());

    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((item) => ItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to fetch listings from server.');
    }
  }

  @override
  Future<ItemModel> fetchItemById(String id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/listings/$id'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      return ItemModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    if (response.statusCode == 404) throw Exception('Listing not found.');
    throw Exception('Failed to fetch listing details.');
  }
}

double? _distanceKm(double lat, double lng, double? itemLat, double? itemLng) {
  if (itemLat == null || itemLng == null) return null;
  const earthRadiusKm = 6371.0;
  const degreesToRadians = 0.017453292519943295;
  final dLat = (itemLat - lat) * degreesToRadians;
  final dLng = (itemLng - lng) * degreesToRadians;
  final a =
      (sin(dLat / 2) * sin(dLat / 2)) +
      cos(lat * degreesToRadians) *
          cos(itemLat * degreesToRadians) *
          (sin(dLng / 2) * sin(dLng / 2));
  return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
}
