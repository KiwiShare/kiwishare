import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/favorites_provider.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';
import 'package:kiwishare/services/notification_permission_coordinator.dart';
import 'package:kiwishare/services/push_notification_service.dart';
import 'package:kiwishare/views/shared/widgets/item_card.dart';
import 'package:provider/provider.dart';

void main() {
  Widget buildCard(ItemModel item, {bool compact = false}) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider(
          create: (_) => FavoritesProvider(),
          child: SizedBox(
            width: 200,
            child: ItemCard(item: item, compact: compact),
          ),
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

  testWidgets('compact card keeps metadata while reducing overall height', (
    tester,
  ) async {
    const item = ItemModel(
      id: 'compact-item',
      title: 'Eco Student Desk',
      priceNzd: '40.00',
      location: 'Auckland Central',
      imageUrl: '',
      isSustainable: true,
      category: 'Furniture',
      status: ItemStatus.active,
      seller: SellerInfo(
        id: 'seller-compact',
        displayName: 'Student Seller',
        isStudentVerified: true,
      ),
    );

    await tester.pumpWidget(buildCard(item));
    final standardHeight = tester.getSize(find.byType(ItemCard)).height;

    await tester.pumpWidget(buildCard(item, compact: true));
    final compactHeight = tester.getSize(find.byType(ItemCard)).height;

    expect(compactHeight, lessThan(standardHeight));
    expect(find.text('Student Seller'), findsNothing);
    expect(find.text('Auckland Central'), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.byTooltip('Verified student seller'), findsOneWidget);
    expect(find.byTooltip('Sustainable listing'), findsOneWidget);
    expect(find.text('Verified Student'), findsNothing);
    expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact card uses a bottom-right Watchlist action and count', (
    tester,
  ) async {
    const item = ItemModel(
      id: 'compact-watch-item',
      title: 'Desk lamp',
      priceNzd: '15',
      location: 'Auckland',
      imageUrl: '',
      isSustainable: false,
      category: 'Home',
      status: ItemStatus.active,
      watchlistCount: 3,
    );
    final watchlist = WatchlistProvider(
      repository: TestWatchlistRepository(),
      initialToken: 'valid-token',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<WatchlistProvider>.value(
            value: watchlist,
            child: const SizedBox(
              width: 200,
              child: ItemCard(item: item, compact: true),
            ),
          ),
        ),
      ),
    );

    final button = find.byKey(const Key('compact-watchlist-compact-watch-item'));
    expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(tester.getRect(button).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(ItemCard)).bottom - 5));

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(watchlist.isWatched(item.id), isTrue);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(find.byTooltip('Remove from Watchlist'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmed card add offers permission but removal does not', (
    tester,
  ) async {
    const item = ItemModel(
      id: 'watch-item',
      title: 'Watch item',
      priceNzd: '25',
      location: 'Auckland',
      imageUrl: '',
      isSustainable: true,
      category: 'Other',
      status: ItemStatus.active,
      ownerId: 'seller-1',
    );
    final watchlist = WatchlistProvider(
      repository: TestWatchlistRepository(),
      initialToken: 'valid-token',
    );
    final controller = _PermissionController();
    final coordinator = NotificationPermissionCoordinator(
      permissionController: controller,
      storage: _Storage(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<WatchlistProvider>.value(
            value: watchlist,
            child: SizedBox(
              width: 200,
              child: ItemCard(item: item, permissionCoordinator: coordinator),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();
    expect(watchlist.isWatched(item.id), isTrue);
    expect(controller.statusCalls, 1);

    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();
    expect(watchlist.isWatched(item.id), isFalse);
    expect(controller.statusCalls, 1);
  });
}

class _PermissionController implements PushPermissionController {
  @override
  int? activeSessionGeneration = 1;
  @override
  String? activeUserId = 'user-1';
  int statusCalls = 0;

  @override
  Future<PushPermissionStatus> getPermissionStatus() async {
    statusCalls += 1;
    return PushPermissionStatus.denied;
  }

  @override
  Future<PushPermissionStatus> requestPermissionAndSync({
    int? expectedSessionGeneration,
    String? expectedUserId,
  }) async => PushPermissionStatus.denied;

  @override
  Future<PushPermissionStatus> synchronizeIfAuthorized({
    int? expectedSessionGeneration,
    String? expectedUserId,
  }) async => PushPermissionStatus.denied;
}

class _Storage implements NotificationPermissionStorage {
  @override
  Future<int?> getNextEligibleAtMs() async => null;

  @override
  Future<void> setNextEligibleAtMs(int value) async {}

  @override
  Future<void> removeObsoleteDismissal() async {}
}
