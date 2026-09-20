import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/views/shared/widgets/share_bottom_sheet.dart';

void main() {
  const testItem = ItemModel(
    id: 'test-item-999',
    title: 'Vintage Road Bike',
    description: 'Classic 10-speed road bike in great condition',
    category: 'Sports',
    condition: 'Good',
    priceNzd: '280',
    location: 'Ponsonby',
    imageUrl: '',
    images: [],
    isSustainable: true,
    status: ItemStatus.active,
    ownerId: 'user-2',
  );

  testWidgets(
    'ShareBottomSheet renders product snippet and all share channels',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ShareBottomSheet(item: testItem)),
        ),
      );

      // Verify header and product info
      expect(find.text('Share listing'), findsOneWidget);
      expect(find.text('Vintage Road Bike'), findsOneWidget);
      expect(find.text('\$280 NZD'), findsOneWidget);

      // Verify all 5 channels and action buttons
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('WeChat'), findsOneWidget);
      expect(find.text('Instagram'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('System share'), findsOneWidget);
    },
  );
}
