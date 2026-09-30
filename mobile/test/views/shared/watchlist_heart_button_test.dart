import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/favorites_provider.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';
import 'package:kiwishare/views/shared/widgets/watchlist_heart_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('own listing heart is visibly disabled and cannot be watched', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'owner-token',
      'current_user':
          '{"id":"owner-1","displayName":"Owner","trustScore":95,"isVerified":true}',
    });
    final auth = AuthProvider(userRepository: MockUserRepository());
    final repository = TestWatchlistRepository();
    final watchlist = WatchlistProvider(
      repository: repository,
      initialToken: 'owner-token',
    );
    const item = ItemModel(
      id: 'own-item',
      title: 'My desk',
      priceNzd: '50',
      location: 'Auckland',
      imageUrl: '',
      isSustainable: true,
      category: 'Furniture',
      ownerId: 'owner-1',
      status: ItemStatus.active,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<FavoritesProvider>.value(value: watchlist),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WatchlistHeartButton(item: item),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heart = find.byKey(const Key('watchlist-heart-own-item'));
    expect(heart, findsOneWidget);
    expect(tester.widget<InkWell>(heart).onTap, isNull);
    expect(watchlist.isWatched(item.id), isFalse);
    expect(find.byTooltip('This is your listing'), findsOneWidget);
  });
}
