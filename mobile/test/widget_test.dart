import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kiwishare/models/user_model.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/app_state.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/repositories/item_repository.dart';
import 'package:kiwishare/main.dart';

void main() {
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

  group('AppState (React Context-Like State)', () {
    late AppState appState;
    late MockUserRepository mockUserRepo;
    late MockItemRepository mockItemRepo;

    setUp(() {
      mockUserRepo = MockUserRepository();
      mockItemRepo = MockItemRepository();
      appState = AppState(
        userRepository: mockUserRepo,
        itemRepository: mockItemRepo,
      );
    });

    test('Initial State configuration', () {
      expect(appState.isLoggedIn, isFalse);
      expect(appState.currentUser, isNull);
      expect(appState.activeTab, equals(0));
      expect(appState.selectedCategory, equals('All NZ'));
      expect(appState.favoriteIds.isEmpty, isTrue);
    });

    test('Login sets isLoggedIn to true and populates currentUser', () async {
      await appState.login();
      expect(appState.isLoggedIn, isTrue);
      expect(appState.currentUser, isNotNull);
      expect(appState.currentUser!.displayName, 'Sam');
    });

    test('Logout clears authenticated user parameters', () async {
      await appState.login();
      expect(appState.isLoggedIn, isTrue);

      appState.logout();
      expect(appState.isLoggedIn, isFalse);
      expect(appState.currentUser, isNull);
    });

    test('Navigation tab index mapping updates', () {
      appState.setActiveTab(3);
      expect(appState.activeTab, equals(3));
    });

    test('Category filtering updates', () {
      appState.setCategory('Camping');
      expect(appState.selectedCategory, equals('Camping'));
    });

    test('Toggling listing favorites updates set', () {
      expect(appState.isFavorite('item_1'), isFalse);

      appState.toggleFavorite('item_1');
      expect(appState.isFavorite('item_1'), isTrue);

      appState.toggleFavorite('item_1');
      expect(appState.isFavorite('item_1'), isFalse);
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
              create: (_) => AppState(
                userRepository: MockUserRepository(),
                itemRepository: MockItemRepository(),
              ),
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
