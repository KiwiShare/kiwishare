import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/order_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/order_provider.dart';
import 'package:kiwishare/repositories/order_repository.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/views/profile/payment_checkout_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockOrderRepository implements OrderRepository {
  @override
  Future<List<OrderModel>> fetchMyOrders({required String token, String? type, String? status}) async => [];

  @override
  Future<OrderModel> fetchOrderDetails({required String orderId, required String token}) async {
    throw UnimplementedError();
  }

  @override
  Future<OrderModel> createOrGetOrder({required String itemId, required String token}) async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PaymentCheckoutScreen renders authentic logos and Stripe trust badge', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'jwt_token': 'test-token',
      'current_user':
          '{"id":"user-1","displayName":"Sam","trustScore":90,"isVerified":true,"isVip":false,"kiwiGoldBalance":50}',
    });

    final order = OrderModel(
      id: 'order-123',
      orderNumber: 'ORD-2026-001',
      status: 'pending_payment',
      role: 'buying',
      itemId: 'item-123',
      item: const OrderItemInfo(
        id: 'item-123',
        title: 'Sony WH-1000XM4',
        priceNzd: '250.00',
        imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e',
      ),
      counterparty: const OrderCounterparty(
        id: 'seller-1',
        displayName: 'Auckland Audio',
        role: 'seller',
      ),
      createdAt: DateTime.utc(2026, 9, 18),
      updatedAt: DateTime.utc(2026, 9, 18),
    );

    final auth = AuthProvider(userRepository: MockUserRepository());

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AcceptedPaymentProvidersWidget(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify professional brand logos
    expect(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText() == 'VISA'),
      findsOneWidget,
    );
    expect(find.text('AMEX'), findsOneWidget);
    expect(find.text('Pay'), findsNWidgets(2)); // Apple Pay and Google Pay
    expect(find.byIcon(Icons.apple), findsOneWidget);

    // 2. Verify Stripe trust footer
    expect(find.text('256-Bit SSL Encrypted & Protected'), findsOneWidget);
    expect(find.text('Powered by '), findsOneWidget);
    expect(find.text('stripe'), findsOneWidget);
  });
}
