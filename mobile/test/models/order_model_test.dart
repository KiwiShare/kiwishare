import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/order_model.dart';

void main() {
  group('OrderModel Tests', () {
    test('parses SafeZoneModel correctly', () {
      final json = {
        'id': 'safe-zone-akl-police',
        'name': 'Auckland Central Police Station Safe Trading Zone',
        'category': 'police_station',
        'address': '13-15 Cook Street, Auckland CBD',
        'suburb': 'Auckland CBD',
        'city': 'Auckland',
        'latitude': -36.8524,
        'longitude': 174.7618,
        'features': ['24/7 CCTV Monitored', 'Well-lit Parking Bays'],
        'operatingHours': '24 Hours',
      };

      final zone = SafeZoneModel.fromMap(json);
      expect(zone.id, 'safe-zone-akl-police');
      expect(zone.name, contains('Auckland Central Police Station'));
      expect(zone.features.length, 2);
    });

    test('parses FeeBreakdownModel with early-bird waiver correctly', () {
      final json = {
        'itemAmount': 1000,
        'feeRate': 0.01,
        'standardBuyerFee': 10,
        'buyerFeeDiscount': 10,
        'effectiveBuyerFee': 0,
        'buyerTotalAmount': 1000,
        'standardSellerFee': 10,
        'sellerFeeDiscount': 10,
        'effectiveSellerFee': 0,
        'sellerReceiveAmount': 1000,
        'isEarlyBirdWaiver': true,
        'isSellerTurboMember': false,
      };

      final breakdown = FeeBreakdownModel.fromMap(json);
      expect(breakdown.itemAmount, 1000);
      expect(breakdown.standardBuyerFee, 10);
      expect(breakdown.buyerFeeDiscount, 10);
      expect(breakdown.effectiveBuyerFee, 0);
      expect(breakdown.buyerTotalAmount, 1000);
      expect(breakdown.sellerReceiveAmount, 1000);
      expect(breakdown.isEarlyBirdWaiver, true);
    });

    test('parses OrderModel and calculates NZD display prices', () {
      final json = {
        '_id': 'ord-123456789012',
        'orderNumber': 'KW-ORD-987654',
        'itemId': {'_id': 'item-100', 'title': 'Vintage Leather Armchair'},
        'buyerId': 'buyer-1',
        'sellerId': 'seller-1',
        'status': 'paid',
        'itemSnapshot': {
          'title': 'Vintage Leather Armchair',
          'condition': 'Very Good',
          'imageUrl': 'https://example.com/armchair.jpg',
        },
        'itemAmount': 4500, // $45.00
        'buyerTotalAmount': 4500,
        'sellerReceiveAmount': 4500,
        'meeting': {
          'locationName': 'Auckland Safe Trading Zone',
          'scheduledAt': '2026-09-01T14:00:00.000Z',
        },
      };

      final order = OrderModel.fromMap(json);
      expect(order.id, 'ord-123456789012');
      expect(order.orderNumber, 'KW-ORD-987654');
      expect(order.displayPriceNzd, 45.0);
      expect(order.displayTotalNzd, 45.0);
      expect(order.displaySellerPayoutNzd, 45.0);
      expect(order.isPaidEscrow, true);
      expect(order.isCompleted, false);
    });
  });
}
