import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/listing_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/views/profile/user_listings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_item_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestItemRepository itemRepo;
  late AuthProvider auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'test-token',
      'current_user':
          '{"id":"user-1","displayName":"Riley","trustScore":95,"kiwiGold":10,"isVerified":true}',
    });
    auth = AuthProvider(userRepository: MockUserRepository());

    itemRepo = TestItemRepository(
      items: [
        const ItemModel(
          id: 'item_1',
          title: 'Monstera Plant',
          priceNzd: '25',
          location: 'Auckland',
          imageUrl: '',
          category: 'Plants',
          isSustainable: true,
          status: ItemStatus.active,
          ownerId: 'user-1',
        ),
        const ItemModel(
          id: 'item_2',
          title: 'Vintage Chair',
          priceNzd: '80',
          location: 'Wellington',
          imageUrl: '',
          category: 'Furniture',
          isSustainable: false,
          status: ItemStatus.delisted,
          ownerId: 'user-1',
        ),
      ],
    );
  });

  Widget createWidgetUnderTest({
    UserListingsMode mode = UserListingsMode.selling,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ListingProvider>(
          create: (_) => ListingProvider(itemRepository: itemRepo),
        ),
      ],
      child: MaterialApp(home: UserListingsScreen(mode: mode)),
    );
  }

  testWidgets('renders KiwiGold wallet banner with 10 KiwiGold', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('10 KiwiGold'), findsOneWidget);
    expect(find.textContaining('5 KiwiGold per boost'), findsOneWidget);
    expect(find.text('Top Up'), findsOneWidget);
  });

  testWidgets('filters listings by Active, Delisted, and All tabs', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Default tab is 'Active'
    expect(find.text('Monstera Plant'), findsOneWidget);
    expect(find.text('Vintage Chair'), findsNothing);

    // Tap Delisted tab
    await tester.tap(find.text('Delisted (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Monstera Plant'), findsNothing);
    expect(find.text('Vintage Chair'), findsOneWidget);

    // Tap All tab
    await tester.tap(find.text('All (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Monstera Plant'), findsOneWidget);
    expect(find.text('Vintage Chair'), findsOneWidget);
  });

  testWidgets('can delist an active item via Delist action button', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Monstera Plant'), findsOneWidget);
    expect(find.text('Delist'), findsOneWidget);

    // Tap Delist
    await tester.tap(find.text('Delist'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Delist?'), findsOneWidget);

    // Confirm delist
    await tester.tap(find.widgetWithText(FilledButton, 'Delist'));
    await tester.pumpAndSettle();

    // Now under Active tab, Monstera Plant should no longer be shown
    expect(find.text('Monstera Plant'), findsNothing);

    // Switch to Delisted tab
    await tester.tap(find.text('Delisted (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Monstera Plant'), findsOneWidget);
  });

  testWidgets('can promote an active item using 5 KiwiGold', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.textContaining('Promote ('), findsOneWidget);

    // Tap Promote
    await tester.tap(find.textContaining('Promote ('));
    await tester.pumpAndSettle();

    // Verify promotion confirmation dialog
    expect(find.text('Promote Listing'), findsOneWidget);
    expect(find.text('Cost: 5 KiwiGold'), findsOneWidget);

    // Tap Confirm
    await tester.tap(find.widgetWithText(FilledButton, 'Promote (5 KiwiGold)'));
    await tester.pumpAndSettle();

    // Verify updated balance in AuthProvider & wallet card
    expect(auth.currentUser?.kiwiGold, 5);
    expect(find.text('5 KiwiGold'), findsOneWidget);
  });

  testWidgets('can open KiwiGoldTopUpSheet from Top Up button', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Top Up'), findsOneWidget);
    await tester.tap(find.text('Top Up'));
    await tester.pumpAndSettle();

    expect(find.text('KiwiGold & VIP Perks'), findsOneWidget);
    expect(find.text('100 KiwiGold Coins'), findsOneWidget);
    expect(find.text('VIP Monthly Membership'), findsOneWidget);
  });

  testWidgets('renders VIP banner and VIP Boost (Free) for VIP users', (
    tester,
  ) async {
    auth.updateVipStatus(isVip: true);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('VIP Member'), findsOneWidget);
    expect(find.text('VIP Boost (Free)'), findsOneWidget);
  });

  testWidgets('sold inventory cannot be edited or relisted by seller', (
    tester,
  ) async {
    itemRepo.items.add(
      const ItemModel(
        id: 'item_sold',
        title: 'Sold Camera',
        priceNzd: '150',
        location: 'Auckland',
        imageUrl: '',
        category: 'Electronics',
        isSustainable: true,
        status: ItemStatus.sold,
        ownerId: 'user-1',
      ),
    );

    await tester.pumpWidget(createWidgetUnderTest(mode: UserListingsMode.sold));
    await tester.pumpAndSettle();

    expect(find.text('Sold Camera'), findsOneWidget);
    expect(find.text('Sold'), findsWidgets);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Relist'), findsNothing);
    expect(find.text('Delist'), findsNothing);
  });
}
