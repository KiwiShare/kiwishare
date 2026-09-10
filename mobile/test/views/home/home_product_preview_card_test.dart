import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';
import 'package:kiwishare/services/notification_permission_coordinator.dart';
import 'package:kiwishare/services/push_notification_service.dart';
import 'package:kiwishare/views/home/widgets/home_product_preview_card.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('map preview offers permission only after a confirmed add', (
    tester,
  ) async {
    const item = ItemModel(
      id: 'map-item',
      title: 'Map item',
      priceNzd: '40',
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<WatchlistProvider>.value(
            value: watchlist,
            child: HomeProductPreviewCard(
              item: item,
              onOpen: () {},
              onClose: () {},
              permissionCoordinator: NotificationPermissionCoordinator(
                permissionController: controller,
                storage: _Storage(),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('home-preview-favorite-button')));
    await tester.pumpAndSettle();
    expect(watchlist.isWatched(item.id), isTrue);
    expect(controller.statusCalls, 1);

    await tester.tap(find.byKey(const Key('home-preview-favorite-button')));
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
