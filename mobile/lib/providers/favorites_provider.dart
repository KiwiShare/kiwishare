import 'package:flutter/material.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteIds = {};
  Set<String> get favoriteIds => _favoriteIds;

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
}
