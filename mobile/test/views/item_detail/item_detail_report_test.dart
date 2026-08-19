import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/favorites_provider.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/item_detail/item_detail_screen.dart';
import 'package:kiwishare/views/shared/widgets/item_card.dart';
import 'package:provider/provider.dart';

void main() {
  const item = ItemModel(
    id: 'item_1',
    title: 'Monstera Plant',
    priceNzd: '25',
    location: 'Auckland',
    imageUrl: 'https://example.com/monstera.jpg',
    isSustainable: true,
    category: 'Plants',
    status: ItemStatus.active,
  );

  Widget buildItemCardApp() => ChangeNotifierProvider(
    create: (_) => FavoritesProvider(),
    child: MaterialApp(
      theme: buildKiwiShareTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 180,
            height: 240,
            child: Builder(
              builder: (context) => ItemCard(
                item: item,
                onTap: () => openItemDetail(context, item),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('item card opens details and listing report form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildItemCardApp());
    await tester.tap(find.byKey(const Key('item_card_item_1')));
    await tester.pumpAndSettle();

    expect(find.text('Item details'), findsOneWidget);
    expect(find.byKey(const Key('item_detail_title')), findsOneWidget);

    final reportButton = find.byKey(const Key('report_listing_button'));
    expect(reportButton.hitTestable(), findsOneWidget);
    await tester.tap(reportButton);
    await tester.pumpAndSettle();

    expect(find.text('Report listing'), findsOneWidget);
    expect(find.text('Listing in Auckland'), findsOneWidget);

    await tester.tap(find.byKey(const Key('report_reason_field')));
    await tester.pumpAndSettle();

    expect(find.text('Misleading information'), findsOneWidget);
    expect(find.text('Prohibited or unsafe item'), findsOneWidget);
    expect(find.text('Counterfeit item'), findsOneWidget);
    expect(find.text('Suspected stolen item'), findsOneWidget);
    expect(find.text('Duplicate listing or spam'), findsOneWidget);
  });
}
