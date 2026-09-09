import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/item_repository.dart';
import 'package:kiwishare/repositories/push_device_repository.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';
import 'package:kiwishare/services/push_notification_service.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/products/product_detail_screen.dart';
import 'package:provider/provider.dart';

import '../support/test_item_repository.dart';

const _itemId = '64f000000000000000000001';

void main() {
  testWidgets(
    'valid watchlist notification routes by item ID and fetches product',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final itemRepository = TestItemRepository(
        items: [
          const ItemModel(
            id: _itemId,
            title: 'Notification Tent',
            priceNzd: '75',
            location: 'Auckland',
            imageUrl: 'https://example.com/tent.jpg',
            isSustainable: true,
            category: 'Camping',
            status: ItemStatus.active,
            ownerId: 'seller-id',
          ),
        ],
      );
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/items/:itemId',
            builder: (_, state) =>
                ProductDetailScreen(itemId: state.pathParameters['itemId']),
          ),
        ],
      );
      addTearDown(router.dispose);

      final messaging = _MessagingClient();
      final service = PushNotificationService(
        messagingClient: messaging,
        deviceRepository: _DeviceRepository(),
        platform: 'android',
        onNavigateToItem: (itemId) => router.go('/items/$itemId'),
      );
      addTearDown(service.dispose);
      addTearDown(messaging.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ItemRepository>.value(value: itemRepository),
            ChangeNotifierProvider(
              create: (_) =>
                  WatchlistProvider(repository: TestWatchlistRepository()),
            ),
          ],
          child: MaterialApp.router(
            theme: buildKiwiShareTheme(),
            routerConfig: router,
          ),
        ),
      );
      await service.activate('jwt-user');

      messaging.opened.add(
        const PushEnvelope(
          data: {
            'type': 'watchlist_price_drop',
            'itemId': _itemId,
            'eventId': 'event-1',
            'oldPrice': '95',
            'newPrice': '75',
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/items/$_itemId');
      expect(find.text('Notification Tent'), findsWidgets);
      expect(find.text(r'$75 NZD'), findsOneWidget);
    },
  );
}

class _DeviceRepository implements PushDeviceRepository {
  @override
  Future<void> registerToken({
    required String token,
    required String platform,
    required String jwtToken,
  }) async {}

  @override
  Future<void> unregisterToken({
    required String token,
    required String jwtToken,
  }) async {}
}

class _MessagingClient implements PushMessagingClient {
  final opened = StreamController<PushEnvelope>.broadcast();

  @override
  Future<String?> getToken() async => null;

  @override
  Future<PushEnvelope?> getInitialMessage() async => null;

  @override
  Stream<PushEnvelope> get onForegroundMessage => const Stream.empty();

  @override
  Stream<PushEnvelope> get onMessageOpened => opened.stream;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<PushPermissionStatus> getPermissionStatus() async =>
      PushPermissionStatus.authorized;

  @override
  Future<PushPermissionStatus> requestPermission() async =>
      PushPermissionStatus.authorized;

  Future<void> dispose() => opened.close();
}
