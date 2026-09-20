class PublicProfileModel {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String bio;
  final String city;
  final String suburb;
  final int trustScore;
  final bool isVip;
  final bool isVerified;
  final bool isStudentVerified;
  final String? studentInstitution;
  final double rating;
  final int reviewCount;
  final int activeItemsCount;
  final int soldItemsCount;
  final DateTime? memberSince;

  const PublicProfileModel({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.bio,
    required this.city,
    required this.suburb,
    required this.trustScore,
    required this.isVip,
    required this.isVerified,
    required this.isStudentVerified,
    this.studentInstitution,
    required this.rating,
    required this.reviewCount,
    required this.activeItemsCount,
    required this.soldItemsCount,
    this.memberSince,
  });

  String get locationDescription {
    final parts = [suburb, city].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? 'Auckland, NZ' : parts.join(', ');
  }

  factory PublicProfileModel.fromJson(Map<String, dynamic> json) {
    final loc = json['location'];
    String city = '';
    String suburb = '';
    if (loc is Map) {
      city = (loc['city'] ?? '').toString();
      suburb = (loc['suburb'] ?? '').toString();
    }

    return PublicProfileModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'Kiwi Member').toString(),
      avatarUrl: json['avatarUrl'] as String?,
      bio: (json['bio'] ?? '').toString(),
      city: city,
      suburb: suburb,
      trustScore: (json['trustScore'] is num)
          ? (json['trustScore'] as num).toInt()
          : 80,
      isVip: json['isVip'] == true,
      isVerified: json['isVerified'] == true,
      isStudentVerified: json['isStudentVerified'] == true,
      studentInstitution: json['studentInstitution'] as String?,
      rating: (json['rating'] is num)
          ? (json['rating'] as num).toDouble()
          : 5.0,
      reviewCount: (json['reviewCount'] is num)
          ? (json['reviewCount'] as num).toInt()
          : 0,
      activeItemsCount: (json['activeItemsCount'] is num)
          ? (json['activeItemsCount'] as num).toInt()
          : 0,
      soldItemsCount: (json['soldItemsCount'] is num)
          ? (json['soldItemsCount'] as num).toInt()
          : 0,
      memberSince: json['memberSince'] != null
          ? DateTime.tryParse(json['memberSince'].toString())
          : null,
    );
  }
}

class PublicReviewModel {
  final String id;
  final String reviewerId;
  final String reviewerName;
  final String? reviewerAvatarUrl;
  final int rating;
  final String comment;
  final List<String> tags;
  final String role; // 'buyer' | 'seller'
  final String itemTitle;
  final String? itemImageUrl;
  final DateTime? createdAt;

  const PublicReviewModel({
    required this.id,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerAvatarUrl,
    required this.rating,
    required this.comment,
    required this.tags,
    required this.role,
    required this.itemTitle,
    this.itemImageUrl,
    this.createdAt,
  });

  factory PublicReviewModel.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags.map((t) => t.toString()).toList()
        : <String>[];

    return PublicReviewModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      reviewerId: (json['reviewerId'] ?? '').toString(),
      reviewerName: (json['reviewerName'] ?? 'Kiwi Trader').toString(),
      reviewerAvatarUrl: json['reviewerAvatarUrl'] as String?,
      rating: (json['rating'] is num) ? (json['rating'] as num).toInt() : 5,
      comment: (json['comment'] ?? '').toString(),
      tags: tags,
      role: (json['role'] ?? 'buyer').toString(),
      itemTitle: (json['itemTitle'] ?? 'KiwiShare Item').toString(),
      itemImageUrl: json['itemImageUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
