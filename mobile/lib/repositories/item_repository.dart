import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/discovery_options_model.dart';
import '../models/item_model.dart';

abstract class ItemRepository {
  Future<ItemModel?> fetchItemById(String id);
  Future<List<ItemModel>> fetchPopularItems();
  Future<List<ItemModel>> fetchRecommendedItems({int limit = 10});
  Future<DiscoveryOptionsModel> fetchDiscoveryOptions();
  Future<List<ItemModel>> fetchDiscoveryItems(DiscoveryQuery query);
  Stream<List<ItemModel>> searchItems({String? query, String? category});
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  });
  Future<ItemModel> updateItem({
    required String id,
    required String token,
    required Map<String, dynamic> updates,
  }) {
    throw UnimplementedError('updateItem is not implemented');
  }
  Future<Map<String, dynamic>> promoteItem({
    required String id,
    required String token,
  }) {
    throw UnimplementedError('promoteItem is not implemented');
  }
  Future<ItemModel> toggleListingStatus({
    required String id,
    required bool publish,
    required String token,
  }) {
    throw UnimplementedError('toggleListingStatus is not implemented');
  }
}

class RestItemRepository implements ItemRepository {
  final http.Client _client;

  RestItemRepository({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<ItemModel> updateItem({
    required String id,
    required String token,
    required Map<String, dynamic> updates,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/usedItems/$id');
    final response = await _client.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(updates),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update item (${response.statusCode}): ${response.body}');
    }
    final data = jsonDecode(response.body);
    final itemData = data is Map<String, dynamic> && data['item'] is Map<String, dynamic>
        ? data['item'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return ItemModel.fromMap(itemData);
  }

  @override
  Future<ItemModel?> fetchItemById(String id) async {
    final trimmedId = id.trim();
    if (trimmedId.isEmpty) return null;
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/usedItems/$trimmedId');
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch item details (${response.statusCode}).');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid item response.');
    }
    final itemData = data['item'] is Map<String, dynamic>
        ? data['item'] as Map<String, dynamic>
        : data;
    return ItemModel.fromMap(itemData);
  }

  @override
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/users/me/usedItems',
    ).replace(
      queryParameters: {
        'status': sold ? 'sold' : 'active,reserved,draft,delisted',
      },
    );
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return _parseItemsResponse(response, 'Failed to fetch your listings.');
  }

  @override
  Future<Map<String, dynamic>> promoteItem({
    required String id,
    required String token,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/usedItems/$id/promote');
    final response = await _client.post(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final item = ItemModel.fromMap(data['item'] as Map<String, dynamic>);
      final kiwiGold = data['kiwiGold'] is num ? (data['kiwiGold'] as num).toInt() : null;
      return {'item': item, 'kiwiGold': kiwiGold, 'message': data['message']};
    }
    String message = 'Failed to promote item.';
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  @override
  Future<ItemModel> toggleListingStatus({
    required String id,
    required bool publish,
    required String token,
  }) async {
    final endpoint = publish ? 'relist' : 'delist';
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/usedItems/$id/$endpoint');
    final response = await _client.post(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ItemModel.fromMap(data['item'] as Map<String, dynamic>);
    }
    return updateItem(
      id: id,
      token: token,
      updates: {'status': publish ? 'active' : 'draft'},
    );
  }

  @override
  Future<List<ItemModel>> fetchPopularItems() async {
    final items = await fetchDiscoveryItems(const DiscoveryQuery());
    return items.take(3).toList(growable: false);
  }

  @override
  Future<List<ItemModel>> fetchRecommendedItems({int limit = 10}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/usedItems/recommended',
    ).replace(queryParameters: {'limit': limit.toString()});
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );
    return _parseItemsResponse(
      response,
      'Failed to fetch recommended listings from server.',
    );
  }

  @override
  Future<DiscoveryOptionsModel> fetchDiscoveryOptions() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/usedItems/discovery-options'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch discovery filters from server.');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid discovery options response.');
    }
    return DiscoveryOptionsModel.fromJson(data);
  }

  @override
  Future<List<ItemModel>> fetchDiscoveryItems(DiscoveryQuery query) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/usedItems',
    ).replace(queryParameters: query.toQueryParameters());
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );
    return _parseItemsResponse(
      response,
      'Failed to fetch discovery listings from server.',
    );
  }

  @override
  Stream<List<ItemModel>> searchItems({
    String? query,
    String? category,
  }) async* {
    yield await fetchDiscoveryItems(
      DiscoveryQuery(
        query: query ?? '',
        category: category == null || category == 'All NZ' || category == 'All'
            ? null
            : category,
      ),
    );
  }
}

List<ItemModel> _parseItemsResponse(http.Response response, String error) {
  if (response.statusCode != 200) throw Exception(error);
  final data = jsonDecode(response.body);
  if (data is! List) throw const FormatException('Invalid listings response.');
  return data
      .whereType<Map<String, dynamic>>()
      .map(ItemModel.fromJson)
      .toList(growable: false);
}
