import 'package:flutter/material.dart';

import '../models/item_model.dart';

enum HomeProductSort { recommended, priceLowToHigh, priceHighToLow }

enum HomeProductView { grid, map }

enum HomePriceRange { any, under25, from25To50, from50To100, over100, custom }

extension HomeProductSortLabel on HomeProductSort {
  String get label => switch (this) {
    HomeProductSort.recommended => 'Recommended',
    HomeProductSort.priceLowToHigh => 'Price: low to high',
    HomeProductSort.priceHighToLow => 'Price: high to low',
  };
}

extension HomePriceRangeLabel on HomePriceRange {
  String get label => switch (this) {
    HomePriceRange.any => 'Any price',
    HomePriceRange.under25 => r'Up to $25',
    HomePriceRange.from25To50 => r'$25–$50',
    HomePriceRange.from50To100 => r'$50–$100',
    HomePriceRange.over100 => r'$100+',
    HomePriceRange.custom => 'Custom',
  };
}

class HomeDiscoveryProvider extends ChangeNotifier {
  static const categories = ['Camping', 'Plants', 'Furniture', 'Transport'];

  static const locations = [
    'All NZ',
    'Auckland',
    'Wellington',
    'Hamilton',
    'Christchurch',
    'Dunedin',
  ];

  static const locationCoordinates = <String, (double, double)>{
    'Auckland': (-36.8485, 174.7633),
    'Wellington': (-41.2866, 174.7756),
    'Hamilton': (-37.7870, 175.2793),
    'Christchurch': (-43.5321, 172.6362),
    'Dunedin': (-45.8788, 170.5028),
  };

  String _query = '';
  String _selectedCategory = 'All';
  String _selectedLocation = 'All NZ';
  HomeProductSort _selectedSort = HomeProductSort.recommended;
  HomePriceRange _selectedPriceRange = HomePriceRange.any;
  bool _sustainableOnly = false;
  bool _isNearYou = false;
  double? _minimumPrice;
  double? _maximumPrice;
  double? _userLatitude;
  double? _userLongitude;
  HomeProductView _view = HomeProductView.grid;
  String? _previewItemId;

  String get query => _query;
  String get selectedCategory => _selectedCategory;
  String get selectedLocation => _selectedLocation;
  HomeProductSort get selectedSort => _selectedSort;
  HomePriceRange get selectedPriceRange => _selectedPriceRange;
  bool get sustainableOnly => _sustainableOnly;
  bool get isNearYou => _isNearYou;
  double? get minimumPrice => _minimumPrice;
  double? get maximumPrice => _maximumPrice;
  double? get userLatitude => _userLatitude;
  double? get userLongitude => _userLongitude;
  HomeProductView get view => _view;
  String? get previewItemId => _previewItemId;

  int get activeFilterCount => [
    _selectedPriceRange != HomePriceRange.any,
    _sustainableOnly,
    _selectedSort != HomeProductSort.recommended,
  ].where((active) => active).length;

  void setQuery(String value) {
    final normalized = value.trimLeft();
    if (_query == normalized) return;
    _query = normalized;
    _previewItemId = null;
    notifyListeners();
  }

  void toggleCategory(String category) {
    final next = _selectedCategory == category ? 'All' : category;
    if (_selectedCategory == next) return;
    _selectedCategory = next;
    _previewItemId = null;
    notifyListeners();
  }

  void setLocation(
    String location, {
    bool nearYou = false,
    double? latitude,
    double? longitude,
  }) {
    final manualCoordinates = locationCoordinates[location];
    final nextLatitude = location == 'All NZ'
        ? null
        : latitude ?? manualCoordinates?.$1;
    final nextLongitude = location == 'All NZ'
        ? null
        : longitude ?? manualCoordinates?.$2;
    if (_selectedLocation == location &&
        _isNearYou == nearYou &&
        _userLatitude == nextLatitude &&
        _userLongitude == nextLongitude) {
      return;
    }
    _selectedLocation = location;
    _isNearYou = nearYou;
    _userLatitude = nextLatitude;
    _userLongitude = nextLongitude;
    _previewItemId = null;
    notifyListeners();
  }

