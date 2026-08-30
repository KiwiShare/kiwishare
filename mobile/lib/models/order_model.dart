import 'package:flutter/foundation.dart';

class SafeZoneModel {
  final String id;
  final String name;
  final String category;
  final String address;
  final String suburb;
  final String city;
  final double latitude;
  final double longitude;
  final List<String> features;
  final String operatingHours;

  const SafeZoneModel({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.suburb,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.features,
    required this.operatingHours,
  });

  factory SafeZoneModel.fromMap(Map<String, dynamic> map) {
    return SafeZoneModel(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? 'Safe Trading Zone').toString(),
      category: (map['category'] ?? 'police_station').toString(),
      address: (map['address'] ?? '').toString(),
      suburb: (map['suburb'] ?? '').toString(),
      city: (map['city'] ?? 'Auckland').toString(),
      latitude: (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : -36.8524,
      longitude: (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : 174.7618,
      features: (map['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      operatingHours: (map['operatingHours'] ?? '24/7 Monitored').toString(),
    );
  }
}

class FeeBreakdownModel {
  final int itemAmount; // in cents
  final double feeRate;
  final int standardBuyerFee;
  final int buyerFeeDiscount;
  final int effectiveBuyerFee;
  final int buyerTotalAmount;
  final int standardSellerFee;
  final int sellerFeeDiscount;
  final int effectiveSellerFee;
  final int sellerReceiveAmount;
  final bool isEarlyBirdWaiver;
  final bool isSellerTurboMember;

  const FeeBreakdownModel({
    required this.itemAmount,
    this.feeRate = 0.01,
    required this.standardBuyerFee,
    required this.buyerFeeDiscount,
    required this.effectiveBuyerFee,
    required this.buyerTotalAmount,
    required this.standardSellerFee,
    required this.sellerFeeDiscount,
    required this.effectiveSellerFee,
    required this.sellerReceiveAmount,
    this.isEarlyBirdWaiver = true,
    this.isSellerTurboMember = false,
  });

  factory FeeBreakdownModel.fromMap(Map<String, dynamic> map) {
    return FeeBreakdownModel(
      itemAmount: (map['itemAmount'] is num) ? (map['itemAmount'] as num).toInt() : 0,
      feeRate: (map['feeRate'] is num) ? (map['feeRate'] as num).toDouble() : 0.01,
      standardBuyerFee: (map['standardBuyerFee'] is num) ? (map['standardBuyerFee'] as num).toInt() : 0,
      buyerFeeDiscount: (map['buyerFeeDiscount'] is num) ? (map['buyerFeeDiscount'] as num).toInt() : 0,
      effectiveBuyerFee: (map['effectiveBuyerFee'] is num) ? (map['effectiveBuyerFee'] as num).toInt() : 0,
      buyerTotalAmount: (map['buyerTotalAmount'] is num) ? (map['buyerTotalAmount'] as num).toInt() : 0,
      standardSellerFee: (map['standardSellerFee'] is num) ? (map['standardSellerFee'] as num).toInt() : 0,
      sellerFeeDiscount: (map['sellerFeeDiscount'] is num) ? (map['sellerFeeDiscount'] as num).toInt() : 0,
      effectiveSellerFee: (map['effectiveSellerFee'] is num) ? (map['effectiveSellerFee'] as num).toInt() : 0,
      sellerReceiveAmount: (map['sellerReceiveAmount'] is num) ? (map['sellerReceiveAmount'] as num).toInt() : 0,
      isEarlyBirdWaiver: map['isEarlyBirdWaiver'] != false,
      isSellerTurboMember: map['isSellerTurboMember'] == true,
    );
  }
}

class HandoverInfo {
  final String qrToken;
  final String claimCode;
  final String? expiresAt;

  const HandoverInfo({
    required this.qrToken,
    required this.claimCode,
    this.expiresAt,
  });

  factory HandoverInfo.fromMap(Map<String, dynamic> map) {
    return HandoverInfo(
      qrToken: (map['qrToken'] ?? '').toString(),
      claimCode: (map['claimCode'] ?? '').toString(),
      expiresAt: map['expiresAt']?.toString(),
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String itemId;
  final String buyerId;
  final String sellerId;
  final String status;
  final String title;
  final String imageUrl;
  final String condition;
  final int itemAmount; // cents
  final int buyerTotalAmount; // cents
  final int sellerReceiveAmount; // cents
  final String locationName;
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final HandoverInfo? handover;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.itemId,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.title,
    required this.imageUrl,
    this.condition = 'Good',
    required this.itemAmount,
    required this.buyerTotalAmount,
    required this.sellerReceiveAmount,
    this.locationName = 'Auckland Safe Zone',
    this.scheduledAt,
    required this.createdAt,
    this.handover,
  });

  double get displayPriceNzd => itemAmount / 100.0;
  double get displayTotalNzd => buyerTotalAmount / 100.0;
  double get displaySellerPayoutNzd => sellerReceiveAmount / 100.0;

  bool get isCompleted => status == 'completed' || status == 'seller_paid';
  bool get isPaidEscrow => status == 'paid' || status == 'meeting_scheduled' || status == 'meeting_in_progress';

  factory OrderModel.fromMap(Map<String, dynamic> map, {HandoverInfo? handover}) {
    final itemSnap = map['itemSnapshot'] is Map ? map['itemSnapshot'] as Map<String, dynamic> : <String, dynamic>{};
    final meeting = map['meeting'] is Map ? map['meeting'] as Map<String, dynamic> : <String, dynamic>{};

    return OrderModel(
      id: (map['_id'] ?? map['id'] ?? '').toString(),
      orderNumber: (map['orderNumber'] ?? 'KW-ORD').toString(),
      itemId: map['itemId'] is Map ? (map['itemId']['_id'] ?? map['itemId']['id'] ?? '').toString() : (map['itemId'] ?? '').toString(),
      buyerId: map['buyerId'] is Map ? (map['buyerId']['_id'] ?? map['buyerId']['id'] ?? '').toString() : (map['buyerId'] ?? '').toString(),
      sellerId: map['sellerId'] is Map ? (map['sellerId']['_id'] ?? map['sellerId']['id'] ?? '').toString() : (map['sellerId'] ?? '').toString(),
      status: (map['status'] ?? 'pending_payment').toString(),
      title: (itemSnap['title'] ?? map['title'] ?? 'Pre-loved Item').toString(),
      imageUrl: (itemSnap['imageUrl'] ?? map['imageUrl'] ?? '').toString(),
      condition: (itemSnap['condition'] ?? 'Good').toString(),
      itemAmount: (map['itemAmount'] is num) ? (map['itemAmount'] as num).toInt() : 0,
      buyerTotalAmount: (map['buyerTotalAmount'] is num) ? (map['buyerTotalAmount'] as num).toInt() : 0,
      sellerReceiveAmount: (map['sellerReceiveAmount'] is num) ? (map['sellerReceiveAmount'] as num).toInt() : 0,
      locationName: (meeting['locationName'] ?? 'Auckland Safe Trading Zone').toString(),
      scheduledAt: meeting['scheduledAt'] != null ? DateTime.tryParse(meeting['scheduledAt'].toString()) : null,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
      handover: handover ?? (map['handover'] is Map ? HandoverInfo.fromMap(map['handover'] as Map<String, dynamic>) : null),
    );
  }
}
