import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../models/listing_query.dart';
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

  Future<List<ItemModel>> searchListingItems(ListingQuery query) =>
      itemRepository.fetchListings(query);

  Future<ItemModel> getItemById(String id) => itemRepository.fetchItemById(id);

  Future<List<ItemModel>> getMyItems({
    required bool sold,
    required String token,
  }) => itemRepository.fetchMyItems(sold: sold, token: token);
}
