import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/item_model.dart';
import '../repositories/watchlist_repository.dart';

class WatchlistProvider extends ChangeNotifier {
  final WatchlistRepository _repository;
  String? _authToken;
  int _authGeneration = 0;
  int _mutationRevision = 0;
  int _pendingMutationCount = 0;
  int _loadSequence = 0;

  final Set<String> _watchedItemIds = <String>{};
  List<ItemModel> _watchlistItems = <ItemModel>[];
  bool _isLoading = false;
  String? _error;

  WatchlistProvider({
    WatchlistRepository? repository,
    String? initialToken,
    Set<String>? initialWatchedIds,
  }) : _repository = repository ?? RestWatchlistRepository(),
       _authToken = initialToken {
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

  void updateAuthToken(String? token) {
    if (_authToken == token) return;
    _authToken = token;
    _authGeneration += 1;
    _mutationRevision += 1;
    _pendingMutationCount = 0;
    _loadSequence += 1;
    _watchedItemIds.clear();
    _watchlistItems.clear();
    _isLoading = false;
    _error = null;

    if (token != null && token.isNotEmpty) {
      scheduleMicrotask(() {
        if (_authToken == token) {
          unawaited(loadWatchlist(forceRefresh: true));
        }
      });
    } else {
      scheduleMicrotask(notifyListeners);
    }
  }

  bool isWatched(String itemId) => _watchedItemIds.contains(itemId);
  bool isFavorite(String itemId) => isWatched(itemId); // Compatibility alias

  Future<void> loadWatchlist({bool forceRefresh = false}) async {
    final requestLoadSequence = ++_loadSequence;
    final requestToken = _authToken;
    final requestGeneration = _authGeneration;
    final requestMutationRevision = _mutationRevision;
    final requestHadPendingMutation = _pendingMutationCount > 0;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetchedItems = await _repository.fetchWatchlist(
        token: requestToken,
      );
      final fetchedIds = await _repository.fetchWatchedItemIds(
        token: requestToken,
      );

      // A login, logout, or account switch may finish while this request is in
      // flight. Never let the previous account overwrite the current state.
      if (!_isCurrentLoad(
        requestToken,
        requestGeneration,
        requestLoadSequence,
      )) {
        return;
      }

      final mutationChangedWhileLoading =
          requestHadPendingMutation ||
          _pendingMutationCount > 0 ||
          requestMutationRevision != _mutationRevision;
      if (!mutationChangedWhileLoading) {
        _watchlistItems = fetchedItems;
        _watchedItemIds.clear();
        _watchedItemIds.addAll(fetchedIds);
        // Ensure all items in list are also in set
        for (final item in fetchedItems) {
          _watchedItemIds.add(item.id);
        }
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (!_isCurrentLoad(
        requestToken,
        requestGeneration,
        requestLoadSequence,
      )) {
        return;
      }
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
    final requestToken = _authToken;
    final requestGeneration = _authGeneration;
    _beginMutation();

    // Optimistic UI update
    _watchedItemIds.add(itemId);
    if (item != null && !_watchlistItems.any((i) => i.id == itemId)) {
      _watchlistItems.insert(0, item);
    }
    notifyListeners();

    try {
      final success = await _repository.addToWatchlist(
        itemId,
        token: requestToken,
      );
      if (!_isCurrentSession(requestToken, requestGeneration)) return;

      if (!success && requestToken != null) {
        // Revert if API failed when user is logged in
        _watchedItemIds.remove(itemId);
        _watchlistItems.removeWhere((i) => i.id == itemId);
        notifyListeners();
      }
    } finally {
      _finishMutation(requestToken, requestGeneration);
    }
  }

  Future<void> removeFromWatchlist(String itemId) async {
    if (!_watchedItemIds.contains(itemId)) return;
    final requestToken = _authToken;
    final requestGeneration = _authGeneration;
    _beginMutation();

    // Optimistic UI update
    final removedIndex = _watchlistItems.indexWhere((i) => i.id == itemId);
    ItemModel? removedItem;
    if (removedIndex != -1) {
      removedItem = _watchlistItems.removeAt(removedIndex);
    }
    _watchedItemIds.remove(itemId);
    notifyListeners();

    try {
      final success = await _repository.removeFromWatchlist(
        itemId,
        token: requestToken,
      );
      if (!_isCurrentSession(requestToken, requestGeneration)) return;

      if (!success && requestToken != null) {
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
    } finally {
      _finishMutation(requestToken, requestGeneration);
    }
  }

  void _beginMutation() {
    _pendingMutationCount += 1;
    _mutationRevision += 1;
  }

  void _finishMutation(String? token, int generation) {
    if (!_isCurrentSession(token, generation)) return;
    if (_pendingMutationCount > 0) _pendingMutationCount -= 1;
    _mutationRevision += 1;
  }

  bool _isCurrentSession(String? token, int generation) =>
      _authToken == token && _authGeneration == generation;

  bool _isCurrentLoad(String? token, int generation, int loadSequence) =>
      _isCurrentSession(token, generation) && _loadSequence == loadSequence;
}
