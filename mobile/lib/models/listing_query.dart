enum ListingSortOrder {
  popular,
  newest,
  priceLowToHigh,
  priceHighToLow,
  nearest,
}

extension ListingSortOrderPresentation on ListingSortOrder {
  String get apiValue => switch (this) {
    ListingSortOrder.popular => 'popular',
    ListingSortOrder.newest => 'newest',
    ListingSortOrder.priceLowToHigh => 'price_asc',
    ListingSortOrder.priceHighToLow => 'price_desc',
    ListingSortOrder.nearest => 'nearest',
  };

  String get label => switch (this) {
    ListingSortOrder.popular => 'Popular',
    ListingSortOrder.newest => 'Newest',
    ListingSortOrder.priceLowToHigh => 'Price: low to high',
    ListingSortOrder.priceHighToLow => 'Price: high to low',
    ListingSortOrder.nearest => 'Nearest first',
  };
}

class ListingQuery {
  final String query;
  final String? category;
  final String? location;
  final ListingSortOrder sortOrder;
  final double? latitude;
  final double? longitude;
  final double radiusKm;
  final int? limit;

  const ListingQuery({
    this.query = '',
    this.category,
    this.location,
    this.sortOrder = ListingSortOrder.popular,
    this.latitude,
    this.longitude,
    this.radiusKm = 25,
    this.limit,
  });

  bool get isNearby => latitude != null && longitude != null;

  Map<String, String> toQueryParameters() {
    final parameters = <String, String>{'sort': sortOrder.apiValue};
    if (query.trim().isNotEmpty) parameters['query'] = query.trim();
    if (category != null && category!.trim().isNotEmpty) {
      parameters['category'] = category!.trim();
    }
    if (location != null && location!.trim().isNotEmpty) {
      parameters['location'] = location!.trim();
    }
    if (isNearby) {
      parameters['latitude'] = latitude!.toStringAsFixed(6);
      parameters['longitude'] = longitude!.toStringAsFixed(6);
      parameters['radiusKm'] = radiusKm.toStringAsFixed(1);
    }
    if (limit != null) parameters['limit'] = limit.toString();
    return parameters;
  }

  @override
  bool operator ==(Object other) {
    return other is ListingQuery &&
        other.query == query &&
        other.category == category &&
        other.location == location &&
        other.sortOrder == sortOrder &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.radiusKm == radiusKm &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
    query,
    category,
    location,
    sortOrder,
    latitude,
    longitude,
    radiusKm,
    limit,
  );
}
