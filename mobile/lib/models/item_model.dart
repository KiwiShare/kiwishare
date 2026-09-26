import '../constants/nz_locations.dart';

enum ItemStatus { active, reserved, sold, delisted }

class SellerInfo {
  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final int trustScore;
  final bool isVerified;
  final bool isStudentVerified;
  final String? studentInstitution;

  const SellerInfo({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.trustScore = 100,
    this.isVerified = false,
    this.isStudentVerified = false,
    this.studentInstitution,
  });

  factory SellerInfo.fromMap(Map<String, dynamic> map) {
    return SellerInfo(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      displayName: (map['displayName'] ?? 'Kiwi Member').toString(),
      email: map['email']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
      trustScore: (map['trustScore'] is num)
          ? (map['trustScore'] as num).toInt()
          : 100,
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
    'isVerified': isVerified,
    'isStudentVerified': isStudentVerified,
    'studentInstitution': studentInstitution,
  };
}

class ItemModel {
  final String id;
  final String title;
  final String priceNzd;
  final String location;
  final String imageUrl;
  final List<String> images;
  final bool isSustainable;
  final String category;
  final ItemStatus status;
  final String description;
  final String? condition;
  final String ownerId;
  final SellerInfo? seller;
  final double? latitude;
  final double? longitude;
  final int watchlistCount;
  final bool isPromoted;
  final DateTime? promotedAt;

  const ItemModel({
    required this.id,
    required this.title,
    required this.priceNzd,
    required this.location,
    required this.imageUrl,
    this.images = const [],
    required this.isSustainable,
    required this.category,
    required this.status,
    this.description = '',
    this.condition,
    this.ownerId = '',
    this.seller,
    this.latitude,
    this.longitude,
    this.watchlistCount = 0,
    this.isPromoted = false,
    this.promotedAt,
  });

  double get numericPrice => double.tryParse(priceNzd) ?? 0;

  bool get isFree => numericPrice <= 0;

  String get ownerName => seller?.displayName ?? 'Seller';

  String get displayLocation => NzLocations.standardizeDisplayLocation(
    location,
    latitude: latitude,
    longitude: longitude,
  );

  double? get effectiveLatitude =>
      latitude ?? NzLocations.getApproximateCoordinates(location)?.latitude;

  double? get effectiveLongitude =>
      longitude ?? NzLocations.getApproximateCoordinates(location)?.longitude;

  bool get hasMapLocation =>
      effectiveLatitude != null && effectiveLongitude != null;

  bool get isDelisted => status == ItemStatus.delisted;

  bool get isActive => status == ItemStatus.active;

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
    String? location,
    String? imageUrl,
    List<String>? images,
    bool? isSustainable,
    String? category,
    ItemStatus? status,
    String? description,
    String? condition,
    String? ownerId,
    double? latitude,
    double? longitude,
    int? watchlistCount,
    bool? isPromoted,
    DateTime? promotedAt,
  }) {
    return ItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      priceNzd: priceNzd ?? this.priceNzd,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      isSustainable: isSustainable ?? this.isSustainable,
      category: category ?? this.category,
      status: status ?? this.status,
      description: description ?? this.description,
      condition: condition ?? this.condition,
      ownerId: ownerId ?? this.ownerId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      watchlistCount: watchlistCount ?? this.watchlistCount,
      isPromoted: isPromoted ?? this.isPromoted,
      promotedAt: promotedAt ?? this.promotedAt,
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
      'images': images,
      'isSustainable': isSustainable,
      'category': category,
      'status': status.name,
      'description': description,
      'condition': condition,
      'ownerId': ownerId,
      'seller': seller?.toMap(),
      'latitude': latitude,
      'longitude': longitude,
      'watchlistCount': watchlistCount,
      'isPromoted': isPromoted,
      'promotedAt': promotedAt?.toIso8601String(),
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

    DateTime? parsedPromotedAt;
    if (map['promotedAt'] != null) {
      parsedPromotedAt = DateTime.tryParse(map['promotedAt'].toString());
    }

    return ItemModel(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      priceNzd: (map['priceNzd'] ?? map['price'] ?? '0').toString(),
      location: (map['location'] ?? 'Location not supplied').toString(),
      imageUrl: singleImageUrl.isNotEmpty
          ? singleImageUrl
          : (imagesList.isNotEmpty ? imagesList.first : ''),
      images: imagesList,
      isSustainable: map['isSustainable'] == true,
      category: (map['category'] ?? '').toString(),
      status: _parseStatus(map['status']),
      description: (map['description'] ?? '').toString(),
      condition: map['condition']?.toString(),
      ownerId: (map['ownerId'] ?? '').toString(),
      seller: sellerInfo,
      latitude: _asDouble(map['latitude']),
      longitude: _asDouble(map['longitude']),
      watchlistCount: _asInt(map['watchlistCount'] ?? map['favouriteCount']),
      isPromoted: map['isPromoted'] == true,
      promotedAt: parsedPromotedAt,
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
        other.longitude == longitude &&
        other.watchlistCount == watchlistCount;
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
      watchlistCount,
    );
  }

  @override
  String toString() {
    return 'ItemModel(id: $id, title: $title, priceNzd: $priceNzd, location: $location, category: $category, status: $status, watchlistCount: $watchlistCount)';
  }
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

ItemStatus _parseStatus(dynamic value) => switch (value?.toString()) {
  'reserved' => ItemStatus.reserved,
  'sold' => ItemStatus.sold,
  'delisted' || 'draft' || 'hidden' || 'unlisted' => ItemStatus.delisted,
  _ => ItemStatus.active,
};
