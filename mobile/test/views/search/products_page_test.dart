import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/providers.dart';
import 'package:kiwishare/repositories/item_repository.dart';
import 'package:kiwishare/services/product_location_service.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/products/product_detail_screen.dart';
import 'package:kiwishare/views/search/search_screen.dart';
import 'package:provider/provider.dart';

class _AucklandLocationService implements ProductLocationService {
  @override
  Future<ProductLocationContext> getCurrentLocation() async =>
      const ProductLocationContext(
        city: 'Auckland',
        latitude: -36.8485,
        longitude: 174.7633,
      );
}

class _DeniedLocationService implements ProductLocationService {
  @override
  Future<ProductLocationContext> getCurrentLocation() =>
      throw const ProductLocationException(
        'Location permission was not granted. Choose a city instead.',
      );
}

Widget _productsApp({
  ValueChanged<ItemModel>? onOpenItem,
  TextScaler textScaler = TextScaler.noScaling,
  ProductLocationService? locationService,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SearchProvider()),
    ChangeNotifierProvider(create: (_) => FavoritesProvider()),
    ChangeNotifierProvider(
      create: (_) => ListingProvider(itemRepository: MockItemRepository()),
    ),
  ],
  child: MaterialApp(
    theme: buildKiwiShareTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: SearchScreen(
      locationService: locationService ?? _AucklandLocationService(),
      onOpenItem: onOpenItem,
    ),
  ),
);

void main() {
  testWidgets('uses documented heading sizes and four category tabs', (
    tester,
  ) async {
    await tester.pumpWidget(_productsApp());

    final screenTitle = tester.widget<Text>(find.text('Products'));
    expect(screenTitle.style?.fontSize, 24);
    expect(find.text('Camping'), findsOneWidget);
    expect(find.text('Plants'), findsOneWidget);
    expect(find.text('Furniture'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.text('Available products · 7'), findsOneWidget);
  });

  testWidgets('filters products and opens the selected product', (
    tester,
  ) async {
    ItemModel? openedItem;
    await tester.pumpWidget(
      _productsApp(onOpenItem: (item) => openedItem = item),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    await tester.tap(find.text('Plants'));
    await tester.pump();
    expect(find.text('Available products · 1'), findsOneWidget);

    await tester.ensureVisible(find.text('Monstera Plant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monstera Plant'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product-preview-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('product-preview-card')));
    expect(openedItem?.id, 'item_1');
  });

  testWidgets('near-you action uses approximate city and filters results', (
    tester,
  ) async {
    await tester.pumpWidget(_productsApp());
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    await tester.tap(find.byKey(const Key('products-location-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('near-you-option')));
    await tester.pumpAndSettle();

    expect(find.text('Near you · Auckland'), findsOneWidget);
    expect(find.byKey(const Key('products-map')), findsOneWidget);
    expect(find.byKey(const Key('product-marker-item_1')), findsOneWidget);
    expect(find.byKey(const Key('product-marker-item_6')), findsOneWidget);
  });

  testWidgets('denied location keeps conventional product browsing available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _productsApp(locationService: _DeniedLocationService()),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    await tester.tap(find.byKey(const Key('products-location-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('near-you-option')));
    await tester.pumpAndSettle();

    expect(
      find.text('Location permission was not granted. Choose a city instead.'),
      findsOneWidget,
    );
    expect(find.text('Available products · 7'), findsOneWidget);
  });

  testWidgets('products controls support 200 percent text scaling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _productsApp(textScaler: const TextScaler.linear(2)),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    expect(find.byKey(const Key('products-search-field')), findsOneWidget);
    expect(find.text('Camping'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product detail displays buyer-facing listing information', (
    tester,
  ) async {
    const item = ItemModel(
      id: 'detail-1',
      title: 'Camping Stove',
      priceNzd: '35',
      location: 'Auckland',
      imageUrl: '',
      isSustainable: true,
      category: 'Camping',
      status: ItemStatus.active,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FavoritesProvider(),
        child: MaterialApp(
          theme: buildKiwiShareTheme(),
          home: const ProductDetailScreen(item: item),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Product details'), findsOneWidget);
    final productTitle = find.text('Camping Stove', skipOffstage: false);
    expect(productTitle, findsOneWidget);
    await tester.ensureVisible(productTitle);
    await tester.pumpAndSettle();
    expect(find.text('\$35 NZD'), findsOneWidget);
    expect(
      find.text('Approximate location', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Available', skipOffstage: false), findsOneWidget);
  });

  testWidgets('price range and keyword filters work together', (tester) async {
    await tester.pumpWidget(_productsApp());
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('products-search-field')),
      'camping',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('Available products · 4'), findsOneWidget);

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('maximum-price-field')), '35');
    await tester.tap(find.text('Show products'));
    await tester.pumpAndSettle();

    expect(find.text('Available products · 2'), findsOneWidget);
    expect(find.text('Camping Stove'), findsOneWidget);
  });

  testWidgets('map preview favorite toggles without opening details', (
    tester,
  ) async {
    ItemModel? openedItem;
    await tester.pumpWidget(
      _productsApp(onOpenItem: (item) => openedItem = item),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    await tester.tap(find.byKey(const Key('map-view-toggle')));
    await tester.pump();
    tester
        .widget<IconButton>(find.byKey(const Key('product-marker-item_1')))
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview-favorite-button')));
    await tester.pump();

    expect(openedItem, isNull);
    expect(
      tester
          .element(find.byKey(const Key('product-preview-card')))
          .read<FavoritesProvider>()
          .isFavorite('item_1'),
      isTrue,
    );
  });

  testWidgets('detail back restores preview and preserved filters', (
    tester,
  ) async {
    final searchProvider = SearchProvider();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: TextButton(
              key: const Key('open-products'),
              onPressed: () => context.push('/search'),
              child: const Text('Products'),
            ),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) =>
              SearchScreen(locationService: _AucklandLocationService()),
        ),
        GoRoute(
          path: '/items/:itemId',
          builder: (context, state) =>
              ProductDetailScreen(item: state.extra as ItemModel?),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: searchProvider),
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(
            create: (_) =>
                ListingProvider(itemRepository: MockItemRepository()),
          ),
        ],
        child: MaterialApp.router(
          theme: buildKiwiShareTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-products')));
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('products-search-field')),
      'monstera',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Plants'));
    await tester.pump();
    await tester.tap(find.text('Monstera Plant'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('product-preview-card')));
    await tester.pumpAndSettle();

    expect(find.text('Product details'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('product-preview-card')), findsOneWidget);
    expect(searchProvider.query, 'monstera');
    expect(searchProvider.selectedCategory, 'Plants');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('products-search-field')))
          .controller
          ?.text,
      'monstera',
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('product-preview-card')), findsNothing);
    expect(find.byKey(const Key('products-search-field')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open-products')), findsOneWidget);
  });
}
