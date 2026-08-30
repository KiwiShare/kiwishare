import 'package:flutter/foundation.dart';
import '../models/item_model.dart';
import '../repositories/watchlist_repository.dart';

class WatchlistProvider extends ChangeNotifier {
  final WatchlistRepository _repository;
  String? _authToken;
  String? _userId;

  final Set<String> _watchedItemIds = <String>{};
  List<ItemModel> _watchlistItems = <ItemModel>[];
  bool _isLoading = false;
  String? _error;

  WatchlistProvider({
    WatchlistRepository? repository,
    String? initialToken,
    String? initialUserId,
    Set<String>? initialWatchedIds,
  }) : _repository = repository ?? RestWatchlistRepository(),
       _authToken = initialToken,
       _userId = initialUserId {
    if (initialWatchedIds != null) {
      _watchedItemIds.addAll(initialWatchedIds);
    }
  }

  Set<String> get watchedItemIds => Set.unmodifiable(_watchedItemIds);
  Set<String> get favoriteIds => _watchedItemIds; // Compatibility alias
  List<ItemModel> get watchlistItems => List.unmodifiable(_watchlistItems);
  List<ItemModel> get items => _watchlistItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get count => _watchedItemIds.length;

  void updateAuth(String? token, {String? userId}) {
    if (_authToken == token && _userId == userId) return;
    _authToken = token;
    _userId = userId;
    if (_authToken != null || _userId != null) {
      loadWatchlist(forceRefresh: true);
    } else {
      _watchedItemIds.clear();
      _watchlistItems.clear();
      notifyListeners();
    }
  }

  void updateAuthToken(String? token) {
    updateAuth(token, userId: _userId);
  }

  bool isWatched(String itemId) => _watchedItemIds.contains(itemId);
  bool isFavorite(String itemId) => isWatched(itemId); // Compatibility alias

  Future<void> loadWatchlist({bool forceRefresh = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetchedItems = await _repository.fetchWatchlist(
        token: _authToken,
        userId: _userId,
      );
      final fetchedIds = await _repository.fetchWatchedItemIds(
        token: _authToken,
        userId: _userId,
      );

      _watchlistItems = fetchedItems;
      _watchedItemIds.clear();
      _watchedItemIds.addAll(fetchedIds);
      // Ensure all items in list are also in set
      for (final item in fetchedItems) {
        _watchedItemIds.add(item.id);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load watchlist: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleWatch(String itemId, {ItemModel? item}) async {
    if (isWatched(itemId)) {
      await removeFromWatchlist(itemId);
    } else {
      await addToWatchlist(itemId, item: item);
    }
  }

  void toggleFavorite(String itemId, [ItemModel? item]) {
    toggleWatch(itemId, item: item);
  }

  Future<void> addToWatchlist(String itemId, {ItemModel? item}) async {
    if (_watchedItemIds.contains(itemId)) return;

    // Optimistic UI update
    _watchedItemIds.add(itemId);
    if (item != null && !_watchlistItems.any((i) => i.id == itemId)) {
      _watchlistItems.insert(0, item);
    }
    notifyListeners();

    final success = await _repository.addToWatchlist(
      itemId,
      token: _authToken,
      userId: _userId,
    );
    if (!success && (_authToken != null || _userId != null)) {
      // Revert if API failed when user is logged in
      _watchedItemIds.remove(itemId);
      _watchlistItems.removeWhere((i) => i.id == itemId);
      notifyListeners();
    }
  }

  Future<void> removeFromWatchlist(String itemId) async {
    if (!_watchedItemIds.contains(itemId)) return;

    // Optimistic UI update
    final removedIndex = _watchlistItems.indexWhere((i) => i.id == itemId);
    ItemModel? removedItem;
    if (removedIndex != -1) {
      removedItem = _watchlistItems.removeAt(removedIndex);
    }
    _watchedItemIds.remove(itemId);
    notifyListeners();

    final success = await _repository.removeFromWatchlist(
      itemId,
      token: _authToken,
      userId: _userId,
    );
    if (!success && (_authToken != null || _userId != null)) {
      // Revert on API failure
      _watchedItemIds.add(itemId);
      if (removedItem != null) {
        _watchlistItems.insert(
          removedIndex.clamp(0, _watchlistItems.length),
          removedItem,
        );
      }
      notifyListeners();
    }
  }
}
