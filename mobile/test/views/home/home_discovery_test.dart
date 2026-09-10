import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiwishare/main.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/providers.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/services/product_location_service.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/home/home_screen.dart';
import 'package:kiwishare/views/home/widgets/home_product_map.dart';
import 'package:kiwishare/views/products/product_detail_screen.dart';
import 'package:provider/provider.dart';

import '../../support/test_item_repository.dart';

class _AucklandLocationService implements ProductLocationService {
  @override
  Future<ProductLocationContext> getCurrentLocation() async =>
      const ProductLocationContext(
        city: 'Auckland',
        latitude: -36.85,
        longitude: 174.76,
      );
}

class _DeniedLocationService implements ProductLocationService {
  @override
  Future<ProductLocationContext> getCurrentLocation() =>
      throw const ProductLocationException(
        'Location permission was not granted. Choose a city instead.',
      );
}

Widget _homeApp({
  ValueChanged<ItemModel>? onOpenItem,
  TextScaler textScaler = TextScaler.noScaling,
  ProductLocationService? locationService,
  HomeDiscoveryProvider? discovery,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: discovery ?? HomeDiscoveryProvider()),
    ChangeNotifierProvider(create: (_) => FavoritesProvider()),
    ChangeNotifierProvider(
      create: (_) => ListingProvider(itemRepository: TestItemRepository()),
    ),
  ],
  child: MaterialApp(
    theme: buildKiwiShareTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: HomeScreen(
      locationService: locationService ?? _AucklandLocationService(),
      onOpenItem: onOpenItem,
    ),
  ),
);

Future<void> _loadHome(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.pump(const Duration(milliseconds: 650));
  await tester.pump();
}

