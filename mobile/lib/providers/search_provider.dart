import 'package:flutter/material.dart';

enum ProductSort { recommended, priceLowToHigh, priceHighToLow }

enum ProductViewMode { list, map }

extension ProductSortLabel on ProductSort {
  String get label => switch (this) {
    ProductSort.recommended => 'Recommended',
    ProductSort.priceLowToHigh => 'Price: low to high',
    ProductSort.priceHighToLow => 'Price: high to low',
  };
}

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

  String _selectedCategory = 'All';
  String _selectedLocation = 'All NZ';
  ProductSort _selectedSort = ProductSort.recommended;
  bool _sustainableOnly = false;
  bool _isNearYou = false;
  String _query = '';
  double? _minimumPrice;
  double? _maximumPrice;
  double? _userLatitude;
  double? _userLongitude;
  ProductViewMode _viewMode = ProductViewMode.list;
  String? _previewItemId;

  String get selectedCategory => _selectedCategory;
  String get selectedLocation => _selectedLocation;
  ProductSort get selectedSort => _selectedSort;
  bool get sustainableOnly => _sustainableOnly;
  bool get isNearYou => _isNearYou;
  String get query => _query;
  double? get minimumPrice => _minimumPrice;
  double? get maximumPrice => _maximumPrice;
  double? get userLatitude => _userLatitude;
  double? get userLongitude => _userLongitude;
  ProductViewMode get viewMode => _viewMode;
  String? get previewItemId => _previewItemId;

  bool get hasActiveFilters =>
      _selectedCategory != 'All' ||
      _selectedLocation != 'All NZ' ||
      _selectedSort != ProductSort.recommended ||
      _sustainableOnly ||
      _minimumPrice != null ||
      _maximumPrice != null;

  void setQuery(String query) {
    final normalized = query.trim();
    if (_query == normalized) return;
    _query = normalized;
    notifyListeners();
  }

  void toggleCategory(String category) {
    _selectedCategory = _selectedCategory == category ? 'All' : category;
    notifyListeners();
  }

  void setCategory(String category) {
    final normalized = category == 'All NZ' ? 'All' : category;
    if (_selectedCategory == normalized) return;
    _selectedCategory = normalized;
    notifyListeners();
  }

  void setLocation(
    String location, {
    bool nearYou = false,
    double? latitude,
    double? longitude,
  }) {
    if (_selectedLocation == location &&
        _isNearYou == nearYou &&
        _userLatitude == latitude &&
        _userLongitude == longitude) {
      return;
    }
    _selectedLocation = location;
    _isNearYou = nearYou;
    _userLatitude = latitude;
    _userLongitude = longitude;
    notifyListeners();
  }

  void setSort(ProductSort sort) {
    if (_selectedSort == sort) return;
    _selectedSort = sort;
    notifyListeners();
  }

  void toggleSustainableOnly() {
    _sustainableOnly = !_sustainableOnly;
    notifyListeners();
  }

  void setPriceRange({double? minimum, double? maximum}) {
    _minimumPrice = minimum;
    _maximumPrice = maximum;
    notifyListeners();
  }

  void setViewMode(ProductViewMode mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
  }

  void selectPreview(String? itemId) {
    if (_previewItemId == itemId) return;
    _previewItemId = itemId;
    notifyListeners();
  }

  void resetFilters() {
    _selectedCategory = 'All';
    _selectedLocation = 'All NZ';
    _selectedSort = ProductSort.recommended;
    _sustainableOnly = false;
    _isNearYou = false;
    _minimumPrice = null;
    _maximumPrice = null;
    notifyListeners();
  }
}
