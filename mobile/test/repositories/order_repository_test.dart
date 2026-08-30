import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/models/order_model.dart';
import 'package:kiwishare/repositories/order_repository.dart';

void main() {
  group('OrderRepository Tests', () {
    test('getSafeZones returns parsed list of SafeZoneModel', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/api/safe-zones'));
        return http.Response(
          jsonEncode({
            'status': 'success',
            'data': [
              {
                'id': 'safe-zone-akl-police',
                'name': 'Auckland Central Police Station Safe Trading Zone',
                'category': 'police_station',
                'address': '13-15 Cook Street, Auckland CBD',
                'suburb': 'Auckland CBD',
                'city': 'Auckland',
                'latitude': -36.8524,
                'longitude': 174.7618,
                'features': ['24/7 CCTV Monitored'],
                'operatingHours': '24 Hours',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RestOrderRepository(client: mockClient);
      final zones = await repo.getSafeZones();

      expect(zones.length, 1);
      expect(zones.first.id, 'safe-zone-akl-police');
      expect(zones.first.city, 'Auckland');
    });

    test('checkout creates order and returns checkout payload', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/api/orders/checkout'));
        final body = jsonDecode(request.body);
        expect(body['itemId'], 'item-100');

        return http.Response(
          jsonEncode({
            'status': 'success',
            'order': {
              'id': 'ord-999',
              'orderNumber': 'KW-ORD-999',
              'status': 'pending_payment',
            },
            'clientSecret': 'pi_mock_secret',
            'feeBreakdown': {
              'itemAmount': 2000,
              'buyerTotalAmount': 2000,
              'sellerReceiveAmount': 2000,
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RestOrderRepository(client: mockClient);
      final res = await repo.checkout(
        itemId: 'item-100',
        meetingLocation: {'name': 'Auckland Safe Zone', 'address': '13 Cook St'},
        token: 'test-token',
        userId: 'test-user',
      );

      expect(res['status'], 'success');
      expect(res['order']['id'], 'ord-999');
    });

    test('payOrder holds funds in escrow and generates handover info', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/api/orders/ord-999/pay'));
        return http.Response(
          jsonEncode({
            'status': 'success',
            'order': {
              'id': 'ord-999',
              'status': 'paid',
            },
            'handover': {
              'claimCode': '849201',
              'qrToken': '849201',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RestOrderRepository(client: mockClient);
      final res = await repo.payOrder('ord-999', token: 'test-token');

      expect(res['status'], 'success');
      expect(res['order']['status'], 'paid');
      expect(res['handover']['claimCode'], '849201');
    });

    test('verifyHandover marks order as completed and releases escrow', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/api/orders/ord-999/verify-handover'));
        final body = jsonDecode(request.body);
        expect(body['claimCode'], '849201');

        return http.Response(
          jsonEncode({
            'status': 'success',
            'message': 'Handover verified and completed successfully.',
            'order': {
              'id': 'ord-999',
              'status': 'completed',
            },
            'escrowPayout': {
              'releasedAmount': 2000,
              'currency': 'NZD',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = RestOrderRepository(client: mockClient);
      final res = await repo.verifyHandover('ord-999', claimCode: '849201', token: 'test-token');

      expect(res['status'], 'success');
      expect(res['order']['status'], 'completed');
      expect(res['escrowPayout']['releasedAmount'], 2000);
    });
  });
}
