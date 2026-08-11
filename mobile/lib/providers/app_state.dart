import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/item_model.dart';
import '../repositories/user_repository.dart';
import '../repositories/item_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';

class AppState extends ChangeNotifier {
  final UserRepository userRepository;
  final ItemRepository itemRepository;

  AppState({required this.userRepository, required this.itemRepository}) {
    _loadSession();
  }

  // Authentication State
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool _isLoggingIn = false;
  bool get isLoggingIn => _isLoggingIn;

  String? _jwtToken;
  String? get jwtToken => _jwtToken;

  // Google Sign-In instance configuration
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _jwtToken = prefs.getString('jwt_token');
      final userJson = prefs.getString('current_user');
      if (_jwtToken != null && userJson != null) {
        _currentUser = UserModel.fromJson(
          jsonDecode(userJson) as Map<String, dynamic>,
        );
        _isLoggedIn = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading auth session: $e');
    }
  }

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
  Future<void> sendOtp(String email) async {
    _isLoggingIn = true;
    notifyListeners();
    try {
      await userRepository.sendOtp(email);
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> verifyOtp(String email, String code) async {
    _isLoggingIn = true;
    notifyListeners();
    try {
      final result = await userRepository.verifyOtp(email, code);
      final token = result['token'] as String;
      final user = result['user'] as UserModel;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      _jwtToken = token;
      _currentUser = user;
      _isLoggedIn = true;
    } catch (e) {
      _currentUser = null;
      _isLoggedIn = false;
      rethrow;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> loginWithGoogle() async {
    _isLoggingIn = true;
    notifyListeners();
    try {
      // 1. Trigger Google Sign-in prompt on native platform
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the login flow
        _isLoggingIn = false;
        notifyListeners();
        return;
      }

      // 2. Fetch the authentication credentials (idToken)
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google Sign-in failed: Could not retrieve ID Token.');
      }

      // 3. Authenticate with backend and fetch JWT + Profile
      final result = await userRepository.loginWithGoogle(idToken);
      final token = result['token'] as String;
      final user = result['user'] as UserModel;

      // 4. Save session locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('current_user', jsonEncode(user.toJson()));

      _jwtToken = token;
      _currentUser = user;
      _isLoggedIn = true;
    } catch (e) {
      debugPrint('Google Login Provider Error: $e');
      _currentUser = null;
      _isLoggedIn = false;
      rethrow;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _currentUser = null;
    _jwtToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('current_user');

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

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
