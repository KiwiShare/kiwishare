import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/favorites_provider.dart';
import 'package:kiwishare/views/shared/widgets/item_card.dart';
import 'package:provider/provider.dart';

void main() {
  Widget buildCard(ItemModel item) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => FavoritesProvider(),
          child: SizedBox(width: 200, child: ItemCard(item: item)),
        ),
      ),
    );
  }

  testWidgets(
    'renders verified student badge and icon when seller is student verified',
    (tester) async {
      const item = ItemModel(
        id: 'student-item-1',
        title: 'University Textbook',
        priceNzd: '45.00',
        location: 'Auckland Central',
        imageUrl: 'https://assets.kiwishare.online/test/book.png',
        isSustainable: false,
        category: 'Books',
        status: ItemStatus.active,
        seller: SellerInfo(
          id: 'seller-1',
          displayName: 'Sam Student',
          isStudentVerified: true,
        ),
      );

      await tester.pumpWidget(buildCard(item));

      expect(find.text('Verified Student'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsWidgets);
    },
  );

  testWidgets(
    'renders both sustainable and student verified badges when both apply',
    (tester) async {
      const item = ItemModel(
        id: 'student-item-2',
        title: 'Eco Wooden Chair',
        priceNzd: '30.00',
        location: 'Mount Eden',
        imageUrl: 'https://assets.kiwishare.online/test/chair.png',
        isSustainable: true,
        category: 'Furniture',
        status: ItemStatus.active,
        seller: SellerInfo(
          id: 'seller-2',
          displayName: 'Eco Student',
          isStudentVerified: true,
        ),
      );

      await tester.pumpWidget(buildCard(item));

      expect(find.text('Sustainable'), findsOneWidget);
      expect(find.text('Verified Student'), findsOneWidget);
    },
  );

  testWidgets(
    'does not render student verified badge when seller is not verified',
    (tester) async {
      const item = ItemModel(
        id: 'regular-item',
        title: 'Coffee Table',
        priceNzd: '80.00',
        location: 'Ponsonby',
        imageUrl: 'https://assets.kiwishare.online/test/table.png',
        isSustainable: false,
        category: 'Furniture',
        status: ItemStatus.active,
        seller: SellerInfo(
          id: 'seller-3',
          displayName: 'Regular User',
          isStudentVerified: false,
        ),
      );

      await tester.pumpWidget(buildCard(item));

      expect(find.text('Verified Student'), findsNothing);
    },
  );
}
