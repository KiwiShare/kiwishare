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
    expect(find.text('Watching'), findsOneWidget);
    expect(provider.isWatched('64f000000000000000000001'), isFalse);

    // 2. Tap bottom "Watch Item" button
    await tester.tap(find.byKey(const Key('detail-watch-action-button')));
    await tester.pumpAndSettle();

    // 3. Status changes to "Watching"
    expect(find.text('Watching'), findsOneWidget);
    expect(provider.isWatched('64f000000000000000000001'), isTrue);
    expect(
      provider.watchlistItems.any((i) => i.id == '64f000000000000000000001'),
      isTrue,
    );
    expect(permissionController.statusCalls, 1);

    // 4. Tap AppBar bookmark button to unwatch
    await tester.tap(find.byKey(const Key('detail-favorite-button')));
    await tester.pumpAndSettle();

    // 5. The label stays fixed; the heart communicates the status.
    expect(find.text('Watching'), findsOneWidget);
    expect(provider.isWatched('64f000000000000000000001'), isFalse);
    expect(permissionController.statusCalls, 1);
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
    await tester.tap(find.byKey(const Key('detail-watch-action-button')));
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
    await tester.tap(find.byKey(const Key('detail-watch-action-button')));
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
      await tester.tap(find.byKey(const Key('detail-watch-action-button')));
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
      await tester.tap(find.byKey(const Key('detail-watch-action-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notification-rationale-enable')));
      await tester.pumpAndSettle();

      expect(provider.isWatched(_detailItem.id), isTrue);
      expect(find.text('Watching'), findsOneWidget);
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
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('detail-message-seller-button')),
    );
    expect(button.onPressed, isNull);
    expect(repository.createCalls, 0);
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

    expect(find.text('Watching'), findsOneWidget);
    expect(find.text('Message seller'), findsOneWidget);
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
  Future<List<ItemModel>> fetchRecommendedItems({int limit = 10}) =>
      throw UnimplementedError();

  @override
  Stream<List<ItemModel>> searchItems({String? query, String? category}) =>
      throw UnimplementedError();
}
