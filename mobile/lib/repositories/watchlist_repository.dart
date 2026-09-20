import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/item_model.dart';

abstract class WatchlistRepository {
  Future<List<ItemModel>> fetchWatchlist({String? token});
  Future<Set<String>> fetchWatchedItemIds({String? token});
  Future<bool> addToWatchlist(String itemId, {String? token});
  Future<bool> removeFromWatchlist(String itemId, {String? token});
  Future<bool> isWatched(String itemId, {String? token});
}

abstract interface class PaginatedWatchlistRepository {
  Future<WatchlistPage> fetchWatchlistPage({
    String? token,
    String? cursor,
    int limit = 25,
  });
}

class WatchlistPage {
  const WatchlistPage({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  final List<ItemModel> items;
  final String? nextCursor;
  final bool hasMore;
}

class WatchlistRepositoryException implements Exception {
  const WatchlistRepositoryException();
}

class RestWatchlistRepository
    implements WatchlistRepository, PaginatedWatchlistRepository {
  final http.Client _client;

  RestWatchlistRepository({http.Client? client})
    : _client = client ?? http.Client();

  Map<String, String> _headers(String? token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  @override
  Future<List<ItemModel>> fetchWatchlist({String? token}) async {
    return (await fetchWatchlistPage(token: token)).items;
  }

  @override
  Future<WatchlistPage> fetchWatchlistPage({
    String? token,
    String? cursor,
    int limit = 25,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/watchlist');
    final requestUri = uri.replace(
      queryParameters: {'limit': '$limit', 'cursor': ?cursor},
    );
    final response = await _client.get(requestUri, headers: _headers(token));
    if (response.statusCode != 200) {
      throw const WatchlistRepositoryException();
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (data['data'] as List<dynamic>? ?? []);
    final pagination = data['pagination'] as Map<String, dynamic>?;
    return WatchlistPage(
      items: list
          .map((raw) => ItemModel.fromJson(raw as Map<String, dynamic>))
          .toList(),
      nextCursor: pagination?['nextCursor'] as String?,
      hasMore: pagination?['hasMore'] == true,
    );
  }

  @override
  Future<Set<String>> fetchWatchedItemIds({String? token}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/watchlist/ids');
    try {
      final response = await _client.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ids = (data['itemIds'] as List<dynamic>? ?? [])
            .map((id) => id.toString())
            .toSet();
        return ids;
      }
      throw const WatchlistRepositoryException();
    } catch (error) {
      if (error is WatchlistRepositoryException) rethrow;
      debugPrint('Watchlist IDs request failed.');
      throw const WatchlistRepositoryException();
    }
  }

  @override
  Future<bool> addToWatchlist(String itemId, {String? token}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/watchlist/$itemId');
    final response = await _client.post(uri, headers: _headers(token));
    return response.statusCode == 200;
  }

  @override
  Future<bool> removeFromWatchlist(String itemId, {String? token}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/watchlist/$itemId');
    final response = await _client.delete(uri, headers: _headers(token));
    return response.statusCode == 200;
  }

  @override
  Future<bool> isWatched(String itemId, {String? token}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/watchlist/check/$itemId');
    try {
      final response = await _client.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isWatched'] == true;
      }
      throw const WatchlistRepositoryException();
    } catch (error) {
      if (error is WatchlistRepositoryException) rethrow;
      debugPrint('Watchlist status request failed.');
      throw const WatchlistRepositoryException();
    }
  }
}

class TestWatchlistRepository implements WatchlistRepository {
  final Set<String> _watchedIds = <String>{};
  final List<ItemModel> _items = <ItemModel>[];

  TestWatchlistRepository({
    Set<String>? initialIds,
    List<ItemModel>? initialItems,
  }) {
    if (initialIds != null) _watchedIds.addAll(initialIds);
    if (initialItems != null) _items.addAll(initialItems);
  }

  @override
  Future<List<ItemModel>> fetchWatchlist({String? token}) async {
    return _items.where((item) => _watchedIds.contains(item.id)).toList();
  }

  @override
  Future<Set<String>> fetchWatchedItemIds({String? token}) async {
    return Set.from(_watchedIds);
  }

  @override
  Future<bool> addToWatchlist(String itemId, {String? token}) async {
    _watchedIds.add(itemId);
    return true;
  }

  @override
  Future<bool> removeFromWatchlist(String itemId, {String? token}) async {
    _watchedIds.remove(itemId);
    return true;
  }

  @override
  Future<bool> isWatched(String itemId, {String? token}) async {
    return _watchedIds.contains(itemId);
  }

  void seedItem(ItemModel item) {
    _items.removeWhere((i) => i.id == item.id);
    _items.add(item);
    _watchedIds.add(item.id);
  }
}
