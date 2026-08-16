import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item_model.dart';
import '../config/api_config.dart';

abstract class ItemRepository {
  Future<List<ItemModel>> fetchPopularItems();
  Stream<List<ItemModel>> searchItems({String? query, String? category});
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
      description: 'Healthy indoor monstera in a reusable ceramic pot.',
      latitude: -36.8509,
      longitude: 174.7645,
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
      description: 'Comfortable fabric armchair with light signs of use.',
      latitude: -41.2902,
      longitude: 174.7787,
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
      description:
          'Reliable commuter bike, recently serviced and ready to ride.',
      latitude: -37.7878,
      longitude: 175.2810,
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
      description: 'Water-resistant two-person tent with poles and carry bag.',
      latitude: -43.5309,
      longitude: 172.6346,
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
      description: 'Warm three-season sleeping bag in good condition.',
      latitude: -41.2821,
      longitude: 174.7694,
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
      description: 'Compact single-burner stove for weekend trips.',
      latitude: -36.8624,
      longitude: 174.7541,
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
      description: 'Rechargeable lantern with three brightness settings.',
      latitude: -45.8758,
      longitude: 170.5006,
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
  Stream<List<ItemModel>> searchItems({
    String? query,
    String? category,
  }) async* {
    // Simulate 600ms latency for real-time changes or query emissions
    await Future.delayed(const Duration(milliseconds: 600));

    List<ItemModel> results = List.from(_allMockItems);

    if (query != null && query.trim().isNotEmpty) {
      final queryLower = query.trim().toLowerCase();
      results = results
          .where(
            (item) =>
                item.title.toLowerCase().contains(queryLower) ||
                item.category.toLowerCase().contains(queryLower) ||
                item.location.toLowerCase().contains(queryLower),
          )
          .toList();
    }

    if (category != null &&
        category.trim().isNotEmpty &&
        category != 'All NZ' &&
        category != 'All') {
      final categoryLower = category.trim().toLowerCase();
      results = results
          .where((item) => item.category.toLowerCase() == categoryLower)
          .toList();
    }

    yield results;
  }
}

class RestItemRepository implements ItemRepository {
  @override
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/users/me/listings',
    ).replace(queryParameters: {'status': sold ? 'sold' : 'active,reserved'});
    final response = await http.get(
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
    final response = await http.get(
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
  Stream<List<ItemModel>> searchItems({
    String? query,
    String? category,
  }) async* {
    final queryParams = <String, String>{};
    if (category != null && category != 'All NZ' && category != 'All') {
      queryParams['category'] = category;
    }
    if (query != null && query.trim().isNotEmpty) {
      queryParams['query'] = query.trim();
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/listings',
    ).replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      yield data
          .map((item) => ItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to fetch listings from server.');
    }
  }
}
