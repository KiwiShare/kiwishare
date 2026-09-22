import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/models/public_profile_model.dart';
import 'package:kiwishare/models/user_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/views/profile/public_profile_screen.dart';
import 'package:kiwishare/widgets/vip_crown_icon.dart';
import 'package:provider/provider.dart';

class _FakePublicProfileRepository implements UserRepository {
  final PublicProfileModel profile;
  final List<ItemModel> activeItems;
  final List<ItemModel> soldItems;
  final List<PublicReviewModel> reviews;

  _FakePublicProfileRepository({
    required this.profile,
    required this.activeItems,
    required this.soldItems,
    required this.reviews,
  });

  @override
  Future<PublicProfileModel> fetchPublicProfile(String userId, {String? token}) async => profile;

  @override
  Future<List<ItemModel>> fetchUserPublicItems(String userId, {String status = 'active', String? token}) async {
    return status == 'sold' ? soldItems : activeItems;
  }

  @override
  Future<List<PublicReviewModel>> fetchUserPublicReviews(String userId, {String? token}) async => reviews;

  @override
  Future<void> submitReview({
    required String targetUserId,
    required int rating,
    required String comment,
    List<String>? tags,
    String? orderId,
    String? itemId,
    String? role,
    String? itemTitle,
    String? itemImageUrl,
    required String token,
  }) async {}

  @override
  Future<UserModel> updateBio(String bio, {required String token}) async => const UserModel(
    id: 'user_123',
    displayName: 'Auckland Trader',
    trustScore: 95,
    isVerified: true,
  );

  @override
  Future<UserModel> updateProfile({
    required String token,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
  }) async => const UserModel(
    id: 'user_123',
    displayName: 'Auckland Trader',
    trustScore: 95,
    isVerified: true,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('PublicProfileScreen displays Xianyu header, trust score, VIP badge, bio and reviews', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const mockProfile = PublicProfileModel(
      id: 'user_123',
      displayName: 'Sarah UoA',
      avatarUrl: null,
      bio: '3rd year CS student. Moving overseas sale! All prices negotiable.',
      city: 'Auckland',
      suburb: 'Grafton',
      trustScore: 96,
      isVip: true,
      isVerified: true,
      isStudentVerified: true,
      studentInstitution: 'University of Auckland',
      rating: 5.0,
      reviewCount: 8,
      activeItemsCount: 2,
      soldItemsCount: 5,
    );

    final mockReviews = [
      PublicReviewModel(
        id: 'rev_1',
        reviewerId: 'reviewer_1',
        reviewerName: 'Liam K.',
        reviewerAvatarUrl: null,
        rating: 5,
        comment: 'Super fast handover outside Kate Edger! Item was in immaculate condition.',
        tags: const ['Punctual', 'Item as described', 'Friendly'],
        role: 'buyer',
        itemTitle: 'Logitech MX Master 3S',
        createdAt: DateTime(2026, 9, 15),
      ),
    ];

    final repo = _FakePublicProfileRepository(
      profile: mockProfile,
      activeItems: [],
      soldItems: [],
      reviews: mockReviews,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<UserRepository>.value(value: repo),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(userRepository: repo),
          ),
        ],
        child: const MaterialApp(
          home: PublicProfileScreen(userId: 'user_123'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify User Display Name & VIP Badge
    expect(find.text('Sarah UoA'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    // Only one VipCrownIcon next to the name, none overlaying avatar
    expect(find.byType(VipCrownIcon), findsOneWidget);
    expect(find.text('University of Auckland'), findsOneWidget);

    // Verify Bio / Signature
    expect(
      find.text('3rd year CS student. Moving overseas sale! All prices negotiable.'),
      findsOneWidget,
    );

    // Verify Location
    expect(find.text('Grafton, Auckland'), findsOneWidget);

    // Verify Trust Score card (Zhima style)
    expect(find.text('Kiwi Trust Score'), findsOneWidget);
    expect(find.text('96 • Needs Improvement'), findsOneWidget);
    expect(find.text('ID Verified'), findsOneWidget);
    expect(find.text('NZ Student'), findsOneWidget);

    // Verify Tabs
    expect(find.text('Selling (0)'), findsOneWidget);
    expect(find.text('Reviews (1)'), findsOneWidget);
    expect(find.text('Sold (0)'), findsOneWidget);

    // Switch to Reviews tab
    await tester.tap(find.text('Reviews (1)'));
    await tester.pumpAndSettle();

    // Verify Review content
    expect(find.text('Liam K.'), findsOneWidget);
    expect(find.text('Buyer'), findsOneWidget);
    expect(
      find.text('Super fast handover outside Kate Edger! Item was in immaculate condition.'),
      findsOneWidget,
    );
    expect(find.text('Punctual'), findsOneWidget);
    expect(find.text('Item as described'), findsOneWidget);
    expect(find.text('Transaction: Logitech MX Master 3S'), findsOneWidget);
  });
}