void main() {
  testWidgets('category chips filter products without leaving Home', (
    tester,
  ) async {
    await _loadHome(tester, _homeApp());

    expect(find.text('7 items'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-category-Plants')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('1 items'), findsOneWidget);
    expect(find.text('Monstera Plant'), findsOneWidget);
    expect(find.text('Armchair'), findsNothing);
    expect(find.text('KiwiShare'), findsOneWidget);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('Home keyword and preset price range filter together', (
    tester,
  ) async {
    await _loadHome(tester, _homeApp());

    await tester.enterText(
      find.byKey(const Key('home-search-field')),
      'camping',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('4 items'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-price-range-under25')));
    await tester.tap(find.byKey(const Key('home-apply-filters')));
    await tester.pumpAndSettle();

    expect(find.text('1 items'), findsOneWidget);
    expect(find.text('Lantern'), findsOneWidget);
    expect(find.text('Camping Stove'), findsNothing);
  });

  testWidgets('Home map uses a restrained NZ-only light basemap', (
    tester,
  ) async {
    await _loadHome(tester, _homeApp());

    await tester.ensureVisible(find.byKey(const Key('home-map-view-toggle')));
    await tester.tap(find.byKey(const Key('home-map-view-toggle')));
    await tester.pump();

    expect(find.byKey(const Key('home-products-map')), findsOneWidget);
    final map = tester.widget<FlutterMap>(
      find.byKey(const Key('home-products-map')),
    );
    expect(map.options.minZoom, HomeProductMap.minimumZoom);
    expect(map.options.maxZoom, HomeProductMap.maximumZoom);
    expect(map.options.cameraConstraint, isA<ContainCameraCenter>());
    final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(tiles.urlTemplate, HomeProductMap.tileUrl);
    expect(tiles.urlTemplate, contains('light_all'));
    expect(find.byKey(const Key('home-product-marker-item_1')), findsOneWidget);
  });

  testWidgets('near-you choice stays on Home and shows Auckland products', (
    tester,
  ) async {
    await _loadHome(tester, _homeApp());

    await tester.tap(find.byKey(const Key('home-location-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-near-you-option')));
    await tester.pumpAndSettle();

    expect(find.text('Near you'), findsOneWidget);
    expect(find.byKey(const Key('home-products-map')), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.byKey(const Key('home-product-marker-item_1')), findsOneWidget);
    expect(find.byKey(const Key('home-product-marker-item_6')), findsOneWidget);
  });

  testWidgets('denied location keeps conventional Home browsing available', (
    tester,
  ) async {
    await _loadHome(
      tester,
      _homeApp(locationService: _DeniedLocationService()),
    );

    await tester.tap(find.byKey(const Key('home-location-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-near-you-option')));
    await tester.pumpAndSettle();

    expect(
      find.text('Location permission was not granted. Choose a city instead.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-search-field')), findsOneWidget);
    expect(find.text('7 items'), findsOneWidget);
  });

  testWidgets('map preview can favourite without opening details', (
    tester,
  ) async {
    ItemModel? openedItem;
    await _loadHome(tester, _homeApp(onOpenItem: (item) => openedItem = item));

    await tester.ensureVisible(find.byKey(const Key('home-map-view-toggle')));
    await tester.tap(find.byKey(const Key('home-map-view-toggle')));
    await tester.pump();
    tester
        .element(find.byKey(const Key('home-products-map')))
        .read<HomeDiscoveryProvider>()
        .selectPreview('item_1');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-preview-favorite-button')));
    await tester.pump();

    expect(openedItem, isNull);
    expect(find.byKey(const Key('home-product-preview-card')), findsOneWidget);
    expect(
      tester
          .element(find.byKey(const Key('home-product-preview-card')))
          .read<FavoritesProvider>()
          .isFavorite('item_1'),
      isTrue,
    );
  });

  testWidgets('detail back restores Home map preview and filters', (
    tester,
  ) async {
    final discovery = HomeDiscoveryProvider();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              HomeScreen(locationService: _AucklandLocationService()),
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
          ChangeNotifierProvider.value(value: discovery),
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(
            create: (_) =>
                ListingProvider(itemRepository: TestItemRepository()),
          ),
        ],
        child: MaterialApp.router(
          theme: buildKiwiShareTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('home-search-field')),
      'monstera',
    );
    await tester.tap(find.byKey(const Key('home-category-Plants')));
    await tester.ensureVisible(find.byKey(const Key('home-map-view-toggle')));
    await tester.tap(find.byKey(const Key('home-map-view-toggle')));
    await tester.pump();
    discovery.selectPreview('item_1');
    await tester.pumpAndSettle();
    tester.widget<InkWell>(find.byKey(const Key('home-preview-open'))).onTap!();
    await tester.pumpAndSettle();

    expect(find.byType(ProductDetailScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-product-preview-card')), findsOneWidget);
    expect(discovery.query, 'monstera');
    expect(discovery.selectedCategory, 'Plants');
    expect(discovery.view, HomeProductView.map);
  });

  testWidgets(
    'system back closes details before dismissing the Home map preview',
    (tester) async {
      final discovery = HomeDiscoveryProvider();
      final rootKey = GlobalKey<NavigatorState>();
      final shellKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        initialLocation: '/home',
        navigatorKey: rootKey,
        routes: [
          ShellRoute(
            navigatorKey: shellKey,
            builder: (context, state, child) => KiwiShareShell(child: child),
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) =>
                    HomeScreen(locationService: _AucklandLocationService()),
              ),
            ],
          ),
          GoRoute(
            parentNavigatorKey: rootKey,
            path: '/items/:itemId',
            builder: (context, state) =>
                ProductDetailScreen(item: state.extra as ItemModel?),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: discovery),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(userRepository: MockUserRepository()),
            ),
            ChangeNotifierProvider(create: (_) => FavoritesProvider()),
            ChangeNotifierProvider(
              create: (_) =>
                  ListingProvider(itemRepository: TestItemRepository()),
            ),
          ],
          child: MaterialApp.router(
            theme: buildKiwiShareTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();

      discovery
        ..setView(HomeProductView.map)
        ..selectPreview('item_1');
      await tester.pumpAndSettle();
      tester
          .widget<InkWell>(find.byKey(const Key('home-preview-open')))
          .onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(ProductDetailScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('home-product-preview-card')),
        findsOneWidget,
      );
      expect(discovery.previewItemId, 'item_1');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home-product-preview-card')), findsNothing);
      expect(find.byKey(const Key('home-products-map')), findsOneWidget);
      expect(discovery.previewItemId, isNull);
    },
  );

  testWidgets('Home controls support 200 percent text scaling', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _loadHome(tester, _homeApp(textScaler: const TextScaler.linear(2)));

    expect(find.byKey(const Key('home-search-field')), findsOneWidget);
    expect(find.byKey(const Key('home-category-Camping')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Home displays bold KiwiShare header, category icons, jumbo carousel, and recommendations',
    (tester) async {
      ItemModel? openedItem;
      await _loadHome(
        tester,
        _homeApp(onOpenItem: (item) => openedItem = item),
      );

      // 1. Header
      expect(find.text('KiwiShare'), findsOneWidget);
      expect(find.text('Share & Reuse in NZ'), findsOneWidget);

      // 2. Category Chips with Icons
      expect(find.byKey(const Key('home-category-Plants')), findsOneWidget);
      expect(find.byIcon(Icons.yard_outlined), findsOneWidget);
      expect(find.byIcon(Icons.forest_outlined), findsOneWidget);

      // 3. Featured Highlights Jumbo Carousel
      expect(find.text('Featured Highlights'), findsOneWidget);
      expect(find.text('HOT PICK'), findsWidgets);

      // 4. Recommended for You Section
      expect(find.text('Recommended for You'), findsOneWidget);
      expect(find.text('Top 10'), findsOneWidget);

      // 5. Open item by tapping recommended card
      await tester.tap(find.text('Monstera Plant').first);
      await tester.pump();
      expect(openedItem, isNotNull);
      expect(openedItem!.title, 'Monstera Plant');
    },
  );
}
