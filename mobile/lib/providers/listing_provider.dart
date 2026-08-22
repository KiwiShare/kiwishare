import 'package:flutter/material.dart';
import '../models/discovery_options_model.dart';
import '../models/item_model.dart';
import '../repositories/item_repository.dart';

class ListingProvider extends ChangeNotifier {
  final ItemRepository itemRepository;

  ListingProvider({required this.itemRepository});

  List<ItemModel>? _cachedPopularItems;
  List<ItemModel>? get cachedPopularItems => _cachedPopularItems;
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
}
