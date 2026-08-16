import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/favorites_provider.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/listing_provider.dart';
import 'package:kiwishare/repositories/item_repository.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/item_detail/item_detail_page.dart';
import 'package:kiwishare/views/item_detail/item_detail_screen.dart';
import 'package:kiwishare/views/item_detail/item_edit_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const item = ItemModel(
    id: 'detail-item-1',
    title: 'Restored Rimu Desk',
    priceNzd: '135.50',
    location: 'Kingsland, Auckland',
    imageUrl: '',
    isSustainable: true,
    category: 'Furniture',
    status: ItemStatus.active,
    description: 'Restored locally and ready for a new home.',
    condition: 'good',
    negotiable: true,
    ownerId: 'owner-1',
    sellerName: 'Aroha',
    sellerRating: 4.8,
    sellerReviewCount: 12,
  );

  Widget buildDetail({
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return ChangeNotifierProvider(
      create: (_) => FavoritesProvider(),
      child: MaterialApp(
        theme: buildKiwiShareTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: ItemDetailScreen(
            item: item,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
      ),
    );
  }

  testWidgets('displays buyer-readable listing and seller context', (
    tester,
  ) async {
    await tester.pumpWidget(buildDetail());

    expect(find.text('Restored Rimu Desk'), findsOneWidget);
    expect(find.text(r'$135.50 NZD'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Sustainable choice'), findsOneWidget);
    expect(find.text('Negotiable'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
    expect(find.text('Kingsland, Auckland'), findsOneWidget);
    expect(
      find.text('Restored locally and ready for a new home.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('detail_seller_name')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Aroha'), findsOneWidget);
    expect(find.text('4.8 from 12 reviews'), findsOneWidget);
    expect(find.byKey(const Key('detail_edit_button')), findsNothing);
    expect(find.byKey(const Key('detail_delete_button')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows owner controls only when authorized callbacks exist', (
    tester,
  ) async {
    var editTapped = false;
    var deleteTapped = false;
    await tester.pumpWidget(
      buildDetail(
        onEdit: () => editTapped = true,
        onDelete: () => deleteTapped = true,
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('detail_delete_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('detail_edit_button')));
    await tester.tap(find.byKey(const Key('detail_delete_button')));

    expect(editTapped, isTrue);
    expect(deleteTapped, isTrue);
  });

  testWidgets('favorite action updates its accessible state', (tester) async {
    await tester.pumpWidget(buildDetail());

    expect(find.byTooltip('Save item'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail_favorite_button')));
    await tester.pump();
    expect(find.byTooltip('Remove from saved items'), findsOneWidget);
  });

  testWidgets('supports 200 percent text scaling without layout exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildDetail(textScaler: const TextScaler.linear(2)),
    );
    await tester.drag(
      find.byKey(const Key('item_detail_scroll_view')),
      const Offset(0, -600),
    );
    await tester.pump();

    expect(find.text('Restored Rimu Desk'), findsOneWidget);
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: exception is FlutterError
          ? exception.toStringDeep()
          : exception?.toString(),
    );
  });

  testWidgets('detail page renders a safe not-found state', (tester) async {
    final completer = Completer<ItemModel>();
    final repository = _TestItemRepository(fetchResult: completer.future);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(
            create: (_) => ListingProvider(itemRepository: repository),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(userRepository: MockUserRepository()),
          ),
        ],
        child: MaterialApp(
          theme: buildKiwiShareTheme(),
          home: const ItemDetailPage(itemId: 'missing-item'),
        ),
      ),
    );
    completer.completeError(const ItemNotFoundException());
    await tester.pumpAndSettle();

    expect(find.text('Item unavailable'), findsOneWidget);
    expect(find.text('This item is no longer available.'), findsOneWidget);
    expect(find.byKey(const Key('detail_retry_button')), findsNothing);
  });

  testWidgets('detail page exposes loading then fetched content', (
    tester,
  ) async {
    final completer = Completer<ItemModel>();
    final repository = _TestItemRepository(fetchResult: completer.future);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(
            create: (_) => ListingProvider(itemRepository: repository),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(userRepository: MockUserRepository()),
          ),
        ],
        child: MaterialApp(
          theme: buildKiwiShareTheme(),
          home: const ItemDetailPage(itemId: 'detail-item-1'),
        ),
      ),
    );

    expect(find.byKey(const Key('detail_loading_indicator')), findsOneWidget);
    completer.complete(item.copyWith(ownerId: null));
    await tester.pumpAndSettle();
    expect(find.text('Restored Rimu Desk'), findsOneWidget);
  });

  testWidgets('owner edit form is prefilled and saves approved fields', (
    tester,
  ) async {
    final authProvider = await _signedInAuthProvider(tester);
    final repository = _TestItemRepository(fetchResult: Future.value(item));
    final listingProvider = ListingProvider(itemRepository: repository);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: listingProvider),
        ],
        child: MaterialApp(
          theme: buildKiwiShareTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open_edit_screen'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ItemEditScreen(item: item),
                    ),
                  ),
                  child: const Text('Open edit'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_edit_screen')));
    await tester.pumpAndSettle();

    final titleField = tester.widget<TextFormField>(
      find.byKey(const Key('edit_title_field')),
    );
    expect(titleField.controller?.text, 'Restored Rimu Desk');
    await tester.enterText(
      find.byKey(const Key('edit_title_field')),
      'Updated Rimu Desk',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('edit_save_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit_save_button')));
    await tester.pumpAndSettle();

    expect(repository.updatedItem?.title, 'Updated Rimu Desk');
    expect(find.byKey(const Key('open_edit_screen')), findsOneWidget);
  });

  testWidgets('owner deletion requires confirmation and returns safely', (
    tester,
  ) async {
    final authProvider = await _signedInAuthProvider(tester);
    final ownedItem = item.copyWith(ownerId: 'mock_user_1');
    final repository = _TestItemRepository(
      fetchResult: Future.value(ownedItem),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider(
            create: (_) => ListingProvider(itemRepository: repository),
          ),
        ],
        child: MaterialApp(
          theme: buildKiwiShareTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open_detail_screen'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const ItemDetailPage(itemId: 'detail-item-1'),
                    ),
                  ),
                  child: const Text('Open detail'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open_detail_screen')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('detail_delete_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.byKey(const Key('detail_delete_button')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this listing?'), findsOneWidget);
    expect(find.textContaining('audit records are retained'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete_cancel_button')));
    await tester.pumpAndSettle();
    expect(repository.deletedId, isNull);

    await tester.tap(find.byKey(const Key('detail_delete_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_confirm_button')));
    await tester.pumpAndSettle();

    expect(repository.deletedId, ownedItem.id);
    expect(find.byKey(const Key('open_detail_screen')), findsOneWidget);
  });

  test('listing provider updates and removes cached detail items', () async {
    final repository = _TestItemRepository(fetchResult: Future.value(item));
    final provider = ListingProvider(itemRepository: repository);
    await provider.getPopularItems();

    final changed = item.copyWith(title: 'Updated desk');
    final updated = await provider.updateItem(item: changed, token: 'token');
    expect(updated.title, 'Updated desk');
    expect(provider.cachedPopularItems?.single.title, 'Updated desk');

    await provider.deleteItem(id: item.id, token: 'token');
    expect(provider.cachedPopularItems, isEmpty);
    expect(repository.deletedId, item.id);
  });
}

class _TestItemRepository implements ItemRepository {
  _TestItemRepository({required this.fetchResult});

  final Future<ItemModel> fetchResult;
  String? deletedId;
  ItemModel? updatedItem;

  @override
  Future<void> deleteItem({required String id, required String token}) async {
    deletedId = id;
  }

  @override
  Future<ItemModel> fetchItemById(String id) => fetchResult;

  @override
  Future<List<ItemModel>> fetchMyItems({
    required bool sold,
    required String token,
  }) async => [await fetchResult];

  @override
  Future<List<ItemModel>> fetchPopularItems() async => [await fetchResult];

  @override
  Stream<List<ItemModel>> searchItems({
    String? query,
    String? category,
  }) async* {
    yield [await fetchResult];
  }

  @override
  Future<ItemModel> updateItem({
    required ItemModel item,
    required String token,
  }) async {
    updatedItem = item;
    return item;
  }
}

Future<AuthProvider> _signedInAuthProvider(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final provider = AuthProvider(userRepository: MockUserRepository());
  await tester.runAsync(
    () => provider.verifyOtp('owner@kiwishare.test', '123456'),
  );
  return provider;
}
