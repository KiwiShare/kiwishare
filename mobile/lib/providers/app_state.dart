import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/item_model.dart';
import '../repositories/user_repository.dart';
import '../repositories/item_repository.dart';

class AppState extends ChangeNotifier {
  final UserRepository userRepository;
  final ItemRepository itemRepository;

  AppState({required this.userRepository, required this.itemRepository});

  // Authentication State
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool _isLoggingIn = false;
  bool get isLoggingIn => _isLoggingIn;

  // Navigation State
  int _activeTab = 0;
  int get activeTab => _activeTab;

  // Favorites State
  final Set<String> _favoriteIds = {};
  Set<String> get favoriteIds => _favoriteIds;

  // Search Filters
  String _selectedCategory = 'All NZ';
  String get selectedCategory => _selectedCategory;

  // Cached Popular Items
  List<ItemModel>? _cachedPopularItems;
  List<ItemModel>? get cachedPopularItems => _cachedPopularItems;

  void setActiveTab(int tabIndex) {
    if (_activeTab != tabIndex) {
      _activeTab = tabIndex;
      notifyListeners();
    }
  }

  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }

  bool isFavorite(String itemId) {
    return _favoriteIds.contains(itemId);
  }

  void toggleFavorite(String itemId) {
    if (_favoriteIds.contains(itemId)) {
      _favoriteIds.remove(itemId);
    } else {
      _favoriteIds.add(itemId);
    }
    notifyListeners();
  }

  // Auth Operations
  Future<void> login() async {
    _isLoggingIn = true;
    notifyListeners();

    try {
      // Fetch user profile from repo (simulates delay)
      _currentUser = await userRepository.fetchCurrentUser();
      _isLoggedIn = true;
    } catch (e) {
      _currentUser = null;
      _isLoggedIn = false;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  void logout() {
    _isLoggedIn = false;
    _currentUser = null;
    notifyListeners();
  }

  // Listing Data Operations
  Future<List<ItemModel>> getPopularItems({bool forceRefresh = false}) async {
    if (_cachedPopularItems != null && !forceRefresh) {
      return _cachedPopularItems!;
    }
    final items = await itemRepository.fetchPopularItems();
    _cachedPopularItems = items;
    return items;
  }

  Future<List<ItemModel>> searchListingItems(String query) async {
    // Read the first emission from the mock stream interface
    return itemRepository
        .searchItems(query: query, category: _selectedCategory)
        .first;
  }
}
