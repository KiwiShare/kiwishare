import 'package:flutter/material.dart';
import '../models/discovery_options_model.dart';
import '../models/item_model.dart';
import '../repositories/item_repository.dart';

class ListingProvider extends ChangeNotifier {
  final ItemRepository itemRepository;

  ListingProvider({required this.itemRepository});

  List<ItemModel>? _cachedPopularItems;
  List<ItemModel>? get cachedPopularItems => _cachedPopularItems;
  List<ItemModel>? _cachedRecommendedItems;
  List<ItemModel>? get cachedRecommendedItems => _cachedRecommendedItems;
  DiscoveryOptionsModel? _cachedDiscoveryOptions;
  final Map<DiscoveryQuery, List<ItemModel>> _cachedDiscoveryItems = {};
  final Map<String, ItemModel> _cachedItemDetails = {};

  Future<ItemModel> getItemById(
    String itemId, {
    bool forceRefresh = false,
  }) async {
    final cached = _cachedItemDetails[itemId];
    if (cached != null && !forceRefresh) return cached;
    final item = await itemRepository.fetchItemById(itemId);
    _cacheItem(item);
    return item;
  }

  Future<ItemModel> updateItem({
    required String itemId,
    required String token,
    required ItemUpdateDraft draft,
  }) async {
    final item = await itemRepository.updateItem(
      itemId: itemId,
      token: token,
      draft: draft,
    );
    _cacheItem(item);
    notifyListeners();
    return item;
  }

  Future<void> deleteItem({
    required String itemId,
    required String token,
  }) async {
    await itemRepository.deleteItem(itemId: itemId, token: token);
    _cachedItemDetails.remove(itemId);
    _cachedPopularItems = _cachedPopularItems
        ?.where((item) => item.id != itemId)
        .toList(growable: false);
    _cachedRecommendedItems = _cachedRecommendedItems
        ?.where((item) => item.id != itemId)
        .toList(growable: false);
    for (final query in _cachedDiscoveryItems.keys.toList()) {
      _cachedDiscoveryItems[query] = _cachedDiscoveryItems[query]!
          .where((item) => item.id != itemId)
          .toList(growable: false);
    }
    notifyListeners();
  }

  void seedItemDetail(ItemModel item) => _cacheItem(item);

  void _cacheItem(ItemModel item) {
    _cachedItemDetails[item.id] = item;
    _replaceItem(_cachedPopularItems, item);
    _replaceItem(_cachedRecommendedItems, item);
    for (final items in _cachedDiscoveryItems.values) {
      _replaceItem(items, item);
    }
  }

  void _replaceItem(List<ItemModel>? items, ItemModel replacement) {
    if (items == null) return;
    final index = items.indexWhere((item) => item.id == replacement.id);
    if (index >= 0) items[index] = replacement;
  }

  Future<List<ItemModel>> getPopularItems({bool forceRefresh = false}) async {
    if (_cachedPopularItems != null && !forceRefresh) {
      return _cachedPopularItems!;
    }
    final items = await itemRepository.fetchPopularItems();
    _cachedPopularItems = items;
    return items;
  }

  Future<List<ItemModel>> getRecommendedItems({
    bool forceRefresh = false,
    int limit = 10,
  }) async {
    if (_cachedRecommendedItems != null && !forceRefresh) {
      return _cachedRecommendedItems!;
    }
    final items = await itemRepository.fetchRecommendedItems(limit: limit);
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

  void invalidateCaches() {
    _cachedPopularItems = null;
    _cachedRecommendedItems = null;
    _cachedDiscoveryOptions = null;
    _cachedDiscoveryItems.clear();
    notifyListeners();
  }
}
