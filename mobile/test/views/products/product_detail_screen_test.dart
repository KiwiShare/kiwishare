import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/products/product_detail_screen.dart';
import 'package:provider/provider.dart';

import '../../support/fake_chat_repository.dart';

Widget _productDetailApp({
  required ItemModel? item,
  required WatchlistProvider watchlistProvider,
  ChatProvider? chatProvider,
  String? authToken,
  String? currentUserId,
  ValueChanged<ChatConversationModel>? onConversationOpened,
  VoidCallback? onSignInRequired,
  double textScale = 1,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: watchlistProvider),
      if (chatProvider != null)
        ChangeNotifierProvider.value(value: chatProvider),
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
        chatProvider: chatProvider,
        authToken: authToken,
        currentUserId: currentUserId,
        onConversationOpened: onConversationOpened,
        onSignInRequired: onSignInRequired,
      ),
    ),
  );
}

final _detailItem = ItemModel(
  id: 'detail_tent_1',
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
    final provider = WatchlistProvider(repository: repo);

    await tester.pumpWidget(
      _productDetailApp(item: _detailItem, watchlistProvider: provider),
    );
    await tester.pumpAndSettle();

    // 1. Initial State: not watched
    expect(find.text('Eco 4-Person Camping Tent'), findsOneWidget);
    expect(find.text('\$95 NZD'), findsOneWidget);
    expect(find.text('Watch Item'), findsOneWidget);
    expect(provider.isWatched('detail_tent_1'), isFalse);

    // 2. Tap bottom "Watch Item" button
    await tester.tap(find.byKey(const Key('detail-watch-action-button')));
    await tester.pumpAndSettle();

    // 3. Status changes to "Watching"
    expect(find.text('Watching'), findsOneWidget);
    expect(provider.isWatched('detail_tent_1'), isTrue);
    expect(provider.watchlistItems.any((i) => i.id == 'detail_tent_1'), isTrue);

    // 4. Tap AppBar bookmark button to unwatch
    await tester.tap(find.byKey(const Key('detail-favorite-button')));
    await tester.pumpAndSettle();

    // 5. Status changes back to "Watch Item"
    expect(find.text('Watch Item'), findsOneWidget);
    expect(provider.isWatched('detail_tent_1'), isFalse);
  });

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

    expect(find.text('Report a safety issue'), findsOneWidget);
    expect(find.text('What happened?'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
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

    expect(find.text('Watch Item'), findsOneWidget);
    expect(find.text('Message seller'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
