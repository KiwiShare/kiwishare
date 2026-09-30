import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/item_model.dart';
import '../repositories/notification_preferences_repository.dart';
import '../repositories/watchlist_repository.dart';

enum WatchlistMutationResult { added, removed, unchanged, failed, superseded }

class WatchlistProvider extends ChangeNotifier {
  final WatchlistRepository _repository;
  final NotificationPreferencesRepository? preferencesRepository;
  String? _authToken;
  int _authGeneration = 0;
  int _mutationRevision = 0;
  int _pendingMutationCount = 0;
  int _loadSequence = 0;
  final Map<String, int> _itemMutationRevisions = <String, int>{};

  final Set<String> _watchedItemIds = <String>{};
  List<ItemModel> _watchlistItems = <ItemModel>[];
  bool _isLoading = false;
  String? _error;
  String? _nextCursor;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool? _watchlistPriceDropEnabled;
  bool? _watchlistNearbyCategoryEnabled;
  bool _isLoadingPreference = false;
  bool _isUpdatingPreference = false;
  String? _preferenceError;

  WatchlistProvider({
    WatchlistRepository? repository,
    this.preferencesRepository,
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
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  bool? get watchlistPriceDropEnabled => _watchlistPriceDropEnabled;
  bool? get watchlistPriceChangeEnabled => _watchlistPriceDropEnabled;
  bool? get watchlistNearbyCategoryEnabled => _watchlistNearbyCategoryEnabled;
  bool get isLoadingPreference => _isLoadingPreference;
  bool get isUpdatingPreference => _isUpdatingPreference;
  String? get preferenceError => _preferenceError;
  int get count => _watchedItemIds.length;
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  void updateAuthToken(String? token) {
    if (_authToken == token) return;
    _authToken = token;
    _authGeneration += 1;
    _mutationRevision += 1;
    _pendingMutationCount = 0;
    _loadSequence += 1;
    _watchedItemIds.clear();
    _watchlistItems.clear();
    _itemMutationRevisions.clear();
    _isLoading = false;
    _error = null;
    _nextCursor = null;
    _hasMore = false;
    _isLoadingMore = false;
    _watchlistPriceDropEnabled = null;
    _watchlistNearbyCategoryEnabled = null;
    _isLoadingPreference = false;
    _isUpdatingPreference = false;
    _preferenceError = null;

    if (token != null && token.isNotEmpty) {
      scheduleMicrotask(() {
        if (_authToken == token) {
          unawaited(loadWatchlist(forceRefresh: true));
          if (preferencesRepository != null) {
            unawaited(loadNotificationPreference());
          }
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
    _isLoadingMore = false;
    _error = null;
    notifyListeners();

    try {
      final page = await _fetchPage(token: requestToken);
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
        _watchlistItems = page.items;
        _nextCursor = page.nextCursor;
        _hasMore = page.hasMore;
        _watchedItemIds.clear();
        _watchedItemIds.addAll(fetchedIds);
        // Ensure all items in list are also in set
        for (final item in page.items) {
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
      _error = 'Could not load your Watchlist. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) return;
    final token = _authToken;
    final generation = _authGeneration;
    final loadSequence = _loadSequence;
    final cursor = _nextCursor!;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _fetchPage(token: token, cursor: cursor);
      if (!_isCurrentLoad(token, generation, loadSequence) ||
          _nextCursor != cursor) {
        return;
      }
      final existing = _watchlistItems.map((item) => item.id).toSet();
      _watchlistItems.addAll(page.items.where((item) => existing.add(item.id)));
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _error = null;
    } catch (_) {
      if (_isCurrentLoad(token, generation, loadSequence)) {
        _error = 'Could not load more saved items. Please try again.';
      }
    } finally {
      if (_isCurrentLoad(token, generation, loadSequence)) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<WatchlistPage> _fetchPage({String? token, String? cursor}) async {
    final repository = _repository;
    if (repository is PaginatedWatchlistRepository) {
      return (repository as PaginatedWatchlistRepository).fetchWatchlistPage(
        token: token,
        cursor: cursor,
      );
    }
    if (cursor != null) return const WatchlistPage(items: []);
    return WatchlistPage(items: await repository.fetchWatchlist(token: token));
  }

  Future<void> loadNotificationPreference() async {
    final token = _authToken;
    final generation = _authGeneration;
    final repository = preferencesRepository;
    if (token == null || token.isEmpty || repository == null) return;
    _isLoadingPreference = true;
    _preferenceError = null;
    notifyListeners();
    try {
      final extended = repository is ExtendedNotificationPreferencesRepository
          ? repository as ExtendedNotificationPreferencesRepository
          : null;
      if (extended != null) {
        final preferences = await extended.fetchWatchlistPreferences(
          token: token,
        );
        if (!_isCurrentSession(token, generation)) return;
        _watchlistPriceDropEnabled = preferences.priceChanges;
        _watchlistNearbyCategoryEnabled = preferences.nearbyCategory;
      } else {
        final value = await repository.fetchWatchlistPriceDrop(token: token);
        if (!_isCurrentSession(token, generation)) return;
        _watchlistPriceDropEnabled = value;
        _watchlistNearbyCategoryEnabled ??= false;
      }
    } catch (_) {
      if (_isCurrentSession(token, generation)) {
        _preferenceError = 'Could not load watchlist alerts.';
      }
    } finally {
      if (_isCurrentSession(token, generation)) {
        _isLoadingPreference = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateNotificationPreference(bool enabled) {
    return updatePriceChangePreference(enabled);
  }

  Future<bool> updatePriceChangePreference(bool enabled) async {
    final token = _authToken;
    final generation = _authGeneration;
    final repository = preferencesRepository;
    if (token == null ||
        token.isEmpty ||
        repository == null ||
        _isUpdatingPreference) {
      return false;
    }
    final previous = _watchlistPriceDropEnabled;
    _watchlistPriceDropEnabled = enabled;
    _isUpdatingPreference = true;
    _preferenceError = null;
    notifyListeners();
    try {
      final extended = repository is ExtendedNotificationPreferencesRepository
          ? repository as ExtendedNotificationPreferencesRepository
          : null;
      if (extended != null) {
        final saved = await extended.updateWatchlistPreferences(
          token: token,
          priceChanges: enabled,
        );
        if (!_isCurrentSession(token, generation)) return false;
        _watchlistPriceDropEnabled = saved.priceChanges;
        _watchlistNearbyCategoryEnabled = saved.nearbyCategory;
      } else {
        final saved = await repository.updateWatchlistPriceDrop(
          token: token,
          enabled: enabled,
        );
        if (!_isCurrentSession(token, generation)) return false;
        if (!saved) throw const NotificationPreferencesException();
      }
      return true;
    } catch (_) {
      if (_isCurrentSession(token, generation)) {
        _watchlistPriceDropEnabled = previous;
        _preferenceError =
            'Could not update price-change alerts. Please try again.';
      }
      return false;
    } finally {
      if (_isCurrentSession(token, generation)) {
        _isUpdatingPreference = false;
        notifyListeners();
      }
    }
  }

  Future<bool> updateNearbyCategoryPreference(bool enabled) async {
    final token = _authToken;
    final generation = _authGeneration;
    final repository = preferencesRepository;
    final extended = repository is ExtendedNotificationPreferencesRepository
        ? repository as ExtendedNotificationPreferencesRepository
        : null;
    if (token == null ||
        token.isEmpty ||
        extended == null ||
        _isUpdatingPreference) {
      return false;
    }

    final previous = _watchlistNearbyCategoryEnabled;
    _watchlistNearbyCategoryEnabled = enabled;
    _isUpdatingPreference = true;
    _preferenceError = null;
    notifyListeners();
    try {
      final saved = await extended.updateWatchlistPreferences(
        token: token,
        nearbyCategory: enabled,
      );
      if (!_isCurrentSession(token, generation)) return false;
      _watchlistPriceDropEnabled = saved.priceChanges;
      _watchlistNearbyCategoryEnabled = saved.nearbyCategory;
      return true;
    } catch (_) {
      if (_isCurrentSession(token, generation)) {
        _watchlistNearbyCategoryEnabled = previous;
        _preferenceError =
            'Could not update nearby-category alerts. Please try again.';
      }
      return false;
    } finally {
      if (_isCurrentSession(token, generation)) {
        _isUpdatingPreference = false;
        notifyListeners();
      }
    }
  }

  Future<WatchlistMutationResult> toggleWatch(
    String itemId, {
    ItemModel? item,
  }) async {
    if (isWatched(itemId)) {
      return removeFromWatchlist(itemId);
    }
    return addToWatchlist(itemId, item: item);
  }

  Future<WatchlistMutationResult> toggleFavorite(
    String itemId, [
    ItemModel? item,
  ]) => toggleWatch(itemId, item: item);

  Future<WatchlistMutationResult> addToWatchlist(
    String itemId, {
    ItemModel? item,
  }) async {
    if (_watchedItemIds.contains(itemId)) {
      return WatchlistMutationResult.unchanged;
    }
    final requestToken = _authToken;
    final requestGeneration = _authGeneration;
    final itemRevision = _nextItemMutationRevision(itemId);
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
      if (!_isCurrentSession(requestToken, requestGeneration)) {
        return WatchlistMutationResult.superseded;
      }

      if (!success) _rollbackAdd(itemId, itemRevision);
      if (!success) return WatchlistMutationResult.failed;
      if (_itemMutationRevisions[itemId] != itemRevision ||
          !_watchedItemIds.contains(itemId)) {
        return WatchlistMutationResult.superseded;
      }
      return WatchlistMutationResult.added;
    } catch (_) {
      if (!_isCurrentSession(requestToken, requestGeneration)) {
        return WatchlistMutationResult.superseded;
      }
      _rollbackAdd(itemId, itemRevision);
      return WatchlistMutationResult.failed;
    } finally {
      _finishMutation(requestToken, requestGeneration);
    }
  }

  Future<WatchlistMutationResult> removeFromWatchlist(String itemId) async {
    if (!_watchedItemIds.contains(itemId)) {
      return WatchlistMutationResult.unchanged;
    }
    final requestToken = _authToken;
    final requestGeneration = _authGeneration;
    final itemRevision = _nextItemMutationRevision(itemId);
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
      if (!_isCurrentSession(requestToken, requestGeneration)) {
        return WatchlistMutationResult.superseded;
      }

      if (!success) {
        _rollbackRemove(itemId, itemRevision, removedItem, removedIndex);
      }
      if (!success) return WatchlistMutationResult.failed;
      if (_itemMutationRevisions[itemId] != itemRevision ||
          _watchedItemIds.contains(itemId)) {
        return WatchlistMutationResult.superseded;
      }
      return WatchlistMutationResult.removed;
    } catch (_) {
      if (!_isCurrentSession(requestToken, requestGeneration)) {
        return WatchlistMutationResult.superseded;
      }
      _rollbackRemove(itemId, itemRevision, removedItem, removedIndex);
      return WatchlistMutationResult.failed;
    } finally {
      _finishMutation(requestToken, requestGeneration);
    }
  }

  int _nextItemMutationRevision(String itemId) {
    final revision = (_itemMutationRevisions[itemId] ?? 0) + 1;
    _itemMutationRevisions[itemId] = revision;
    return revision;
  }

  void _rollbackAdd(String itemId, int itemRevision) {
    if (_itemMutationRevisions[itemId] != itemRevision) return;
    _watchedItemIds.remove(itemId);
    _watchlistItems.removeWhere((item) => item.id == itemId);
    notifyListeners();
  }

  void _rollbackRemove(
    String itemId,
    int itemRevision,
    ItemModel? removedItem,
    int removedIndex,
  ) {
    if (_itemMutationRevisions[itemId] != itemRevision) return;
    _watchedItemIds.add(itemId);
    if (removedItem != null &&
        !_watchlistItems.any((item) => item.id == itemId)) {
      _watchlistItems.insert(
        removedIndex.clamp(0, _watchlistItems.length),
        removedItem,
      );
    }
    notifyListeners();
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