  void setSort(HomeProductSort sort) {
    if (_selectedSort == sort) return;
    _selectedSort = sort;
    notifyListeners();
  }

  void setPriceRange(HomePriceRange range) {
    if (range == HomePriceRange.custom) return;
    _selectedPriceRange = range;
    switch (range) {
      case HomePriceRange.any:
        _minimumPrice = null;
        _maximumPrice = null;
      case HomePriceRange.under25:
        _minimumPrice = null;
        _maximumPrice = 25;
      case HomePriceRange.from25To50:
        _minimumPrice = 25;
        _maximumPrice = 50;
      case HomePriceRange.from50To100:
        _minimumPrice = 50;
        _maximumPrice = 100;
      case HomePriceRange.over100:
        _minimumPrice = 100;
        _maximumPrice = null;
      case HomePriceRange.custom:
        break;
    }
    _previewItemId = null;
    notifyListeners();
  }

  void setCustomPriceRange({double? minimum, double? maximum}) {
    if (_selectedPriceRange == HomePriceRange.custom &&
        _minimumPrice == minimum &&
        _maximumPrice == maximum) {
      return;
    }
    _selectedPriceRange = HomePriceRange.custom;
    _minimumPrice = minimum;
    _maximumPrice = maximum;
    _previewItemId = null;
    notifyListeners();
  }

  void setSustainableOnly(bool value) {
    if (_sustainableOnly == value) return;
    _sustainableOnly = value;
    _previewItemId = null;
    notifyListeners();
  }

  void setView(HomeProductView view) {
    if (_view == view) return;
    _view = view;
    if (view == HomeProductView.grid) _previewItemId = null;
    notifyListeners();
  }

  void selectPreview(String? itemId) {
    if (_previewItemId == itemId) return;
    _previewItemId = itemId;
    notifyListeners();
  }

  void resetFilters() {
    _query = '';
    _selectedCategory = 'All';
    _selectedLocation = 'All NZ';
    _selectedSort = HomeProductSort.recommended;
    _selectedPriceRange = HomePriceRange.any;
    _sustainableOnly = false;
    _isNearYou = false;
    _minimumPrice = null;
    _maximumPrice = null;
    _userLatitude = null;
    _userLongitude = null;
    _view = HomeProductView.grid;
    _previewItemId = null;
    notifyListeners();
  }

  List<ItemModel> filterAndSort(List<ItemModel> source) {
    final normalizedQuery = _query.trim().toLowerCase();
    final products = source.where((item) {
      final queryMatches =
          normalizedQuery.isEmpty ||
          item.title.toLowerCase().contains(normalizedQuery) ||
          item.category.toLowerCase().contains(normalizedQuery);
      final normalizedCategory = item.category.toLowerCase();
      final categoryMatches =
          _selectedCategory == 'All' ||
          normalizedCategory == _selectedCategory.toLowerCase() ||
          (_selectedCategory == 'Transport' && normalizedCategory == 'vehicle');
      final locationMatches =
          _selectedLocation == 'All NZ' ||
          item.location.toLowerCase().contains(_selectedLocation.toLowerCase());
      final priceMatches =
          (_minimumPrice == null || item.numericPrice >= _minimumPrice!) &&
          (_maximumPrice == null || item.numericPrice <= _maximumPrice!);
      final sustainableMatches = !_sustainableOnly || item.isSustainable;
      return queryMatches &&
          categoryMatches &&
          locationMatches &&
          priceMatches &&
          sustainableMatches;
    }).toList();

    switch (_selectedSort) {
      case HomeProductSort.recommended:
        break;
      case HomeProductSort.priceLowToHigh:
        products.sort((a, b) => a.numericPrice.compareTo(b.numericPrice));
      case HomeProductSort.priceHighToLow:
        products.sort((a, b) => b.numericPrice.compareTo(a.numericPrice));
    }
    return products;
  }
}
