import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/providers.dart';
import 'package:kiwishare/repositories/item_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/search/search_screen.dart';
import 'package:provider/provider.dart';

Widget _app({ValueChanged<ItemModel>? onOpenItem}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => SearchProvider()),
    ChangeNotifierProvider(create: (_) => FavoritesProvider()),
    ChangeNotifierProvider(
      create: (_) => ListingProvider(itemRepository: MockItemRepository()),
    ),
  ],
  child: MaterialApp(
    theme: buildKiwiShareTheme(),
    home: SearchScreen(onOpenItem: onOpenItem),
  ),
);

void main() {
  testWidgets('shows the four product categories and listing results', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    expect(find.text('Camping'), findsOneWidget);
    expect(find.text('Plants'), findsOneWidget);
    expect(find.text('Furniture'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.text('7 listings'), findsOneWidget);
    expect(find.text('Monstera Plant'), findsOneWidget);
  });

  testWidgets('category filter and product navigation are functional', (
    tester,
  ) async {
    ItemModel? opened;
    await tester.pumpWidget(_app(onOpenItem: (item) => opened = item));
    await tester.tap(find.text('Plants'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    expect(find.text('1 listings'), findsOneWidget);
    await tester.ensureVisible(find.text('Monstera Plant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monstera Plant'));
    expect(opened?.id, 'item_1');
  });

  testWidgets(
    'search, sort and saved controls remain accessible at 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: _app(),
        ),
      );
      expect(find.byKey(const Key('products-search-field')), findsOneWidget);
      expect(find.text('Sort: Popular'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
