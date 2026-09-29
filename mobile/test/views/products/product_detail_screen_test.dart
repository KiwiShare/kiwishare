import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/discovery_options_model.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';
import 'package:kiwishare/services/notification_permission_coordinator.dart';
import 'package:kiwishare/services/push_notification_service.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/products/product_detail_screen.dart';
import 'package:kiwishare/views/profile/report_screen.dart';
import 'package:provider/provider.dart';

import 'package:kiwishare/repositories/item_repository.dart';
import '../../support/fake_chat_repository.dart';
import '../../support/test_item_repository.dart';

Widget _productDetailApp({
  ItemModel? item,
  String? itemId,
  ItemRepository? itemRepository,
  required WatchlistProvider watchlistProvider,
  ChatProvider? chatProvider,
  String? authToken,
  String? currentUserId,
  ValueChanged<ChatConversationModel>? onConversationOpened,
  VoidCallback? onSignInRequired,
  ValueChanged<ItemModel>? onSimilarItemTap,
  NotificationPermissionCoordinator? permissionCoordinator,
  double textScale = 1,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: watchlistProvider),
      if (chatProvider != null)
        ChangeNotifierProvider.value(value: chatProvider),
      if (itemRepository != null)
        Provider<ItemRepository>.value(value: itemRepository),
    ],
    child: MaterialApp(
      theme: buildKiwiShareTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ProductDetailScreen(
        item: item,
        itemId: itemId,
        itemRepository: itemRepository,
        chatProvider: chatProvider,
        authToken: authToken,
        currentUserId: currentUserId,
        onConversationOpened: onConversationOpened,
        onSignInRequired: onSignInRequired,
        onSimilarItemTap: onSimilarItemTap,
        permissionCoordinator: permissionCoordinator,
      ),
    ),
  );
}

final _detailItem = ItemModel(
  id: '64f000000000000000000001',
  title: 'Eco 4-Person Camping Tent',
  priceNzd: '95',
  location: 'Takapuna, Auckland',
  imageUrl: 'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4',
  isSustainable: true,
  category: 'Camping',
  description: 'Waterproof family camping tent with eco materials.',
  status: ItemStatus.active,
  ownerId: 'seller_3',
);

