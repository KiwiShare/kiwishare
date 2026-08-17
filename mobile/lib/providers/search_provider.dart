import 'package:flutter/material.dart';

class SearchProvider extends ChangeNotifier {
  String _selectedCategory = 'All NZ';
  String get selectedCategory => _selectedCategory;

  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners();
    }
  }
}
