enum ItemStatus { active, reserved, sold }

class ItemModel {
  final String id;
  final String title;
  final String priceNzd;
  final String location;
  final String imageUrl;
  final bool isSustainable;
  final String category;
  final ItemStatus status;
  final String description;
  final String? condition;
  final String ownerId;
  final double? latitude;
  final double? longitude;

  const ItemModel({
    required this.id,
    required this.title,
    required this.priceNzd,
    required this.location,
    required this.imageUrl,
    required this.isSustainable,
    required this.category,
    required this.status,
    this.description = '',
    this.condition,
    this.ownerId = '',
    this.latitude,
    this.longitude,
  });

  double get numericPrice => double.tryParse(priceNzd) ?? 0;

  bool get hasMapLocation => latitude != null && longitude != null;

  /// Create a copy of this ItemModel with updated fields.
  ItemModel copyWith({
    String? id,
    String? title,
    String? priceNzd,
    String? location,
    String? imageUrl,
    bool? isSustainable,
    String? category,
    ItemStatus? status,
    String? description,
    String? condition,
    String? ownerId,
    double? latitude,
    double? longitude,
  }) {
    return ItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      priceNzd: priceNzd ?? this.priceNzd,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      isSustainable: isSustainable ?? this.isSustainable,
      category: category ?? this.category,
      status: status ?? this.status,
      description: description ?? this.description,
      condition: condition ?? this.condition,
      ownerId: ownerId ?? this.ownerId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  /// Convert to Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'priceNzd': priceNzd,
      'location': location,
      'imageUrl': imageUrl,
      'isSustainable': isSustainable,
      'category': category,
      'status': status.name,
      'description': description,
      'condition': condition,
      'ownerId': ownerId,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Create from Map.
  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      priceNzd: (map['priceNzd'] ?? map['price'] ?? '0').toString(),
      location: (map['location'] ?? 'Location not supplied').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      isSustainable: map['isSustainable'] == true,
      category: (map['category'] ?? '').toString(),
      status: _parseStatus(map['status']),
      description: (map['description'] ?? '').toString(),
      condition: map['condition']?.toString(),
      ownerId: (map['ownerId'] ?? '').toString(),
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
    );
  }

  /// JSON serialization helper.
  factory ItemModel.fromJson(Map<String, dynamic> json) =>
      ItemModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ItemModel &&
        other.id == id &&
        other.title == title &&
        other.priceNzd == priceNzd &&
        other.location == location &&
        other.imageUrl == imageUrl &&
        other.isSustainable == isSustainable &&
        other.category == category &&
        other.status == status &&
        other.description == description &&
        other.condition == condition &&
        other.ownerId == ownerId &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      priceNzd,
      location,
      imageUrl,
      isSustainable,
      category,
      status,
      description,
      condition,
      ownerId,
      latitude,
      longitude,
    );
  }

  @override
  String toString() {
    return 'ItemModel(id: $id, title: $title, priceNzd: $priceNzd, location: $location, category: $category, status: $status)';
  }
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

ItemStatus _parseStatus(dynamic value) => switch (value?.toString()) {
  'reserved' => ItemStatus.reserved,
  'sold' => ItemStatus.sold,
  _ => ItemStatus.active,
};
