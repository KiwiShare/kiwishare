class DiscoveryCategoryOption {
  final String value;
  final int count;

  const DiscoveryCategoryOption({required this.value, required this.count});

  factory DiscoveryCategoryOption.fromJson(Map<String, dynamic> json) {
    return DiscoveryCategoryOption(
      value: (json['value'] ?? '').toString(),
      count: _asInt(json['count']),
    );
  }
}

class DiscoveryLocationOption {
  final String value;
  final int count;
  final double? latitude;
  final double? longitude;

  const DiscoveryLocationOption({
    required this.value,
    required this.count,
    this.latitude,
    this.longitude,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  factory DiscoveryLocationOption.fromJson(Map<String, dynamic> json) {
    return DiscoveryLocationOption(
      value: (json['value'] ?? '').toString(),
      count: _asInt(json['count']),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
    );
  }
}

class DiscoveryConditionOption {
  final String value;
  final int count;

  const DiscoveryConditionOption({required this.value, required this.count});

  factory DiscoveryConditionOption.fromJson(Map<String, dynamic> json) {
    return DiscoveryConditionOption(
      value: (json['value'] ?? '').toString(),
      count: _asInt(json['count']),
    );
  }
}

class DiscoveryOptionsModel {
  final List<DiscoveryCategoryOption> categories;
  final List<DiscoveryLocationOption> locations;
  final List<DiscoveryConditionOption> conditions;
  final double? minimumPrice;
  final double? maximumPrice;

  const DiscoveryOptionsModel({
    required this.categories,
    required this.locations,
    this.conditions = const [],
    this.minimumPrice,
    this.maximumPrice,
  });

  factory DiscoveryOptionsModel.fromJson(Map<String, dynamic> json) {
    final priceRange = json['priceRange'];
    return DiscoveryOptionsModel(
      categories: _mapList(
        json['categories'],
        DiscoveryCategoryOption.fromJson,
      ),
      locations: _mapList(json['locations'], DiscoveryLocationOption.fromJson),
      conditions: _mapList(
        json['conditions'],
        DiscoveryConditionOption.fromJson,
      ),
      minimumPrice: priceRange is Map<String, dynamic>
          ? _asDouble(priceRange['minimum'])
          : null,
      maximumPrice: priceRange is Map<String, dynamic>
          ? _asDouble(priceRange['maximum'])
          : null,
    );
  }
}

class DiscoveryQuery {
  final String query;
  final String? category;
  final String? location;
  final double? minimumPrice;
  final double? maximumPrice;
  final bool sustainableOnly;
  final String sort;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;

  const DiscoveryQuery({
    this.query = '',
    this.category,
    this.location,
    this.minimumPrice,
    this.maximumPrice,
    this.sustainableOnly = false,
    this.sort = 'recommended',
    this.latitude,
    this.longitude,
    this.radiusKm,
  });

  Map<String, String> toQueryParameters() {
    return {
      if (query.trim().isNotEmpty) 'query': query.trim(),
      if (category != null && category!.isNotEmpty) 'category': category!,
      if (location != null && location!.isNotEmpty) 'location': location!,
      if (minimumPrice != null) 'minPrice': _formatNumber(minimumPrice!),
      if (maximumPrice != null) 'maxPrice': _formatNumber(maximumPrice!),
      if (sustainableOnly) 'sustainable': 'true',
      if (sort != 'recommended') 'sort': sort,
      if (latitude != null) 'latitude': latitude!.toStringAsFixed(6),
      if (longitude != null) 'longitude': longitude!.toStringAsFixed(6),
      if (radiusKm != null) 'radiusKm': _formatNumber(radiusKm!),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is DiscoveryQuery &&
        other.query == query &&
        other.category == category &&
        other.location == location &&
        other.minimumPrice == minimumPrice &&
        other.maximumPrice == maximumPrice &&
        other.sustainableOnly == sustainableOnly &&
        other.sort == sort &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.radiusKm == radiusKm;
  }

  @override
  int get hashCode => Object.hash(
    query,
    category,
    location,
    minimumPrice,
    maximumPrice,
    sustainableOnly,
    sort,
    latitude,
    longitude,
    radiusKm,
  );
}

List<T> _mapList<T>(dynamic source, T Function(Map<String, dynamic>) parse) {
  if (source is! List) return const [];
  return source
      .whereType<Map<String, dynamic>>()
      .map(parse)
      .where(
        (value) => switch (value) {
          DiscoveryCategoryOption option => option.value.isNotEmpty,
          DiscoveryLocationOption option => option.value.isNotEmpty,
          DiscoveryConditionOption option => option.value.isNotEmpty,
          _ => true,
        },
      )
      .toList(growable: false);
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}
