import 'package:flutter/material.dart';
import '../models/listing_query.dart';

class SearchProvider extends ChangeNotifier {
  static const categories = ['Camping', 'Plants', 'Furniture', 'Transport'];
  static const locations = [
    'All NZ',
    'Auckland',
    'Wellington',
    'Hamilton',
    'Christchurch',
    'Dunedin',
  ];

  String _query = '';
  String? _selectedCategory;
  String _selectedLocation = 'All NZ';
  ListingSortOrder _sortOrder = ListingSortOrder.popular;
  bool _showSavedOnly = false;
  double? _latitude;
  double? _longitude;

  String get query => _query;
  String? get selectedCategory => _selectedCategory;
  String get selectedLocation => _selectedLocation;
  ListingSortOrder get sortOrder => _sortOrder;
  bool get showSavedOnly => _showSavedOnly;
  bool get isNearby => _latitude != null && _longitude != null;

  ListingQuery get listingQuery => ListingQuery(
    query: _query,
    category: _selectedCategory,
    location: _selectedLocation == 'All NZ' || isNearby
        ? null
        : _selectedLocation,
    sortOrder: isNearby && _sortOrder == ListingSortOrder.popular
        ? ListingSortOrder.nearest
        : _sortOrder,
    latitude: _latitude,
    longitude: _longitude,
  );

  void setQuery(String query) {
    final nextQuery = query.trim();
    if (_query == nextQuery) return;
    _query = nextQuery;
    notifyListeners();
  }

  void toggleCategory(String category) {
    _selectedCategory = _selectedCategory == category ? null : category;
    notifyListeners();
  }

  void setCategory(String? category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
  }

  void setLocation(String location) {
    if (_selectedLocation == location && !isNearby) return;
    _selectedLocation = location;
    _latitude = null;
    _longitude = null;
    if (_sortOrder == ListingSortOrder.nearest) {
      _sortOrder = ListingSortOrder.popular;
    }
    notifyListeners();
  }

  void setNearby({required double latitude, required double longitude}) {
    _selectedLocation = 'Near me';
    _latitude = latitude;
    _longitude = longitude;
    _sortOrder = ListingSortOrder.nearest;
    notifyListeners();
  }

  void setSortOrder(ListingSortOrder sortOrder) {
    if (_sortOrder == sortOrder) return;
    _sortOrder = sortOrder;
    notifyListeners();
  }

  void toggleSavedOnly() {
    _showSavedOnly = !_showSavedOnly;
    notifyListeners();
  }

  void resetFilters() {
    _selectedCategory = null;
    _selectedLocation = 'All NZ';
    _sortOrder = ListingSortOrder.popular;
    _showSavedOnly = false;
    _latitude = null;
    _longitude = null;
    notifyListeners();
  }
}