void main() {
  testWidgets('product images open a swipeable fullscreen gallery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final item = _detailItem.copyWith(
      images: const [
        'https://example.com/one.jpg',
        'https://example.com/two.jpg',
      ],
    );
    await tester.pumpWidget(
      _productDetailApp(
        item: item,
        watchlistProvider: WatchlistProvider(
          repository: TestWatchlistRepository(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('detail-image-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-fullscreen-gallery')), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('detail-fullscreen-gallery')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('listing location opens an embedded Google Map', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _productDetailApp(
        item: _detailItem,
        watchlistProvider: WatchlistProvider(
          repository: TestWatchlistRepository(),
        ),
      ),
    );
    await tester.pump();

    final locationButton = find
        .byKey(const Key('detail-location-map-button'))
        .first;
    await tester.scrollUntilVisible(
      locationButton,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(locationButton);
    await tester.tap(locationButton);
    await tester.pumpAndSettle();

    expect(find.text('Listing location'), findsOneWidget);
    expect(find.byKey(const Key('product-location-map')), findsOneWidget);
    expect(find.text('Directions'), findsOneWidget);
  });

  testWidgets('vehicle listings render vehicle-specific attributes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final car = _detailItem.copyWith(
      title: '2018 Toyota Corolla Hybrid',
      category: 'Cars & Vehicles',
      attributes: const {
        'make': 'Toyota',
        'model': 'Corolla',
        'year': '2018',
        'mileageKm': '85000',
        'fuelType': 'Hybrid',
        'transmission': 'Automatic',
        'bodyType': 'Hatchback',
      },
    );

    await tester.pumpWidget(
      _productDetailApp(
        item: car,
        watchlistProvider: WatchlistProvider(
          repository: TestWatchlistRepository(),
        ),
      ),
    );
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;
    for (
      var attempt = 0;
      attempt < 8 && find.text('Vehicle details').evaluate().isEmpty;
      attempt += 1
    ) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(find.text('Vehicle details'), findsOneWidget);
    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Corolla'), findsOneWidget);
    expect(find.text('85000 km'), findsOneWidget);
    expect(find.text('Hybrid'), findsOneWidget);
    expect(find.text('Automatic'), findsOneWidget);
  });

  testWidgets('ProductDetailScreen caps public seller trust display at 200+', (
    tester,
  ) async {
    final item = ItemModel(
      id: _detailItem.id,
      title: _detailItem.title,
      priceNzd: _detailItem.priceNzd,
      location: _detailItem.location,
      imageUrl: '',
      isSustainable: _detailItem.isSustainable,
      category: _detailItem.category,
      status: _detailItem.status,
      description: _detailItem.description,
      ownerId: _detailItem.ownerId,
      seller: const SellerInfo(
        id: 'seller_3',
        displayName: 'High Trust Seller',
        trustScore: 205,
      ),
    );
    await tester.pumpWidget(
      _productDetailApp(
        item: item,
        watchlistProvider: WatchlistProvider(
          repository: TestWatchlistRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Trust Score'), 300);

    expect(find.text('200+'), findsOneWidget);
    expect(find.textContaining('/100'), findsNothing);
  });

  testWidgets('ProductDetailScreen allows watching and unwatching item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = TestWatchlistRepository();
    final provider = WatchlistProvider(
      repository: repo,
      initialToken: 'buyer-token',
    );
    final permissionController = _FakePermissionController()
      ..status = PushPermissionStatus.denied;

    await tester.pumpWidget(
      _productDetailApp(
        item: _detailItem,
        watchlistProvider: provider,
        authToken: 'buyer-token',
        permissionCoordinator: NotificationPermissionCoordinator(
          permissionController: permissionController,
          storage: _MemoryPermissionStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Initial State: not watched
    expect(find.text('Eco 4-Person Camping Tent'), findsWidgets);
    expect(find.text('\$95 NZD'), findsOneWidget);
    expect(find.byKey(const Key('detail-watch-action-button')), findsNothing);
    expect(provider.isWatched('64f000000000000000000001'), isFalse);

    // 2. Use the AppBar heart to add the item.
    await tester.tap(find.byKey(const Key('detail-favorite-button')));
    await tester.pumpAndSettle();

    // 3. Watchlist state updates without a duplicate bottom action.
    expect(find.byKey(const Key('detail-watch-action-button')), findsNothing);
    expect(provider.isWatched('64f000000000000000000001'), isTrue);
    expect(
      provider.watchlistItems.any((i) => i.id == '64f000000000000000000001'),
      isTrue,
    );
    expect(permissionController.statusCalls, 1);

    // 4. Tap AppBar heart button again to unwatch
    await tester.tap(find.byKey(const Key('detail-favorite-button')));
    await tester.pumpAndSettle();

    // 5. Bottom Watchlist action remains absent.
    expect(find.byKey(const Key('detail-watch-action-button')), findsNothing);
    expect(provider.isWatched('64f000000000000000000001'), isFalse);
    expect(permissionController.statusCalls, 1);
  });

  testWidgets('own listing shows a friendly Watchlist message', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = WatchlistProvider(
      repository: TestWatchlistRepository(),
      initialToken: 'seller-token',
    );

    await tester.pumpWidget(
      _productDetailApp(
        item: _detailItem,
        watchlistProvider: provider,
        authToken: 'seller-token',
        currentUserId: _detailItem.ownerId,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-watch-action-button')), findsNothing);
    await tester.tap(find.byKey(const Key('detail-favorite-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('You can’t add your own listing to your Watchlist.'),
      findsOneWidget,
    );
    expect(provider.isWatched(_detailItem.id), isFalse);
  });

  testWidgets('failed Watchlist add does not offer notification permission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final permissionController = _FakePermissionController();
    final provider = WatchlistProvider(
      repository: _ResultWatchlistRepository(addResult: false),
      initialToken: 'buyer-token',
    );

    await tester.pumpWidget(
      _productDetailApp(
        item: _detailItem,
        watchlistProvider: provider,
        authToken: 'buyer-token',
        permissionCoordinator: NotificationPermissionCoordinator(
          permissionController: permissionController,
          storage: _MemoryPermissionStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-favorite-button')));
    await tester.pumpAndSettle();

    expect(provider.isWatched(_detailItem.id), isFalse);
    expect(permissionController.statusCalls, 0);
  });

  testWidgets('unauthenticated Watchlist add does not offer permission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final permissionController = _FakePermissionController();
    final provider = WatchlistProvider(repository: TestWatchlistRepository());

    await tester.pumpWidget(
      _productDetailApp(
        item: _detailItem,
        watchlistProvider: provider,
        authToken: '',
        permissionCoordinator: NotificationPermissionCoordinator(
          permissionController: permissionController,
          storage: _MemoryPermissionStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-favorite-button')));
    await tester.pumpAndSettle();

    expect(permissionController.statusCalls, 0);
  });

  testWidgets(
    'route disposal during Watchlist add does not show permission UI',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _DelayedAddWatchlistRepository();
      final permissionController = _FakePermissionController();
      final provider = WatchlistProvider(
        repository: repository,
        initialToken: 'buyer-token',
      );

      await tester.pumpWidget(
        _productDetailApp(
          item: _detailItem,
          watchlistProvider: provider,
          authToken: 'buyer-token',
          permissionCoordinator: NotificationPermissionCoordinator(
            permissionController: permissionController,
            storage: _MemoryPermissionStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-favorite-button')));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Text('Different route')));
      repository.addCompleter.complete(true);
      await tester.pumpAndSettle();

      expect(permissionController.statusCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'permission failure does not roll back a successful Watchlist add',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final permissionController = _FakePermissionController()
        ..failRequest = true;
      final provider = WatchlistProvider(
        repository: TestWatchlistRepository(),
        initialToken: 'buyer-token',
      );

      await tester.pumpWidget(
        _productDetailApp(
          item: _detailItem,
          watchlistProvider: provider,
          authToken: 'buyer-token',
          permissionCoordinator: NotificationPermissionCoordinator(
            permissionController: permissionController,
            storage: _MemoryPermissionStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-favorite-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notification-rationale-enable')));
      await tester.pumpAndSettle();

      expect(provider.isWatched(_detailItem.id), isTrue);
      expect(find.byKey(const Key('detail-watch-action-button')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ProductDetailScreen renders unavailable view for null item', (
    tester,
  ) async {
    final repo = TestWatchlistRepository();
    final provider = WatchlistProvider(repository: repo);

    await tester.pumpWidget(
      _productDetailApp(item: null, watchlistProvider: provider),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product unavailable'), findsOneWidget);
  });

  testWidgets('Product detail opens the existing report form', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = WatchlistProvider(repository: TestWatchlistRepository());

    await tester.pumpWidget(
      _productDetailApp(item: _detailItem, watchlistProvider: provider),
    );
    await tester.pumpAndSettle();

    final reportButton = find.byKey(const Key('detail-report-listing-button'));
    await tester.ensureVisible(reportButton);
    await tester.pumpAndSettle();

    expect(reportButton, findsOneWidget);
    await tester.tap(reportButton);
    await tester.pumpAndSettle();

    final reportScreen = tester.widget<ReportScreen>(find.byType(ReportScreen));
    expect(reportScreen.reportContext.targetImageUrl, _detailItem.imageUrl);
    expect(find.text('Report listing'), findsWidgets);
    expect(find.text(_detailItem.title), findsWidgets);
    expect(find.text('What happened?'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.byKey(const Key('report_reason_field')));
    await tester.pumpAndSettle();
    expect(find.text('Misleading information'), findsOneWidget);
  });

  testWidgets('Message seller creates an item conversation and opens it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());
    final repository = FakeChatRepository(
      conversations: [
        testConversation(id: 'detail-chat', itemTitle: _detailItem.title),
      ],
    );
    final chat = ChatProvider(repository: repository);
    ChatConversationModel? opened;

    await tester.pumpWidget(
      _productDetailApp(
        item: _detailItem,
        watchlistProvider: watchlist,
        chatProvider: chat,
        authToken: 'buyer-token',
        currentUserId: 'buyer-1',
        onConversationOpened: (value) => opened = value,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detail-message-seller-button')));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
    expect(repository.createdItemIds, [_detailItem.id]);
    expect(opened?.id, 'detail-chat');
  });

  testWidgets('Message seller asks a signed-out member to authenticate', (
    tester,
  ) async {
    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());
    final chat = ChatProvider(
      repository: FakeChatRepository(
        conversations: [testConversation(id: 'detail-chat')],
      ),
    );
    var signInRequests = 0;

    await tester.pumpWidget(
      _productDetailApp(
        item: _detailItem,
        watchlistProvider: watchlist,
        chatProvider: chat,
        authToken: '',
        currentUserId: '',
        onSignInRequired: () => signInRequests += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detail-message-seller-button')));
    await tester.pump();

    expect(signInRequests, 1);
  });

  testWidgets('Message seller is unavailable on the member own listing', (
    tester,
  ) async {
    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());
    final repository = FakeChatRepository(
      conversations: [testConversation(id: 'detail-chat')],
    );

    await tester.pumpWidget(
      _productDetailApp(
        item: _detailItem,
        watchlistProvider: watchlist,
        chatProvider: ChatProvider(repository: repository),
        authToken: 'seller-token',
        currentUserId: _detailItem.ownerId,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your listing'), findsOneWidget);
    expect(find.byKey(const Key('detail-message-seller-button')), findsNothing);
    expect(find.byKey(const Key('detail-edit-listing-button')), findsOneWidget);
    expect(repository.createCalls, 0);
  });

  testWidgets('sold owner listing is locked from editing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final soldItem = ItemModel(
      id: _detailItem.id,
      title: _detailItem.title,
      priceNzd: _detailItem.priceNzd,
      location: _detailItem.location,
      imageUrl: _detailItem.imageUrl,
      isSustainable: _detailItem.isSustainable,
      category: _detailItem.category,
      description: _detailItem.description,
      status: ItemStatus.sold,
      ownerId: _detailItem.ownerId,
    );

    await tester.pumpWidget(
      _productDetailApp(
        item: soldItem,
        watchlistProvider: WatchlistProvider(
          repository: TestWatchlistRepository(),
        ),
        currentUserId: soldItem.ownerId,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('detail-sold-listing-locked-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('detail-edit-listing-button')), findsNothing);
    expect(find.byTooltip('Sold — refund/cancel first'), findsOneWidget);
  });

  testWidgets('Message seller explains a recoverable service failure', (
    tester,
  ) async {
    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());
    final repository = FakeChatRepository(
      conversations: [testConversation(id: 'detail-chat')],
    )..createError = const ChatRepositoryException('Chat is taking a break.');

    await tester.pumpWidget(
      _productDetailApp(
        item: _detailItem,
        watchlistProvider: watchlist,
        chatProvider: ChatProvider(repository: repository),
        authToken: 'buyer-token',
        currentUserId: 'buyer-1',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detail-message-seller-button')));
    await tester.pumpAndSettle();

    expect(find.text('Chat is taking a break.'), findsOneWidget);
  });

  testWidgets('Product actions support 200 percent system text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());
    final chat = ChatProvider(
      repository: FakeChatRepository(
        conversations: [testConversation(id: 'detail-chat')],
      ),
    );

    await tester.pumpWidget(
      _productDetailApp(
        item: _detailItem,
        watchlistProvider: watchlist,
        chatProvider: chat,
        authToken: 'buyer-token',
        currentUserId: 'buyer-1',
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail-watch-action-button')), findsNothing);
    expect(
      find.byKey(const Key('detail-message-seller-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ProductDetailScreen fetches and renders by itemId when item is null',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final watchlist = WatchlistProvider(
        repository: TestWatchlistRepository(),
      );
      final itemRepo = TestItemRepository(items: [_detailItem]);

      await tester.pumpWidget(
        _productDetailApp(
          itemId: '64f000000000000000000001',
          itemRepository: itemRepo,
          watchlistProvider: watchlist,
        ),
      );

      // Initial pump shows loading
      expect(find.byKey(const Key('product-detail-loading')), findsOneWidget);

      // Settle loads the item
      await tester.pumpAndSettle();

      expect(find.text('Eco 4-Person Camping Tent'), findsWidgets);
      expect(find.text('\$95 NZD'), findsOneWidget);
      expect(find.byKey(const Key('product-detail-loading')), findsNothing);
    },
  );

  testWidgets(
    'ProductDetailScreen displays not found state when itemId does not exist',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final watchlist = WatchlistProvider(
        repository: TestWatchlistRepository(),
      );
      final itemRepo = TestItemRepository(items: [_detailItem]);

      await tester.pumpWidget(
        _productDetailApp(
          itemId: '64f000000000000000000099',
          itemRepository: itemRepo,
          watchlistProvider: watchlist,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Product unavailable'), findsOneWidget);
      expect(
        find.text('Item not found or no longer available.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('ProductDetailScreen handles malformed or empty itemId safely', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());
    final itemRepo = TestItemRepository(items: [_detailItem]);

    await tester.pumpWidget(
      _productDetailApp(
        itemId: '   ',
        itemRepository: itemRepo,
        watchlistProvider: watchlist,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product unavailable'), findsOneWidget);
    expect(find.text('The item link is invalid.'), findsOneWidget);
  });

  testWidgets(
    'ProductDetailScreen displays network error and retries successfully',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final watchlist = WatchlistProvider(
        repository: TestWatchlistRepository(),
      );
      var failFetch = true;

      final mockRepo = _FailingItemRepository(
        onFetch: (id) async {
          if (failFetch) throw Exception('Network error');
          return _detailItem;
        },
      );

      await tester.pumpWidget(
        _productDetailApp(
          itemId: '64f000000000000000000001',
          itemRepository: mockRepo,
          watchlistProvider: watchlist,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Product unavailable'), findsOneWidget);
      expect(
        find.text(
          'Unable to load item details. Please check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('product-detail-retry-button')),
        findsOneWidget,
      );

      // Now fix network and tap retry
      failFetch = false;
      await tester.tap(find.byKey(const Key('product-detail-retry-button')));
      await tester.pumpAndSettle();

      expect(find.text('Eco 4-Person Camping Tent'), findsWidgets);
      expect(find.text('\$95 NZD'), findsOneWidget);
    },
  );

  testWidgets(
    'ProductDetailScreen renders similar items section and handles tapping recommendation',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = TestItemRepository();
      final watchlistRepo = TestWatchlistRepository();
      final watchlistProvider = WatchlistProvider(repository: watchlistRepo);
      ItemModel? tappedItem;

      await tester.pumpWidget(
        _productDetailApp(
          item: _detailItem,
          itemRepository: repo,
          watchlistProvider: watchlistProvider,
          onSimilarItemTap: (item) => tappedItem = item,
        ),
      );
      await tester.pumpAndSettle();

      // Verify the Similar Items section header is rendered
      expect(find.text('Similar Items'), findsOneWidget);
      expect(
        find.byKey(const Key('detail-similar-items-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('detail-similar-items-list')),
        findsOneWidget,
      );

      // Verify similar items from the Camping category are shown (Tent - 2 Person)
      expect(find.text('Tent - 2 Person'), findsOneWidget);
      expect(find.text('\$65 NZD'), findsOneWidget);

      // Tap on the similar item card
      await tester.tap(find.byKey(const Key('similar-item-item_4')));
      await tester.pumpAndSettle();

      expect(tappedItem, isNotNull);
      expect(tappedItem!.id, 'item_4');
      expect(tappedItem!.title, 'Tent - 2 Person');
    },
  );
}

class _FakePermissionController implements PushPermissionController {
  @override
  int? activeSessionGeneration = 1;
  @override
  String? activeUserId = 'buyer-1';
  PushPermissionStatus status = PushPermissionStatus.notDetermined;
  bool failRequest = false;
  int statusCalls = 0;

  @override
  Future<PushPermissionStatus> getPermissionStatus() async {
    statusCalls += 1;
    return status;
  }

  @override
  Future<PushPermissionStatus> requestPermissionAndSync({
    int? expectedSessionGeneration,
    String? expectedUserId,
  }) async {
    if (failRequest) throw StateError('permission failed');
    return PushPermissionStatus.authorized;
  }

  @override
  Future<PushPermissionStatus> synchronizeIfAuthorized({
    int? expectedSessionGeneration,
    String? expectedUserId,
  }) async => status;
}

class _MemoryPermissionStorage implements NotificationPermissionStorage {
  int? nextEligibleAtMs;

  @override
  Future<int?> getNextEligibleAtMs() async => nextEligibleAtMs;

  @override
  Future<void> setNextEligibleAtMs(int value) async => nextEligibleAtMs = value;

  @override
  Future<void> removeObsoleteDismissal() async {}
}

class _ResultWatchlistRepository extends TestWatchlistRepository {
  _ResultWatchlistRepository({required this.addResult});

  final bool addResult;

  @override
  Future<bool> addToWatchlist(String itemId, {String? token}) async =>
      addResult;
}

class _DelayedAddWatchlistRepository extends TestWatchlistRepository {
  final addCompleter = Completer<bool>();

  @override
  Future<bool> addToWatchlist(String itemId, {String? token}) =>
      addCompleter.future;
}

class _FailingItemRepository implements ItemRepository {
  final Future<ItemModel?> Function(String id) onFetch;

  _FailingItemRepository({required this.onFetch});

  @override
  Future<ItemModel?> fetchItemById(String id) => onFetch(id);

  @override
  Future<DiscoveryOptionsModel> fetchDiscoveryOptions() =>
      throw UnimplementedError();

  @override
  Future<List<ItemModel>> fetchDiscoveryItems(DiscoveryQuery query) =>
      throw UnimplementedError();

  @override
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  }) => throw UnimplementedError();

  @override
  Future<ItemModel> updateItem({
    required String id,
    required String token,
    required Map<String, dynamic> updates,
  }) => throw UnimplementedError();

  @override
  Future<List<ItemModel>> fetchPopularItems() => throw UnimplementedError();

  @override
  Future<List<ItemModel>> fetchFeaturedItems({int limit = 10}) =>
      throw UnimplementedError();

  @override
  Future<List<ItemModel>> fetchRecommendedItems({
    int limit = 10,
    double? latitude,
    double? longitude,
    String? token,
  }) => throw UnimplementedError();

  @override
  Stream<List<ItemModel>> searchItems({String? query, String? category}) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> promoteItem({
    required String id,
    required String token,
  }) => throw UnimplementedError();

  @override
  Future<ItemModel> toggleListingStatus({
    required String id,
    required bool publish,
    required String token,
  }) => throw UnimplementedError();
}
