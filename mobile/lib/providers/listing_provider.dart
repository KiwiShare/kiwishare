import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../repositories/item_repository.dart';

class ListingProvider extends ChangeNotifier {
  final ItemRepository itemRepository;

  ListingProvider({required this.itemRepository});

  List<ItemModel>? _cachedPopularItems;
  List<ItemModel>? get cachedPopularItems => _cachedPopularItems;

  Future<List<ItemModel>> getPopularItems({bool forceRefresh = false}) async {
    if (_cachedPopularItems != null && !forceRefresh) {
      return _cachedPopularItems!;
    }
    final items = await itemRepository.fetchPopularItems();
    _cachedPopularItems = items;
    return items;
  }

  Future<ItemModel> getItemById(String id) => itemRepository.fetchItemById(id);

  Future<ItemModel> updateItem({
    required ItemModel item,
    required String token,
  }) async {
    final updated = await itemRepository.updateItem(item: item, token: token);
    final cachedItems = _cachedPopularItems;
    if (cachedItems != null) {
      final index = cachedItems.indexWhere(
        (candidate) => candidate.id == item.id,
      );
      if (index != -1) cachedItems[index] = updated;
    }
    notifyListeners();
    return updated;
  }

  Future<void> deleteItem({required String id, required String token}) async {
    await itemRepository.deleteItem(id: id, token: token);
    _cachedPopularItems?.removeWhere((item) => item.id == id);
    notifyListeners();
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
