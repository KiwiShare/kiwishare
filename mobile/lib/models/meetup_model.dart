class MeetupModel {
  const MeetupModel({
    required this.id,
    required this.orderNumber,
    required this.itemId,
    required this.itemTitle,
    required this.itemPriceNzd,
    required this.itemImageUrl,
    required this.status,
    required this.role,
    required this.buyerId,
    required this.buyerName,
    this.buyerAvatarUrl,
    required this.sellerId,
    required this.sellerName,
    this.sellerAvatarUrl,
    required this.scheduledAt,
    required this.locationName,
    this.latitude,
    this.longitude,
    required this.proposalStatus,
    this.proposedBy,
    this.note,
    this.qrToken,
    this.paymentConfirmed,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderNumber;
  final String itemId;
  final String itemTitle;
  final String itemPriceNzd;
  final String itemImageUrl;
  final String status;
  final String role; // 'buying' | 'selling'
  final String buyerId;
  final String buyerName;
  final String? buyerAvatarUrl;
  final String sellerId;
  final String sellerName;
  final String? sellerAvatarUrl;
  final DateTime scheduledAt;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String
  proposalStatus; // 'proposed' | 'confirmed' | 'declined' | 'cancelled'
  final String? proposedBy;
  final String? note;
  final String? qrToken;
  final bool? paymentConfirmed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isBuying => role == 'buying';
  bool get isSelling => role == 'selling';

  bool get isProposed => proposalStatus == 'proposed';
  bool get isConfirmed => proposalStatus == 'confirmed';
  bool get isDeclined => proposalStatus == 'declined';
  bool get isCancelled => proposalStatus == 'cancelled';
  bool get isCompleted => status == 'completed';
  bool get isPaid =>
      paymentConfirmed ?? (status == 'completed' || status == 'paid');

  bool get hasCoordinates => latitude != null && longitude != null;

  String get counterpartyName => isBuying ? sellerName : buyerName;
  String? get counterpartyAvatarUrl =>
      isBuying ? sellerAvatarUrl : buyerAvatarUrl;
  String get counterpartyRole => isBuying ? 'Seller' : 'Buyer';

  MeetupModel copyWith({
    String? id,
    String? orderNumber,
    String? itemId,
    String? itemTitle,
    String? itemPriceNzd,
    String? itemImageUrl,
    String? status,
    String? role,
    String? buyerId,
    String? buyerName,
    String? buyerAvatarUrl,
    String? sellerId,
    String? sellerName,
    String? sellerAvatarUrl,
    DateTime? scheduledAt,
    String? locationName,
    double? latitude,
    double? longitude,
    String? proposalStatus,
    String? proposedBy,
    String? note,
    String? qrToken,
    bool? paymentConfirmed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MeetupModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      itemId: itemId ?? this.itemId,
      itemTitle: itemTitle ?? this.itemTitle,
      itemPriceNzd: itemPriceNzd ?? this.itemPriceNzd,
      itemImageUrl: itemImageUrl ?? this.itemImageUrl,
      status: status ?? this.status,
      role: role ?? this.role,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      buyerAvatarUrl: buyerAvatarUrl ?? this.buyerAvatarUrl,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerAvatarUrl: sellerAvatarUrl ?? this.sellerAvatarUrl,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      proposalStatus: proposalStatus ?? this.proposalStatus,
      proposedBy: proposedBy ?? this.proposedBy,
      note: note ?? this.note,
      qrToken: qrToken ?? this.qrToken,
      paymentConfirmed: paymentConfirmed ?? this.paymentConfirmed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MeetupModel.fromJson(Map<String, dynamic> json) {
    return MeetupModel(
      id: (json['id'] ?? '').toString(),
      orderNumber: (json['orderNumber'] ?? '').toString(),
      itemId: (json['itemId'] ?? '').toString(),
      itemTitle: (json['itemTitle'] ?? 'KiwiShare Item').toString(),
      itemPriceNzd: (json['itemPriceNzd'] ?? '0.00').toString(),
      itemImageUrl: (json['itemImageUrl'] ?? '').toString(),
      status: (json['status'] ?? 'meeting_scheduled').toString(),
      role: (json['role'] ?? 'buying').toString(),
      buyerId: (json['buyerId'] ?? '').toString(),
      buyerName: (json['buyerName'] ?? 'Buyer').toString(),
      buyerAvatarUrl: json['buyerAvatarUrl']?.toString(),
      sellerId: (json['sellerId'] ?? '').toString(),
      sellerName: (json['sellerName'] ?? 'Seller').toString(),
      sellerAvatarUrl: json['sellerAvatarUrl']?.toString(),
      scheduledAt:
          DateTime.tryParse(json['scheduledAt']?.toString() ?? '') ??
          DateTime.now(),
      locationName: (json['locationName'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      proposalStatus: (json['proposalStatus'] ?? 'proposed').toString(),
      proposedBy: json['proposedBy']?.toString(),
      note: json['note']?.toString(),
      qrToken: json['qrToken']?.toString(),
      paymentConfirmed: json['isPaid'] is bool ? json['isPaid'] as bool : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
    );
  }
}
