import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/watchlist/watchlist_screen.dart';
import 'package:provider/provider.dart';

Widget _watchlistApp({
  required WatchlistRepository repository,
  ValueChanged<ItemModel>? onOpenItem,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => WatchlistProvider(repository: repository),
      ),
    ],
    child: MaterialApp(
      theme: buildKiwiShareTheme(),
      home: WatchlistScreen(onOpenItem: onOpenItem),
    ),
  );
}

final _testItem1 = ItemModel(
  id: 'item_plant_1',
  title: 'Monstera Deliciosa',
  priceNzd: '35',
  location: 'Ponsonby, Auckland',
  imageUrl: 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b',
  isSustainable: true,
  category: 'Plants',
  description: 'Healthy indoor plant',
  status: ItemStatus.active,
  ownerId: 'seller_1',
);

final _testItem2 = ItemModel(
  id: 'item_chair_2',
  title: 'Vintage Oak Armchair',
  priceNzd: '120',
  location: 'Newmarket, Auckland',
  imageUrl: 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7',
  isSustainable: false,
  category: 'Furniture',
  description: 'Mid-century armchair',
  status: ItemStatus.reserved,
  ownerId: 'seller_2',
);

void main() {
  testWidgets('Watchlist displays empty state when no items are watched', (
    tester,
  ) async {
    final repo = TestWatchlistRepository();
    await tester.pumpWidget(_watchlistApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(find.text('Your watchlist is empty'), findsOneWidget);
    expect(find.byKey(const Key('watchlist-explore-button')), findsOneWidget);
  });

  testWidgets('Watchlist renders watched items and allows removing an item', (
    tester,
  ) async {
    final repo = TestWatchlistRepository(
      initialIds: {'item_plant_1', 'item_chair_2'},
      initialItems: [_testItem1, _testItem2],
    );

    ItemModel? openedItem;
    await tester.pumpWidget(
      _watchlistApp(repository: repo, onOpenItem: (item) => openedItem = item),
    );
    await tester.pumpAndSettle();

    // 1. Check header and count
    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);

    // 2. Check items rendered
    expect(find.text('Monstera Deliciosa'), findsOneWidget);
    expect(find.text('\$35 NZD'), findsOneWidget);
    expect(find.text('Vintage Oak Armchair'), findsOneWidget);
    expect(find.text('\$120 NZD'), findsOneWidget);
    expect(find.text('Reserved'), findsOneWidget);

    // 3. Tap card opens item details
    await tester.tap(find.text('Monstera Deliciosa'));
    await tester.pump();
    expect(openedItem, isNotNull);
    expect(openedItem!.id, 'item_plant_1');

    // 4. Remove item using unwatch button
    await tester.tap(find.byKey(const Key('watchlist-remove-item_plant_1')));
    await tester.pumpAndSettle();

    // 5. Verify item removed and count updated to 1
    expect(find.text('Monstera Deliciosa'), findsNothing);
    expect(find.text('Vintage Oak Armchair'), findsOneWidget);
    expect(find.text('1 items'), findsOneWidget);
  });

  testWidgets('Watchlist filters items by search query and allows clearing', (
    tester,
  ) async {
    final repo = TestWatchlistRepository(
      initialIds: {'item_plant_1', 'item_chair_2'},
      initialItems: [_testItem1, _testItem2],
    );

    await tester.pumpWidget(_watchlistApp(repository: repo));
    await tester.pumpAndSettle();

    expect(find.text('Monstera Deliciosa'), findsOneWidget);
    expect(find.text('Vintage Oak Armchair'), findsOneWidget);

    // Search for "chair"
    await tester.enterText(
      find.byKey(const Key('watchlist-search-field')),
      'chair',
    );
    await tester.pumpAndSettle();

    expect(find.text('Monstera Deliciosa'), findsNothing);
    expect(find.text('Vintage Oak Armchair'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);

    // Search for non-matching query
    await tester.enterText(
      find.byKey(const Key('watchlist-search-field')),
      'nonexistent item xyz',
    );
    await tester.pumpAndSettle();

    expect(find.text('No matching items found'), findsOneWidget);
    expect(find.byKey(const Key('watchlist-reset-filters-button')), findsOneWidget);

    // Reset filters
    await tester.tap(find.byKey(const Key('watchlist-reset-filters-button')));
    await tester.pumpAndSettle();

    expect(find.text('Monstera Deliciosa'), findsOneWidget);
    expect(find.text('Vintage Oak Armchair'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
  });

  testWidgets('Watchlist filters items by status chips', (tester) async {
    final repo = TestWatchlistRepository(
      initialIds: {'item_plant_1', 'item_chair_2'},
      initialItems: [_testItem1, _testItem2],
    );

    await tester.pumpWidget(_watchlistApp(repository: repo));
    await tester.pumpAndSettle();

    // Tap "Available" chip (_testItem1 is active, _testItem2 is reserved)
    await tester.tap(find.byKey(const Key('watchlist-filter-available')));
    await tester.pumpAndSettle();

    expect(find.text('Monstera Deliciosa'), findsOneWidget);
    expect(find.text('Vintage Oak Armchair'), findsNothing);
    expect(find.text('1 of 2'), findsOneWidget);

    // Tap "Reserved" chip
    await tester.tap(find.byKey(const Key('watchlist-filter-reserved')));
    await tester.pumpAndSettle();

    expect(find.text('Monstera Deliciosa'), findsNothing);
    expect(find.text('Vintage Oak Armchair'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);

    // Tap "All" chip
    await tester.tap(find.byKey(const Key('watchlist-filter-all')));
    await tester.pumpAndSettle();

    expect(find.text('Monstera Deliciosa'), findsOneWidget);
    expect(find.text('Vintage Oak Armchair'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
  });
}
