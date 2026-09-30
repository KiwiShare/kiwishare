import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/providers/providers.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/search/search_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_item_repository.dart';

Widget _app({SearchProvider? searchProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => ListingProvider(itemRepository: TestItemRepository()),
      ),
      ChangeNotifierProvider.value(value: searchProvider ?? SearchProvider()),
    ],
    child: MaterialApp(
      theme: buildKiwiShareTheme(),
      home: const SearchScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('search-as-you-type suggestions become full search results', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-input')), 'camp');
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    expect(find.text('Camping'), findsWidgets);
    expect(find.text('Camping Stove'), findsWidgets);

    await tester.tap(find.text('Camping').first);
    await tester.pumpAndSettle();

    expect(find.text('4 results across KiwiShare'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Price'), findsOneWidget);
    expect(find.text('Newest'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Tent - 2 Person'), findsOneWidget);
    expect(find.text('Camping Stove'), findsOneWidget);
  });

  testWidgets(
    'result filters narrow a submitted search without leaving screen',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('search-input')), 'camping');
      await tester.tap(find.byKey(const Key('search-submit')));
      await tester.pumpAndSettle();

      expect(find.text('4 results across KiwiShare'), findsOneWidget);

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('search-filter-max-price')),
        '30',
      );
      await tester.tap(find.byKey(const Key('search-apply-filters')));
      await tester.pumpAndSettle();

      expect(find.text('1 result across KiwiShare'), findsOneWidget);
      expect(find.text('Lantern'), findsOneWidget);
      expect(find.text('Camping Stove'), findsNothing);
      expect(find.text('Filters 1'), findsOneWidget);
    },
  );

  testWidgets('submitted searches appear in recent history', (tester) async {
    final searchProvider = SearchProvider();
    await tester.pumpWidget(_app(searchProvider: searchProvider));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-input')), 'bike');
    await tester.tap(find.byKey(const Key('search-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-clear')));
    await tester.pumpAndSettle();

    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('bike'), findsOneWidget);
  });
}
