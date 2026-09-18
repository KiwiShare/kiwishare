import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/order_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/order_provider.dart';
import 'package:kiwishare/repositories/order_repository.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/views/profile/user_orders_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOrderRepository implements OrderRepository {
  final List<OrderModel> mockOrders;
  _FakeOrderRepository(this.mockOrders);

  @override
  Future<List<OrderModel>> fetchMyOrders({
    required String token,
    String? type,
    String? status,
  }) async {
    return mockOrders;
  }

  @override
  Future<OrderModel> fetchOrderDetails({
    required String orderId,
    required String token,
  }) async {
    return mockOrders.firstWhere((o) => o.id == orderId);
  }

  @override
  Future<OrderModel> createOrGetOrder({
    required String itemId,
    required String token,
  }) async {
    return mockOrders.first;
  }

  @override
  Future<OrderModel> refundOrder({
    required String orderId,
    required String token,
    String? reason,
  }) async {
    return mockOrders.firstWhere((o) => o.id == orderId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'UserOrdersScreen renders long item info and multiple actions without overflow',
    (tester) async {
      // Test on a narrow screen (width: 320, height: 700) to stress test overflow prevention
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'jwt_token': 'test-token',
        'current_user': '{"id":"user-1","displayName":"Riley","trustScore":95}',
      });

      final testOrder = OrderModel(
        id: 'order_1234567890',
        orderNumber: 'ORD-2026-999988887777',
        status: 'pending_payment',
        role: 'buying',
        itemId: 'item_1',
        item: const OrderItemInfo(
          id: 'item_1',
          title:
              'Extremely Long Product Title That Spans Multiple Lines And Needs To Truncate Gracefully Without Breaking Layout Or Exceeding Width Bounds',
          priceNzd: '250.00',
          imageUrl: '',
        ),
        counterparty: const OrderCounterparty(
          id: 'seller_1',
          displayName:
              'Seller With An Exceptionally Long Display Name Or Company Profile Name',
          role: 'seller',
        ),
        meeting: OrderMeetingInfo(
          scheduledAt: DateTime(2026, 9, 20, 14, 30),
          locationName:
              'University of Auckland Student Hub, Building 423, Level 2 Conference Room B, Corner of Symonds St and Alfred St',
          latitude: -36.8523,
          longitude: 174.7687,
          proposalStatus: 'accepted',
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final auth = AuthProvider(userRepository: MockUserRepository());
      final orderProvider = OrderProvider(
        repository: _FakeOrderRepository([testOrder]),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: const MaterialApp(home: UserOrdersScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify order rendered cleanly
      expect(find.textContaining('ORD-2026-999988887777'), findsOneWidget);
      expect(find.text('Pending Payment'), findsOneWidget);
      expect(find.text('\$250.00 NZD'), findsOneWidget);

      // Verify action buttons present
      expect(
        find.byKey(const Key('pay_now_btn_order_1234567890')),
        findsOneWidget,
      );
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('View Item'), findsOneWidget);

      // Verify zero RenderFlex overflow errors occurred
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'UserOrdersScreen distinguishes Paid, To Pay, and Completed orders with tabs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'jwt_token': 'test-token',
        'current_user': '{"id":"user-1","displayName":"Riley","trustScore":95}',
      });

      final unpaidOrder = OrderModel(
        id: 'order_unpaid',
        orderNumber: 'ORD-UNPAID-1',
        status: 'pending_payment',
        role: 'buying',
        itemId: 'item_1',
        item: const OrderItemInfo(
          id: 'item_1',
          title: 'Calculus Textbook',
          priceNzd: '40.00',
          imageUrl: '',
        ),
        counterparty: const OrderCounterparty(
          id: 'seller_1',
          displayName: 'Sam',
          role: 'seller',
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final paidOrder = OrderModel(
        id: 'order_paid',
        orderNumber: 'ORD-PAID-2',
        status: 'paid',
        role: 'buying',
        paidAt: DateTime.now(),
        itemId: 'item_2',
        item: const OrderItemInfo(
          id: 'item_2',
          title: 'Desk Lamp',
          priceNzd: '20.00',
          imageUrl: '',
        ),
        counterparty: const OrderCounterparty(
          id: 'seller_2',
          displayName: 'Alex',
          role: 'seller',
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final completedOrder = OrderModel(
        id: 'order_completed',
        orderNumber: 'ORD-COMPLETED-3',
        status: 'completed',
        role: 'buying',
        paidAt: DateTime.now().subtract(const Duration(days: 2)),
        completedAt: DateTime.now().subtract(const Duration(days: 1)),
        itemId: 'item_3',
        item: const OrderItemInfo(
          id: 'item_3',
          title: 'Coffee Press',
          priceNzd: '15.00',
          imageUrl: '',
        ),
        counterparty: const OrderCounterparty(
          id: 'seller_3',
          displayName: 'Emma',
          role: 'seller',
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final auth = AuthProvider(userRepository: MockUserRepository());
      final orderProvider = OrderProvider(
        repository: _FakeOrderRepository([
          unpaidOrder,
          paidOrder,
          completedOrder,
        ]),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<OrderProvider>.value(value: orderProvider),
          ],
          child: const MaterialApp(home: UserOrdersScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Default 'All' filter shows all 3
      expect(find.text('Calculus Textbook'), findsOneWidget);
      expect(find.text('Desk Lamp'), findsOneWidget);
      expect(find.text('Coffee Press'), findsOneWidget);
      expect(find.text('Pending Payment'), findsOneWidget);
      expect(find.text('Paid · Awaiting Handover'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);

      // Paid order should NOT have 'Pay Now' button
      expect(find.byKey(const Key('pay_now_btn_order_paid')), findsNothing);

      // Tap 'To Pay' filter chip
      await tester.tap(find.byKey(const Key('filter_chip_to_pay')));
      await tester.pumpAndSettle();
      expect(find.text('Calculus Textbook'), findsOneWidget);
      expect(find.text('Desk Lamp'), findsNothing);
      expect(find.text('Coffee Press'), findsNothing);

      // Tap 'Paid (Pickup Pending)' filter chip
      final paidPickupChip = find.byKey(const Key('filter_chip_paid_pickup'));
      await tester.ensureVisible(paidPickupChip);
      await tester.tap(paidPickupChip);
      await tester.pumpAndSettle();
      expect(find.text('Calculus Textbook'), findsNothing);
      expect(find.text('Desk Lamp'), findsOneWidget);
      expect(find.text('Coffee Press'), findsNothing);

      // Tap 'Completed' filter chip
      final completedChip = find.byKey(const Key('filter_chip_completed'));
      await tester.ensureVisible(completedChip);
      await tester.tap(completedChip);
      await tester.pumpAndSettle();
      expect(find.text('Calculus Textbook'), findsNothing);
      expect(find.text('Desk Lamp'), findsNothing);
      expect(find.text('Coffee Press'), findsOneWidget);
    },
  );
}
