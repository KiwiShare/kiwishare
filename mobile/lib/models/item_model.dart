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
  final String? description;
  final String? condition;
  final bool negotiable;
  final List<String> imageUrls;
  final String? ownerId;
  final String? sellerName;
  final String? sellerAvatarUrl;
  final double? sellerRating;
  final int? sellerReviewCount;

  const ItemModel({
    required this.id,
    required this.title,
    required this.priceNzd,
    required this.location,
    required this.imageUrl,
    required this.isSustainable,
    required this.category,
    required this.status,
    this.description,
    this.condition,
    this.negotiable = false,
    this.imageUrls = const [],
    this.ownerId,
    this.sellerName,
    this.sellerAvatarUrl,
    this.sellerRating,
    this.sellerReviewCount,
  });

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
    bool? negotiable,
    List<String>? imageUrls,
    String? ownerId,
    String? sellerName,
    String? sellerAvatarUrl,
    double? sellerRating,
    int? sellerReviewCount,
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
      negotiable: negotiable ?? this.negotiable,
      imageUrls: imageUrls ?? this.imageUrls,
      ownerId: ownerId ?? this.ownerId,
      sellerName: sellerName ?? this.sellerName,
      sellerAvatarUrl: sellerAvatarUrl ?? this.sellerAvatarUrl,
      sellerRating: sellerRating ?? this.sellerRating,
      sellerReviewCount: sellerReviewCount ?? this.sellerReviewCount,
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
      'negotiable': negotiable,
      'imageUrls': imageUrls,
      'ownerId': ownerId,
      'sellerName': sellerName,
      'sellerAvatarUrl': sellerAvatarUrl,
      'sellerRating': sellerRating,
      'sellerReviewCount': sellerReviewCount,
    };
  }

  /// Create from Map.
  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['id'] as String,
      title: map['title'] as String,
      priceNzd: map['priceNzd'] as String,
      location: map['location'] as String,
      imageUrl: map['imageUrl'] as String,
      isSustainable: map['isSustainable'] as bool,
      category: map['category'] as String,
      status: ItemStatus.values.byName(map['status'] as String),
      description: map['description'] as String?,
      condition: map['condition'] as String?,
      negotiable: map['negotiable'] as bool? ?? false,
      imageUrls:
          (map['imageUrls'] as List<dynamic>?)
              ?.map((url) => url.toString())
              .toList() ??
          const [],
      ownerId: map['ownerId'] as String?,
      sellerName: map['sellerName'] as String?,
      sellerAvatarUrl: map['sellerAvatarUrl'] as String?,
      sellerRating: (map['sellerRating'] as num?)?.toDouble(),
      sellerReviewCount: (map['sellerReviewCount'] as num?)?.toInt(),
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
        other.negotiable == negotiable &&
        _listEquals(other.imageUrls, imageUrls) &&
        other.ownerId == ownerId &&
        other.sellerName == sellerName &&
        other.sellerAvatarUrl == sellerAvatarUrl &&
        other.sellerRating == sellerRating &&
        other.sellerReviewCount == sellerReviewCount;
  }

  @override
  int get hashCode {
    return Object.hashAll([
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
      negotiable,
      ...imageUrls,
      ownerId,
      sellerName,
      sellerAvatarUrl,
      sellerRating,
      sellerReviewCount,
    ]);
  }

  @override
  String toString() {
    return 'ItemModel(id: $id, title: $title, priceNzd: $priceNzd, location: $location, imageUrl: $imageUrl, isSustainable: $isSustainable, category: $category, status: $status, ownerId: $ownerId)';
  }

  static bool _listEquals(List<String> first, List<String> second) {
    if (identical(first, second)) return true;
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
