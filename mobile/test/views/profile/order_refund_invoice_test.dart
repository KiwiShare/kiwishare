import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/order_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/order_provider.dart';
import 'package:kiwishare/repositories/order_repository.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/utils/campus_locations.dart';
import 'package:kiwishare/views/profile/user_orders_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockOrderRepo implements OrderRepository {
  _MockOrderRepo(this.orders);
  final List<OrderModel> orders;
  bool refundCalled = false;

  @override
  Future<List<OrderModel>> fetchMyOrders({
    required String token,
    String? type,
    String? status,
  }) async {
    return orders;
  }

  @override
  Future<OrderModel> fetchOrderDetails({
    required String orderId,
    required String token,
  }) async {
    return orders.firstWhere((o) => o.id == orderId);
  }

  @override
  Future<OrderModel> createOrGetOrder({
    required String itemId,
    required String token,
  }) async {
    return orders.first;
  }

  @override
  Future<OrderModel> refundOrder({
    required String orderId,
    required String token,
    String? reason,
  }) async {
    refundCalled = true;
    final index = orders.indexWhere((o) => o.id == orderId);
    final refundedOrder = OrderModel(
      id: orders[index].id,
      orderNumber: orders[index].orderNumber,
      status: 'refunded',
      role: orders[index].role,
      itemId: orders[index].itemId,
      item: orders[index].item,
      counterparty: orders[index].counterparty,
      meeting: orders[index].meeting,
      createdAt: orders[index].createdAt,
      updatedAt: DateTime.now(),
      paidAt: orders[index].paidAt,
      refundedAt: DateTime.now(),
      itemAmountNzd: orders[index].itemAmountNzd,
      buyerTotalAmountNzd: orders[index].buyerTotalAmountNzd,
      buyerFeeAmountNzd: orders[index].buyerFeeAmountNzd,
    );
    orders[index] = refundedOrder;
    return refundedOrder;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusLocations Autocomplete Tests', () {
    test('search returns matching campus and suburb locations', () {
      final libraryResults = CampusLocations.search('Library');
      expect(
        libraryResults.any((loc) => loc.contains('General Library')),
        isTrue,
      );

      final quadResults = CampusLocations.search('Quad');
      expect(quadResults.any((loc) => loc.contains('Quad')), isTrue);

      final emptyResults = CampusLocations.search('');
      expect(emptyResults.length, 8);

      final centralResults = CampusLocations.search('Auckland Central');
      expect(centralResults.any((loc) => loc == 'Auckland Central'), isTrue);
    });
  });

  group('Order Refund & Invoice UI Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'test-token',
        'current_user':
            '{"id":"seller-1","displayName":"Alice Seller","trustScore":98}',
      });
    });

    testWidgets(
      'Renders Invoice and Refund buttons for seller on paid order, opens Invoice sheet',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final paidOrder = OrderModel(
          id: 'order-101',
          orderNumber: 'ORD-2026-101',
          status: 'paid',
          role: 'selling',
          itemId: 'item-101',
          item: const OrderItemInfo(
            id: 'item-101',
            title: 'Sony WH-1000XM4 Noise Canceling Headphones',
            priceNzd: '280.00',
            imageUrl: '',
            condition: 'Like New',
            category: 'Electronics',
          ),
          counterparty: const OrderCounterparty(
            id: 'buyer-202',
            displayName: 'Bob Buyer',
            role: 'buyer',
          ),
          createdAt: DateTime.now().subtract(const Duration(hours: 50)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 50)),
          paidAt: DateTime.now().subtract(const Duration(hours: 50)),
          itemAmountNzd: '280.00',
          buyerTotalAmountNzd: '294.00',
          buyerFeeAmountNzd: '14.00',
        );

        final mockRepo = _MockOrderRepo([paidOrder]);
        final orderProvider = OrderProvider(repository: mockRepo);
        final authProvider = AuthProvider(userRepository: MockUserRepository());

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: orderProvider),
              ChangeNotifierProvider.value(value: authProvider),
            ],
            child: const MaterialApp(
              home: UserOrdersScreen(initialTabIndex: 1), // Sales Orders tab
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify 48-Hour reminder banner appears for unconfirmed meetup after 2 days
        expect(
          find.textContaining('No meetup agreed after 2 days'),
          findsOneWidget,
        );

        // 2. Verify Invoice button appears and is clickable
        final invoiceBtn = find.byKey(const Key('invoice_btn_order-101'));
        expect(invoiceBtn, findsOneWidget);

        await tester.tap(invoiceBtn);
        await tester.pumpAndSettle();

        // Verify invoice sheet contents
        expect(find.text('Payment Invoice'), findsOneWidget);
        expect(find.text('PAID'), findsWidgets);
        expect(find.text('INV-ORD-2026-101'), findsOneWidget);
        expect(find.text('\$280.00 NZD'), findsWidgets);
        expect(find.text('\$294.00 NZD'), findsOneWidget);
        expect(
          find.textContaining('KiwiShare Escrow Protection Guarantee'),
          findsOneWidget,
        );

        // Close invoice sheet
        await tester.tap(find.text('Close Invoice'));
        await tester.pumpAndSettle();

        // 3. Verify Refund Order button
        final refundBtn = find.byKey(const Key('refund_btn_order-101'));
        expect(refundBtn, findsOneWidget);

        await tester.tap(refundBtn);
        await tester.pumpAndSettle();

        // Dialog opens
        expect(find.text('Confirm Refund'), findsOneWidget);
        expect(find.text('Process Refund'), findsOneWidget);

        // Confirm refund
        await tester.tap(find.text('Process Refund'));
        await tester.pumpAndSettle();

        expect(mockRepo.refundCalled, isTrue);
      },
    );
  });
}
