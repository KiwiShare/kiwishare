import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/providers.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/home/home_screen.dart';
import 'package:kiwishare/views/products/product_detail_screen.dart';
import 'package:kiwishare/views/shared/widgets/item_card.dart';
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
    await tester.ensureVisible(find.byKey(const Key('home-filter-button')));
    expect(find.byKey(const Key('home-filter-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-filter-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-filter-category')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-filter-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plants').last);
    tester
        .widget<FilledButton>(find.byKey(const Key('home-apply-filters')))
        .onPressed!();
    await tester.pumpAndSettle();

    final productCard = find.descendant(
      of: find.byType(GridView),
      matching: find.widgetWithText(ItemCard, 'Monstera Plant'),
    );
    expect(productCard, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(GridView),
        matching: find.widgetWithText(ItemCard, 'Armchair'),
      ),
      findsNothing,
    );
    expect(router.routeInformationProvider.value.uri.path, '/home');

    await tester.ensureVisible(productCard);
    await tester.pumpAndSettle();
    await tester.tap(productCard);
    await tester.pumpAndSettle();

    expect(find.byType(ProductDetailScreen), findsOneWidget);
    final detailScreen = tester.widget<ProductDetailScreen>(
      find.byType(ProductDetailScreen),
    );
    expect(detailScreen.item?.title, 'Monstera Plant');
  });
}
