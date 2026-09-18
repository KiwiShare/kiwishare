class OrderItemInfo {
  final String id;
  final String title;
  final String priceNzd; // original list price
  final String? originalPriceNzd; // kept for display as strikethrough
  final String imageUrl;
  final String? condition;
  final String? category;

  const OrderItemInfo({
    required this.id,
    required this.title,
    required this.priceNzd,
    this.originalPriceNzd,
    required this.imageUrl,
    this.condition,
    this.category,
  });

  factory OrderItemInfo.fromJson(Map<String, dynamic> json) {
    return OrderItemInfo(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'KiwiShare Item').toString(),
      priceNzd: (json['priceNzd'] ?? '0.00').toString(),
      originalPriceNzd: json['originalPriceNzd']?.toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      condition: json['condition']?.toString(),
      category: json['category']?.toString(),
    );
  }
}

class OrderCounterparty {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String role; // 'seller' | 'buyer'

  const OrderCounterparty({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.role,
  });

  factory OrderCounterparty.fromJson(Map<String, dynamic> json) {
    return OrderCounterparty(
      id: (json['id'] ?? '').toString(),
      displayName: (json['displayName'] ?? 'User').toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      role: (json['role'] ?? 'user').toString(),
    );
  }
}

class OrderMeetingInfo {
  final DateTime scheduledAt;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String proposalStatus;
  final String? note;

  const OrderMeetingInfo({
    required this.scheduledAt,
    required this.locationName,
    this.latitude,
    this.longitude,
    required this.proposalStatus,
    this.note,
  });

  factory OrderMeetingInfo.fromJson(Map<String, dynamic> json) {
    return OrderMeetingInfo(
      scheduledAt:
          DateTime.tryParse(json['scheduledAt']?.toString() ?? '') ??
          DateTime.now(),
      locationName: (json['locationName'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      proposalStatus: (json['proposalStatus'] ?? 'proposed').toString(),
      note: json['note']?.toString(),
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String status;
  final String role; // 'buying' | 'selling'
  final String itemId;
  final OrderItemInfo item;
  final OrderCounterparty counterparty;
  final OrderMeetingInfo? meeting;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final DateTime? paidAt;
  final DateTime? refundedAt;

  /// The actual agreed/settled price (may differ from item.priceNzd due to special price negotiation)
  final String? itemAmountNzd;
  final String? buyerTotalAmountNzd;
  final String? buyerFeeAmountNzd;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.role,
    required this.itemId,
    required this.item,
    required this.counterparty,
    this.meeting,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.paidAt,
    this.refundedAt,
    this.itemAmountNzd,
    this.buyerTotalAmountNzd,
    this.buyerFeeAmountNzd,
  });

  bool get isBuying => role == 'buying';
  bool get isSelling => role == 'selling';
  bool get isPaid => paidAt != null || status == 'paid';
  bool get isRefunded => status == 'refunded' || refundedAt != null;

  bool get isCompleted =>
      status == 'completed' ||
      status == 'qr_scanned' ||
      status == 'seller_paid';

  bool get isInProgress =>
      status == 'meeting_scheduled' ||
      status == 'meeting_in_progress' ||
      status == 'pending_payment' ||
      status == 'paid' ||
      status == 'transfer_pending';

  bool get isCancelled =>
      status == 'cancelled' || status == 'refunded' || status == 'disputed';

  String get statusDisplay {
    if (isCompleted) return 'Completed';
    if (isCancelled) {
      if (status == 'refunded') return 'Refunded';
      if (status == 'disputed') return 'Disputed';
      return 'Cancelled';
    }
    if (isPaid) {
      if (status == 'meeting_scheduled' || status == 'meeting_in_progress') {
        return 'Paid · Meetup Arranged';
      }
      return 'Paid · Awaiting Handover';
    }
    if (status == 'pending_payment') return 'Pending Payment';
    return status;
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      orderNumber: (json['orderNumber'] ?? '').toString(),
      status: (json['status'] ?? 'pending_payment').toString(),
      role: (json['role'] ?? 'buying').toString(),
      itemId: (json['itemId'] ?? '').toString(),
      item: OrderItemInfo.fromJson(
        json['item'] is Map<String, dynamic>
            ? json['item'] as Map<String, dynamic>
            : {},
      ),
      counterparty: OrderCounterparty.fromJson(
        json['counterparty'] is Map<String, dynamic>
            ? json['counterparty'] as Map<String, dynamic>
            : {},
      ),
      meeting:
          json['meeting'] != null && json['meeting'] is Map<String, dynamic>
          ? OrderMeetingInfo.fromJson(json['meeting'] as Map<String, dynamic>)
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString())
          : null,
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'].toString())
          : null,
      refundedAt: json['refundedAt'] != null
          ? DateTime.tryParse(json['refundedAt'].toString())
          : null,
      itemAmountNzd:
          json['itemAmountNzd']?.toString() ?? json['itemAmount']?.toString(),
      buyerTotalAmountNzd:
          json['buyerTotalAmountNzd']?.toString() ??
          json['buyerTotalAmount']?.toString(),
      buyerFeeAmountNzd:
          json['buyerFeeAmountNzd']?.toString() ??
          json['buyerFeeAmount']?.toString(),
    );
  }
}
