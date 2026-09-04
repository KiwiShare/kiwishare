import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/providers.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/home/home_screen.dart';
import 'package:kiwishare/views/products/product_detail_screen.dart';
import 'package:provider/provider.dart';

import '../../support/test_item_repository.dart';

void main() {
  testWidgets('Home product card opens Product details', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/items/:itemId',
          builder: (context, state) =>
              ProductDetailScreen(item: state.extra as ItemModel?),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) =>
              const Scaffold(body: Text('Products destination')),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(userRepository: MockUserRepository()),
          ),
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(create: (_) => HomeDiscoveryProvider()),
          ChangeNotifierProvider(create: (_) => SearchProvider()),
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
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pump();

    expect(find.byKey(const Key('home-search-field')), findsOneWidget);
    expect(find.byKey(const Key('home-location-button')), findsOneWidget);
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    expect(find.textContaining('Kia ora'), findsNothing);
    for (final category
        in testCatalogItems.map((item) => item.category).toSet()) {
      expect(find.byKey(Key('home-category-$category')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('home-category-Plants')));
    await tester.pumpAndSettle();
    expect(find.text('Monstera Plant'), findsOneWidget);
    expect(find.text('Armchair'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/home');

    await tester.ensureVisible(find.text('Monstera Plant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monstera Plant'));
    await tester.pumpAndSettle();

    expect(find.text('Product details'), findsOneWidget);
    final detailScreen = tester.widget<ProductDetailScreen>(
      find.byType(ProductDetailScreen),
    );
    expect(detailScreen.item?.title, 'Monstera Plant');
  });
}
