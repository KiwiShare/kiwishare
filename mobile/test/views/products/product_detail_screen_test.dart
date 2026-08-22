import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/products/product_detail_screen.dart';
import 'package:provider/provider.dart';

Widget _productDetailApp({
  required ItemModel? item,
  required WatchlistProvider watchlistProvider,
}) {
  return MultiProvider(
    providers: [ChangeNotifierProvider.value(value: watchlistProvider)],
    child: MaterialApp(
      theme: buildKiwiShareTheme(),
      home: ProductDetailScreen(item: item),
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
}
