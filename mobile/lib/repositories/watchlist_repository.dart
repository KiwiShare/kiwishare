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

class RestWatchlistRepository implements WatchlistRepository {
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
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/watchlist');
    try {
      final response = await _client.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['data'] as List<dynamic>? ?? []);
        return list
            .map((raw) => ItemModel.fromJson(raw as Map<String, dynamic>))
            .toList();
      }
      debugPrint(
        'Watchlist fetch failed (${response.statusCode}): ${response.body}',
      );
      return [];
    } catch (e) {
      debugPrint('Watchlist fetch error: $e');
      return [];
    }
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
      return {};
    } catch (e) {
      debugPrint('Watchlist ids fetch error: $e');
      return {};
    }
  }

  @override
  Future<bool> addToWatchlist(String itemId, {String? token}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/watchlist/$itemId');
    try {
      final response = await _client.post(uri, headers: _headers(token));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Add to watchlist error: $e');
      return false;
    }
  }

  @override
  Future<bool> removeFromWatchlist(String itemId, {String? token}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/watchlist/$itemId');
    try {
      final response = await _client.delete(uri, headers: _headers(token));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Remove from watchlist error: $e');
      return false;
    }
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
      return false;
    } catch (e) {
      return false;
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
