import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/order_model.dart';
import 'package:kiwishare/repositories/order_repository.dart';
import 'package:kiwishare/views/profile/payment_checkout_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockOrderRepository implements OrderRepository {
  @override
  Future<List<OrderModel>> fetchMyOrders({
    required String token,
    String? type,
    String? status,
  }) async => [];

  @override
  Future<OrderModel> fetchOrderDetails({
    required String orderId,
    required String token,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<OrderModel> createOrGetOrder({
    required String itemId,
    required String token,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<OrderModel> refundOrder({
    required String orderId,
    required String token,
    String? reason,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'PaymentCheckoutScreen renders authentic logos and Stripe trust badge',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'jwt_token': 'test-token',
        'current_user':
            '{"id":"user-1","displayName":"Sam","trustScore":90,"isVerified":true,"isVip":false,"kiwiGoldBalance":50}',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AcceptedPaymentProvidersWidget()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify professional brand logos
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == 'VISA',
        ),
        findsOneWidget,
      );
      expect(find.text('AMEX'), findsOneWidget);
      expect(find.text('Pay'), findsNWidgets(2)); // Apple Pay and Google Pay
      expect(find.byIcon(Icons.apple), findsOneWidget);

      // 2. Verify Stripe trust footer
      expect(find.text('256-Bit SSL Encrypted & Protected'), findsOneWidget);
      expect(find.text('Powered by '), findsOneWidget);
      expect(find.text('stripe'), findsOneWidget);
    },
  );
}
