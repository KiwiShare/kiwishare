import 'package:flutter/material.dart';
import '../models/discovery_options_model.dart';
import '../models/item_model.dart';
import '../repositories/item_repository.dart';

class ListingProvider extends ChangeNotifier {
  final ItemRepository itemRepository;

  ListingProvider({required this.itemRepository});

  List<ItemModel>? _cachedPopularItems;
  List<ItemModel>? get cachedPopularItems => _cachedPopularItems;
  List<ItemModel>? _cachedFeaturedItems;
  List<ItemModel>? get cachedFeaturedItems => _cachedFeaturedItems;
  List<ItemModel>? _cachedRecommendedItems;
  List<ItemModel>? get cachedRecommendedItems => _cachedRecommendedItems;
  DiscoveryOptionsModel? _cachedDiscoveryOptions;
  final Map<DiscoveryQuery, List<ItemModel>> _cachedDiscoveryItems = {};

  Future<List<ItemModel>> getPopularItems({bool forceRefresh = false}) async {
    if (_cachedPopularItems != null && !forceRefresh) {
      return _cachedPopularItems!;
    }
    final items = await itemRepository.fetchPopularItems();
    _cachedPopularItems = items;
    return items;
  }

  Future<List<ItemModel>> getFeaturedItems({
    bool forceRefresh = false,
    int limit = 10,
  }) async {
    if (_cachedFeaturedItems != null && !forceRefresh) {
      return _cachedFeaturedItems!;
    }
    final items = await itemRepository.fetchFeaturedItems(limit: limit);
    _cachedFeaturedItems = items;
    return items;
  }

  Future<List<ItemModel>> getRecommendedItems({
    bool forceRefresh = false,
    int limit = 10,
    double? latitude,
    double? longitude,
    String? token,
  }) async {
    if (_cachedRecommendedItems != null && !forceRefresh) {
      return _cachedRecommendedItems!;
    }
    final items = await itemRepository.fetchRecommendedItems(
      limit: limit,
      latitude: latitude,
      longitude: longitude,
      token: token,
    );
    _cachedRecommendedItems = items;
    return items;
  }

  Future<DiscoveryOptionsModel> getDiscoveryOptions({
    bool forceRefresh = false,
  }) async {
    if (_cachedDiscoveryOptions != null && !forceRefresh) {
      return _cachedDiscoveryOptions!;
    }
    final options = await itemRepository.fetchDiscoveryOptions();
    _cachedDiscoveryOptions = options;
    return options;
  }

  Future<List<ItemModel>> getDiscoveryItems({
    DiscoveryQuery query = const DiscoveryQuery(),
    bool forceRefresh = false,
  }) async {
    final cached = _cachedDiscoveryItems[query];
    if (cached != null && !forceRefresh) return cached;
    final items = await itemRepository.fetchDiscoveryItems(query);
    _cachedDiscoveryItems[query] = items;
    return items;
  }

  Future<List<String>> getSearchSuggestions(
    String query, {
    int limit = 12,
  }) async {
    final repository = itemRepository;
    if (repository is RestItemRepository) {
      try {
        return await repository.fetchSearchSuggestions(query, limit: limit);
      } catch (_) {
        // Keep search suggestions working during staggered mobile/backend rollouts.
      }
    }

    final items = await repository.fetchDiscoveryItems(
      DiscoveryQuery(query: query.trim()),
    );
    final seen = <String>{};
    final suggestions = <String>[];
    void add(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty || !seen.add(normalized.toLowerCase())) return;
      suggestions.add(normalized);
    }

    for (final item in items) {
      add(item.title);
      add(item.category);
      add(item.displayLocation);
      if (suggestions.length >= limit) break;
    }
    return suggestions.take(limit).toList(growable: false);
  }

  Future<List<ItemModel>> searchListingItems(
    String query,
    String category,
  ) async {
    return itemRepository.searchItems(query: query, category: category).first;
  }

  Future<List<ItemModel>> getMyItems({
    required bool sold,
    required String token,
  }) => itemRepository.fetchMyItems(sold: sold, token: token);

  Future<ItemModel> updateItem({
    required String id,
    required String token,
    required Map<String, dynamic> updates,
  }) async {
    final updated = await itemRepository.updateItem(
      id: id,
      token: token,
      updates: updates,
    );
    invalidateCaches();
    return updated;
  }

  Future<Map<String, dynamic>> promoteItem({
    required String id,
    required String token,
  }) async {
    final result = await itemRepository.promoteItem(id: id, token: token);
    invalidateCaches();
    return result;
  }

  Future<ItemModel> toggleListingStatus({
    required String id,
    required bool publish,
    required String token,
  }) async {
    final updated = await itemRepository.toggleListingStatus(
      id: id,
      publish: publish,
      token: token,
    );
    invalidateCaches();
    return updated;
  }

  void invalidateCaches() {
    _cachedPopularItems = null;
    _cachedFeaturedItems = null;
    _cachedRecommendedItems = null;
    _cachedDiscoveryOptions = null;
    _cachedDiscoveryItems.clear();
    notifyListeners();
  }
}
