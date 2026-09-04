import 'package:flutter/material.dart';

import '../models/discovery_options_model.dart';

enum HomeProductSort { recommended, priceLowToHigh, priceHighToLow }

enum HomeProductView { grid, map }

enum HomePriceRange { any, under25, from25To50, from50To100, over100, custom }

extension HomeProductSortLabel on HomeProductSort {
  String get label => switch (this) {
    HomeProductSort.recommended => 'Recommended',
    HomeProductSort.priceLowToHigh => 'Price: low to high',
    HomeProductSort.priceHighToLow => 'Price: high to low',
  };

  String get apiValue => switch (this) {
    HomeProductSort.recommended => 'recommended',
    HomeProductSort.priceLowToHigh => 'price_asc',
    HomeProductSort.priceHighToLow => 'price_desc',
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
  static const allCategoriesLabel = 'All';
  static const allLocationsLabel = 'All NZ';
  static const nearbyRadiusKm = 50.0;

  List<DiscoveryCategoryOption> _categories = const [];
  List<DiscoveryLocationOption> _locations = const [];
  double? _availableMinimumPrice;
  double? _availableMaximumPrice;
  String _query = '';
  String _selectedCategory = allCategoriesLabel;
  String _selectedLocation = allLocationsLabel;
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

  List<DiscoveryCategoryOption> get categories => _categories;
  List<DiscoveryLocationOption> get locations => _locations;
  double? get availableMinimumPrice => _availableMinimumPrice;
  double? get availableMaximumPrice => _availableMaximumPrice;
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

  DiscoveryQuery get discoveryQuery => DiscoveryQuery(
    query: _query,
    category: _selectedCategory == allCategoriesLabel
        ? null
        : _selectedCategory,
    location: _selectedLocation == allLocationsLabel || _isNearYou
        ? null
        : _selectedLocation,
    minimumPrice: _minimumPrice,
    maximumPrice: _maximumPrice,
    sustainableOnly: _sustainableOnly,
    sort: _selectedSort.apiValue,
    latitude: _isNearYou ? _userLatitude : null,
    longitude: _isNearYou ? _userLongitude : null,
    radiusKm: _isNearYou ? nearbyRadiusKm : null,
  );

  int get activeFilterCount => [
    _selectedPriceRange != HomePriceRange.any,
    _sustainableOnly,
    _selectedSort != HomeProductSort.recommended,
  ].where((active) => active).length;

  void applyOptions(DiscoveryOptionsModel options) {
    _categories = options.categories;
    _locations = options.locations;
    _availableMinimumPrice = options.minimumPrice;
    _availableMaximumPrice = options.maximumPrice;

    if (_selectedCategory != allCategoriesLabel &&
        !_categories.any((option) => option.value == _selectedCategory)) {
      _selectedCategory = allCategoriesLabel;
    }
    if (!_isNearYou &&
        _selectedLocation != allLocationsLabel &&
        !_locations.any((option) => option.value == _selectedLocation)) {
      _selectedLocation = allLocationsLabel;
      _userLatitude = null;
      _userLongitude = null;
    }
    notifyListeners();
  }

  void setQuery(String value) {
    final normalized = value.trimLeft();
    if (_query == normalized) return;
    _query = normalized;
    _previewItemId = null;
    notifyListeners();
  }

  void toggleCategory(String category) {
    final next = _selectedCategory == category ? allCategoriesLabel : category;
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
    DiscoveryLocationOption? option;
    for (final candidate in _locations) {
      if (candidate.value == location) {
        option = candidate;
        break;
      }
    }
    final isAllLocations = location == allLocationsLabel;
    final nextLatitude = isAllLocations ? null : latitude ?? option?.latitude;
    final nextLongitude = isAllLocations
        ? null
        : longitude ?? option?.longitude;
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
    _selectedCategory = allCategoriesLabel;
    _selectedLocation = allLocationsLabel;
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
}
