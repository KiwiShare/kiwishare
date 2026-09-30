import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchProvider extends ChangeNotifier {
  static const _recentSearchesKey = 'kiwishare_recent_searches';
  static const _maxRecentSearches = 10;

  String _selectedCategory = 'All NZ';
  String get selectedCategory => _selectedCategory;

  final List<String> _recentSearches = [];
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  bool _recentLoaded = false;

  void setCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> loadRecentSearches() async {
    if (_recentLoaded) return;
    _recentLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_recentSearchesKey) ?? const <String>[];
    _recentSearches
      ..clear()
      ..addAll(
        saved
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .take(_maxRecentSearches),
      );
    notifyListeners();
  }

  Future<void> addRecentSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return;

    _recentSearches.removeWhere(
      (value) => value.toLowerCase() == normalized.toLowerCase(),
    );
    _recentSearches.insert(0, normalized);
    if (_recentSearches.length > _maxRecentSearches) {
      _recentSearches.removeRange(_maxRecentSearches, _recentSearches.length);
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> removeRecentSearch(String query) async {
    _recentSearches.removeWhere(
      (value) => value.toLowerCase() == query.trim().toLowerCase(),
    );
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> clearRecentSearches() async {
    if (_recentSearches.isEmpty) return;
    _recentSearches.clear();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
  }
}
