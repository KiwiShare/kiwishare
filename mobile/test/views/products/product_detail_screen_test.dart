import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/models/discovery_options_model.dart';
import 'package:kiwishare/models/user_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/listing_provider.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/products/product_detail_integrations.dart';
import 'package:kiwishare/views/products/product_detail_screen.dart';
import 'package:kiwishare/views/products/product_edit_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_item_repository.dart';

const _detailItem = ItemModel(
  id: 'detail_item_1',
  title: 'Database Camping Tent',
  priceNzd: '95',
  currency: 'NZD',
  location: 'Takapuna, Auckland',
  imageUrl: '',
  isSustainable: true,
  category: 'Camping',
  description: 'Waterproof family camping tent.',
  condition: 'like_new',
  negotiable: true,
  status: ItemStatus.active,
  ownerId: 'seller_3',
  seller: SellerInfo(
    id: 'seller_3',
    displayName: 'Stored Seller',
    trustScore: 87,
    rating: 4.8,
    reviewCount: 12,
  ),
);

class _TestAuthProvider extends AuthProvider {
  _TestAuthProvider(this._user) : super(userRepository: MockUserRepository());

  final UserModel? _user;

  @override
  UserModel? get currentUser => _user;

  @override
  bool get isLoggedIn => _user != null;

  @override
  String? get jwtToken => _user == null ? null : 'test-token';
}

AuthProvider _authProvider({bool owner = false}) {
  SharedPreferences.setMockInitialValues({});
  return _TestAuthProvider(
    owner
        ? const UserModel(
            id: 'mock_user_1',
            displayName: 'Owner',
            trustScore: 100,
            isVerified: true,
          )
        : null,
  );
}

Widget _productDetailApp({
  required TestItemRepository itemRepository,
  required AuthProvider authProvider,
  required WatchlistProvider watchlistProvider,
  ItemModel? initialItem,
  ProductDetailIntegrations integrations = const ProductDetailIntegrations(),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: authProvider),
      ChangeNotifierProvider(
        create: (_) => ListingProvider(itemRepository: itemRepository),
      ),
      ChangeNotifierProvider.value(value: watchlistProvider),
    ],
    child: MaterialApp(
      theme: buildKiwiShareTheme(),
      home: ProductDetailScreen(
        itemId: _detailItem.id,
        initialItem: initialItem,
        integrations: integrations,
      ),
    ),
  );
}

