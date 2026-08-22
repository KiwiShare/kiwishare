import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/discovery_options_model.dart';
import '../models/item_model.dart';

abstract class ItemRepository {
  Future<List<ItemModel>> fetchPopularItems();
  Future<DiscoveryOptionsModel> fetchDiscoveryOptions();
  Future<List<ItemModel>> fetchDiscoveryItems(DiscoveryQuery query);
  Stream<List<ItemModel>> searchItems({String? query, String? category});
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  });
}

class RestItemRepository implements ItemRepository {
  @override
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/users/me/usedItems',
    ).replace(queryParameters: {'status': sold ? 'sold' : 'active,reserved'});
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    return _parseItemsResponse(response, 'Failed to fetch your listings.');
  }

  @override
  Future<List<ItemModel>> fetchPopularItems() async {
    final items = await fetchDiscoveryItems(const DiscoveryQuery());
    return items.take(3).toList(growable: false);
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
