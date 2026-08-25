import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/discovery_options_model.dart';
import '../models/item_model.dart';

class ItemUpdateDraft {
  final String title;
  final String description;
  final String category;
  final String condition;
  final String priceNzd;
  final String location;
  final bool negotiable;
  final bool isSustainable;

  const ItemUpdateDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.priceNzd,
    required this.location,
    required this.negotiable,
    required this.isSustainable,
  });

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'category': category,
    'condition': condition,
    'priceNzd': priceNzd.trim(),
    'location': location.trim(),
    'negotiable': negotiable,
    'isSustainable': isSustainable,
  };
}

class ItemRepositoryException implements Exception {
  final String message;
  final int? statusCode;

  const ItemRepositoryException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ItemNotFoundException extends ItemRepositoryException {
  const ItemNotFoundException()
    : super('This listing is no longer available.', statusCode: 404);
}

class ItemAuthorizationException extends ItemRepositoryException {
  const ItemAuthorizationException(super.message, {super.statusCode});
}

abstract class ItemRepository {
  Future<ItemModel> fetchItemById(String itemId);
  Future<ItemModel> updateItem({
    required String itemId,
    required String token,
    required ItemUpdateDraft draft,
  });
  Future<void> deleteItem({required String itemId, required String token});
  Future<List<ItemModel>> fetchPopularItems();
  Future<List<ItemModel>> fetchRecommendedItems({int limit = 10});
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
  Future<ItemModel> fetchItemById(String itemId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/usedItems/$itemId'),
      headers: {'Accept': 'application/json'},
    );
    return _parseItemResponse(response);
  }

  @override
  Future<ItemModel> updateItem({
    required String itemId,
    required String token,
    required ItemUpdateDraft draft,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/usedItems/$itemId'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(draft.toJson()),
    );
    return _parseItemResponse(response);
  }

  @override
  Future<void> deleteItem({
    required String itemId,
    required String token,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/usedItems/$itemId'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200 || response.statusCode == 204) return;
    throw _itemRequestException(response);
  }

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

ItemModel _parseItemResponse(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw _itemRequestException(response);
  }
  final data = jsonDecode(response.body);
  if (data is! Map<String, dynamic>) {
    throw const ItemRepositoryException('Invalid listing response.');
  }
  final rawItem = data['item'];
  if (rawItem is Map<String, dynamic>) return ItemModel.fromJson(rawItem);
  if (rawItem is Map) {
    return ItemModel.fromJson(Map<String, dynamic>.from(rawItem));
  }
  return ItemModel.fromJson(data);
}

ItemRepositoryException _itemRequestException(http.Response response) {
  if (response.statusCode == 404) return const ItemNotFoundException();
  var message = 'The listing request could not be completed.';
  try {
    final data = jsonDecode(response.body);
    if (data is Map && data['message'] != null) {
      message = data['message'].toString();
    }
  } catch (_) {}
  if (response.statusCode == 401 || response.statusCode == 403) {
    return ItemAuthorizationException(message, statusCode: response.statusCode);
  }
  return ItemRepositoryException(message, statusCode: response.statusCode);
}