void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('loads the current product detail from the repository by ID', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final auth = _authProvider();
    final repo = TestItemRepository(items: [_detailItem]);
    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());

    await tester.pumpWidget(
      _productDetailApp(
        itemRepository: repo,
        authProvider: auth,
        watchlistProvider: watchlist,
        initialItem: _detailItem.copyWith(title: 'Stale list title'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Database Camping Tent'), findsOneWidget);
    expect(find.text('\$95 NZD'), findsOneWidget);
    expect(find.text('Like New'), findsOneWidget);
    expect(find.text('Stored Seller'), findsOneWidget);
    expect(find.text('4.8 · 12 reviews'), findsOneWidget);
    expect(find.text('Price negotiable'), findsOneWidget);
  });

  testWidgets('allows watching and unwatching a database item', (tester) async {
    _setPhoneViewport(tester);
    final auth = _authProvider();
    final repo = TestItemRepository(items: [_detailItem]);
    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());

    await tester.pumpWidget(
      _productDetailApp(
        itemRepository: repo,
        authProvider: auth,
        watchlistProvider: watchlist,
        initialItem: _detailItem,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('detail-watch-action-button')));
    await tester.pumpAndSettle();
    expect(watchlist.isWatched(_detailItem.id), isTrue);
    expect(find.text('Watching'), findsOneWidget);

    await tester.tap(find.byKey(const Key('detail-favorite-button')));
    await tester.pumpAndSettle();
    expect(watchlist.isWatched(_detailItem.id), isFalse);
  });

  testWidgets('exposes report and transaction integration hooks', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final auth = _authProvider();
    final repo = TestItemRepository(items: [_detailItem]);
    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());
    String? reportedId;
    String? tradeId;

    await tester.pumpWidget(
      _productDetailApp(
        itemRepository: repo,
        authProvider: auth,
        watchlistProvider: watchlist,
        initialItem: _detailItem,
        integrations: ProductDetailIntegrations(
          onReportListing: (_, item) => reportedId = item.id,
          onStartTrade: (_, item) => tradeId = item.id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reportButton = find.byKey(const Key('report_listing_button'));
    await tester.ensureVisible(reportButton);
    await tester.tap(reportButton);
    await tester.pumpAndSettle();
    expect(reportedId, _detailItem.id);

    await tester.tap(find.byKey(const Key('start_trade_button')));
    await tester.pumpAndSettle();
    expect(tradeId, _detailItem.id);
  });

  testWidgets('opens the contextual listing report module', (tester) async {
    _setPhoneViewport(tester);
    final auth = _authProvider();
    final repo = TestItemRepository(items: [_detailItem]);
    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());

    await tester.pumpWidget(
      _productDetailApp(
        itemRepository: repo,
        authProvider: auth,
        watchlistProvider: watchlist,
        initialItem: _detailItem,
        integrations: const ProductDetailIntegrations(
          onReportListing: openListingReport,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reportButton = find.byKey(const Key('report_listing_button'));
    await tester.ensureVisible(reportButton);
    await tester.tap(reportButton);
    await tester.pumpAndSettle();

    expect(find.text('Report listing'), findsOneWidget);
    expect(find.text(_detailItem.title), findsOneWidget);
    expect(find.text('Listing in ${_detailItem.location}'), findsOneWidget);
    expect(find.byKey(const Key('report_reason_field')), findsOneWidget);
  });

  testWidgets('shows owner controls for the stored listing owner', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final auth = _authProvider(owner: true);
    final ownedItem = _detailItem.copyWith(ownerId: 'mock_user_1');
    final repo = TestItemRepository(items: [ownedItem]);
    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());

    await tester.pumpWidget(
      _productDetailApp(
        itemRepository: repo,
        authProvider: auth,
        watchlistProvider: watchlist,
        initialItem: ownedItem,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('edit_listing_button')), findsOneWidget);
    expect(find.byKey(const Key('delete_listing_button')), findsOneWidget);
    expect(find.byKey(const Key('detail-watch-action-button')), findsNothing);
  });

  testWidgets('edit screen uses listing and discovery values from storage', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final auth = _authProvider(owner: true);
    final ownedItem = _detailItem.copyWith(ownerId: 'mock_user_1');
    final repo = TestItemRepository(items: [ownedItem]);
    const options = DiscoveryOptionsModel(
      categories: [DiscoveryCategoryOption(value: 'Camping', count: 1)],
      locations: [],
      conditions: [DiscoveryConditionOption(value: 'like_new', count: 1)],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(
            create: (_) => ListingProvider(itemRepository: repo),
          ),
        ],
        child: MaterialApp(
          theme: buildKiwiShareTheme(),
          home: ProductEditScreen(item: ownedItem, options: options),
        ),
      ),
    );
    await tester.pump();

    final titleField = tester.widget<TextFormField>(
      find.byKey(const Key('edit_listing_title')),
    );
    final conditionField = tester.widget<TextFormField>(
      find.byKey(const Key('edit_listing_condition')),
    );
    expect(titleField.controller?.text, ownedItem.title);
    expect(conditionField.controller?.text, ownedItem.condition);
    expect(find.text('Camping'), findsOneWidget);
  });

  testWidgets('renders unavailable state when the database item is missing', (
    tester,
  ) async {
    _setPhoneViewport(tester);
    final auth = _authProvider();
    final repo = TestItemRepository(items: []);
    final watchlist = WatchlistProvider(repository: TestWatchlistRepository());

    await tester.pumpWidget(
      _productDetailApp(
        itemRepository: repo,
        authProvider: auth,
        watchlistProvider: watchlist,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product unavailable'), findsOneWidget);
  });
}
