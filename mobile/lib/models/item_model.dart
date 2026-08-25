enum ItemStatus { active, reserved, sold }

class SellerInfo {
  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final int? trustScore;
  final double? rating;
  final int? reviewCount;
  final bool isVerified;
  final bool isStudentVerified;
  final String? studentInstitution;

  const SellerInfo({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.trustScore,
    this.rating,
    this.reviewCount,
    this.isVerified = false,
    this.isStudentVerified = false,
    this.studentInstitution,
  });

  factory SellerInfo.fromMap(Map<String, dynamic> map) {
    return SellerInfo(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      displayName: (map['displayName'] ?? '').toString(),
      email: map['email']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
      trustScore: (map['trustScore'] is num)
          ? (map['trustScore'] as num).toInt()
          : null,
      rating: _asDouble(map['rating']),
      reviewCount: (map['reviewCount'] is num)
          ? (map['reviewCount'] as num).toInt()
          : null,
      isVerified: map['isVerified'] == true,
      isStudentVerified: map['isStudentVerified'] == true,
      studentInstitution: map['studentInstitution']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'displayName': displayName,
    'email': email,
    'avatarUrl': avatarUrl,
    'trustScore': trustScore,
    'rating': rating,
    'reviewCount': reviewCount,
    'isVerified': isVerified,
    'isStudentVerified': isStudentVerified,
    'studentInstitution': studentInstitution,
  };
}

class ItemModel {
  final String id;
  final String title;
  final String priceNzd;
  final String currency;
  final String location;
  final String imageUrl;
  final List<String> images;
  final bool isSustainable;
  final String category;
  final ItemStatus status;
  final String description;
  final String? condition;
  final bool negotiable;
  final String ownerId;
  final SellerInfo? seller;
  final double? latitude;
  final double? longitude;

  const ItemModel({
    required this.id,
    required this.title,
    required this.priceNzd,
    this.currency = '',
    required this.location,
    required this.imageUrl,
    this.images = const [],
    required this.isSustainable,
    required this.category,
    required this.status,
    this.description = '',
    this.condition,
    this.negotiable = false,
    this.ownerId = '',
    this.seller,
    this.latitude,
    this.longitude,
  });

  double get numericPrice => double.tryParse(priceNzd) ?? 0;

  bool get hasMapLocation => latitude != null && longitude != null;

  /// Returns the complete list of images, falling back to imageUrl
  List<String> get allImages {
    if (images.isNotEmpty) return images;
    if (imageUrl.isNotEmpty) return [imageUrl];
    return const [];
  }

  /// Create a copy of this ItemModel with updated fields.
  ItemModel copyWith({
    String? id,
    String? title,
    String? priceNzd,
    String? currency,
    String? location,
    String? imageUrl,
    List<String>? images,
    bool? isSustainable,
    String? category,
    ItemStatus? status,
    String? description,
    String? condition,
    bool? negotiable,
    String? ownerId,
    SellerInfo? seller,
    double? latitude,
    double? longitude,
  }) {
    return ItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      priceNzd: priceNzd ?? this.priceNzd,
      currency: currency ?? this.currency,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      isSustainable: isSustainable ?? this.isSustainable,
      category: category ?? this.category,
      status: status ?? this.status,
      description: description ?? this.description,
      condition: condition ?? this.condition,
      negotiable: negotiable ?? this.negotiable,
      ownerId: ownerId ?? this.ownerId,
      seller: seller ?? this.seller,
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
      'currency': currency,
      'location': location,
      'imageUrl': imageUrl,
      'images': images,
      'isSustainable': isSustainable,
      'category': category,
      'status': status.name,
      'description': description,
      'condition': condition,
      'negotiable': negotiable,
      'ownerId': ownerId,
      'seller': seller?.toMap(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Create from Map.
  factory ItemModel.fromMap(Map<String, dynamic> map) {
    final rawImages = map['images'];
    final imagesList = <String>[];
    if (rawImages is List) {
      for (final item in rawImages) {
        if (item is String && item.isNotEmpty) {
          imagesList.add(item);
        } else if (item is Map && item['url'] != null) {
          imagesList.add(item['url'].toString());
        }
      }
    }
    final singleImageUrl = (map['imageUrl'] ?? '').toString();
    if (imagesList.isEmpty && singleImageUrl.isNotEmpty) {
      imagesList.add(singleImageUrl);
    }

    final rawSeller = map['seller'];
    SellerInfo? sellerInfo;
    if (rawSeller is Map<String, dynamic>) {
      sellerInfo = SellerInfo.fromMap(rawSeller);
    } else if (rawSeller is Map) {
      sellerInfo = SellerInfo.fromMap(Map<String, dynamic>.from(rawSeller));
    }

    return ItemModel(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      priceNzd: (map['priceNzd'] ?? '').toString(),
      currency: (map['currency'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
      imageUrl: singleImageUrl.isNotEmpty
          ? singleImageUrl
          : (imagesList.isNotEmpty ? imagesList.first : ''),
      images: imagesList,
      isSustainable: map['isSustainable'] == true,
      category: (map['category'] ?? '').toString(),
      status: _parseStatus(map['status']),
      description: (map['description'] ?? '').toString(),
      condition: map['condition']?.toString(),
      negotiable: map['negotiable'] == true,
      ownerId: (map['ownerId'] ?? '').toString(),
      seller: sellerInfo,
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
        other.currency == currency &&
        other.location == location &&
        other.imageUrl == imageUrl &&
        other.isSustainable == isSustainable &&
        other.category == category &&
        other.status == status &&
        other.description == description &&
        other.condition == condition &&
        other.negotiable == negotiable &&
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
      currency,
      location,
      imageUrl,
      isSustainable,
      category,
      status,
      description,
      condition,
      negotiable,
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
