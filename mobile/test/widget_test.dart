import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kiwishare/models/user_model.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/providers.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/repositories/item_repository.dart';
import 'package:kiwishare/main.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('KiwiShare Data Models', () {
    test('UserModel JSON Serialization', () {
      final user = const UserModel(
        id: 'test_u',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.png',
        trustScore: 95,
        isVerified: true,
      );

      final map = user.toMap();
      expect(map['id'], 'test_u');
      expect(map['displayName'], 'Test User');

      final fromMap = UserModel.fromMap(map);
      expect(fromMap, user);
    });

    test('ItemModel JSON Serialization', () {
      final item = const ItemModel(
        id: 'test_i',
        title: 'Test Item',
        priceNzd: '50',
        location: 'Auckland',
        imageUrl: 'https://example.com/item.png',
        isSustainable: true,
        category: 'Plants',
        status: ItemStatus.active,
      );

      final map = item.toMap();
      expect(map['id'], 'test_i');
      expect(map['status'], 'active');

      final fromMap = ItemModel.fromMap(map);
      expect(fromMap, item);
    });
  });

  group('Fine-Grained Providers Test', () {
    late AuthProvider authProvider;
    late NavigationProvider navProvider;
    late FavoritesProvider favProvider;
    late SearchProvider searchProvider;
    late MockUserRepository mockUserRepo;

    setUp(() {
      mockUserRepo = MockUserRepository();
      authProvider = AuthProvider(userRepository: mockUserRepo);
      navProvider = NavigationProvider();
      favProvider = FavoritesProvider();
      searchProvider = SearchProvider();
    });

    test('Initial State configuration', () {
      expect(authProvider.isLoggedIn, isFalse);
      expect(authProvider.currentUser, isNull);
      expect(navProvider.activeTab, equals(0));
      expect(searchProvider.selectedCategory, equals('All'));
      expect(favProvider.favoriteIds.isEmpty, isTrue);
    });

    test('Login sets isLoggedIn to true and populates currentUser', () async {
      await authProvider.verifyOtp('sam@kiwishare.co.nz', '123456');
      expect(authProvider.isLoggedIn, isTrue);
      expect(authProvider.currentUser, isNotNull);
      expect(authProvider.currentUser!.displayName, 'sam');
    });

    test('Logout clears authenticated user parameters', () async {
      await authProvider.verifyOtp('sam@kiwishare.co.nz', '123456');
      expect(authProvider.isLoggedIn, isTrue);

      await authProvider.logout();
      expect(authProvider.isLoggedIn, isFalse);
      expect(authProvider.currentUser, isNull);
    });

    test('Navigation tab index mapping updates', () {
      navProvider.setActiveTab(3);
      expect(navProvider.activeTab, equals(3));
    });

    test('Category filtering updates', () {
      searchProvider.setCategory('Camping');
      expect(searchProvider.selectedCategory, equals('Camping'));
    });

    test('Toggling listing favorites updates set', () {
      expect(favProvider.isFavorite('item_1'), isFalse);

      favProvider.toggleFavorite('item_1');
      expect(favProvider.isFavorite('item_1'), isTrue);

      favProvider.toggleFavorite('item_1');
      expect(favProvider.isFavorite('item_1'), isFalse);
    });
  });

  group('Router Compilation Test', () {
    testWidgets('MaterialApp.router loads cleanly with GoRouter Config', (
      tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => AuthProvider(userRepository: MockUserRepository()),
            ),
            ChangeNotifierProvider(create: (_) => NavigationProvider()),
            ChangeNotifierProvider(create: (_) => FavoritesProvider()),
            ChangeNotifierProvider(create: (_) => SearchProvider()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(
              create: (_) =>
                  ListingProvider(itemRepository: MockItemRepository()),
            ),
          ],
          child: const KiwiShareApp(),
        ),
      );

      // Verify that the widget tree compiles and pumps splash screen successfully
      expect(find.byType(KiwiShareApp), findsOneWidget);
    });
  });
}
