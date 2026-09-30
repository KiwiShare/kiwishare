import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/chat_message_model.dart';
import 'package:kiwishare/models/meetup_model.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/providers/meetup_provider.dart';
import 'package:kiwishare/repositories/meetup_repository.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/services/push_notification_service.dart';
import 'package:kiwishare/views/meetups/meetup_qr_screen.dart';
import 'package:kiwishare/views/messages/widgets/location_bubble.dart';
import 'package:kiwishare/views/messages/widgets/meetup_card_bubble.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMeetupRepository implements MeetupRepository {
  MeetupModel? sampleMeetup;
  bool acceptCalled = false;
  bool declineCalled = false;

  @override
  Future<List<MeetupModel>> fetchMyMeetups({required String token}) async {
    return sampleMeetup != null ? [sampleMeetup!] : [];
  }

  @override
  Future<MeetupModel> fetchMeetupDetails({
    required String orderId,
    required String token,
  }) async {
    if (sampleMeetup != null) return sampleMeetup!;
    throw const MeetupRepositoryException('Meetup not found');
  }

  @override
  Future<MeetupModel> proposeMeetup({
    required String itemId,
    String? conversationId,
    required DateTime scheduledAt,
    required String locationName,
    double? latitude,
    double? longitude,
    String? note,
    required String token,
  }) async {
    final m = MeetupModel(
      id: 'order-123',
      orderNumber: 'ORD-123',
      itemId: itemId,
      itemTitle: 'Ergonomic Desk Chair',
      itemPriceNzd: '65',
      itemImageUrl: '',
      status: 'meeting_scheduled',
      role: 'buying',
      sellerId: 'seller-1',
      sellerName: 'Alice',
      buyerId: 'buyer-1',
      buyerName: 'Bob',
      proposalStatus: 'proposed',
      scheduledAt: scheduledAt,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      note: note,
      proposedBy: 'buyer-1',
    );
    sampleMeetup = m;
    return m;
  }

  @override
  Future<MeetupModel> acceptMeetup({
    required String orderId,
    required String token,
    String? messageId,
    DateTime? scheduledAt,
    String? locationName,
  }) async {
    acceptCalled = true;
    final m = sampleMeetup!.copyWith(
      proposalStatus: 'confirmed',
      qrToken: 'QR_HANDOVER_TOKEN_123_abc',
    );
    sampleMeetup = m;
    return m;
  }

  @override
  Future<void> declineMeetup({
    required String orderId,
    required String token,
  }) async {
    declineCalled = true;
    sampleMeetup = sampleMeetup?.copyWith(proposalStatus: 'declined');
  }

  @override
  Future<Map<String, dynamic>> claimHandover({
    required String claimCode,
    String? itemId,
    required String token,
  }) async {
    return {
      'status': 'success',
      'message': 'Ownership transaction verified',
      'item': {
        'id': itemId ?? 'item-123',
        'title': 'Test Item',
        'priceNzd': '50',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> confirmHandover({
    required String orderId,
    required String token,
  }) async {
    final m = sampleMeetup!.copyWith(status: 'completed');
    sampleMeetup = m;
    return {
      'status': 'success',
      'message': 'Handover confirmed successfully.',
      'order': {'id': orderId, 'status': 'completed'},
    };
  }
}

void main() {
  group('Meetup & QR Confirmation Flow Tests', () {
    test(
      'MeetupModel parses correctly from json and identifies status flags',
      () {
        final json = {
          'id': 'ord-1',
          'orderNumber': 'ORD-001',
          'itemId': 'item-1',
          'itemTitle': 'Calculus Textbook',
          'itemPriceNzd': '45',
          'itemImageUrl': 'https://example.com/item.jpg',
          'status': 'meeting_scheduled',
          'role': 'buying',
          'sellerId': 'user-1',
          'sellerName': 'Sarah',
          'buyerId': 'user-2',
          'buyerName': 'Alex',
          'proposalStatus': 'confirmed',
          'scheduledAt': '2026-09-10T14:00:00.000Z',
          'locationName': 'UoA Student Hub',
          'latitude': -36.8519,
          'longitude': 174.7686,
          'proposedBy': 'user-2',
          'qrToken': 'QR_HANDOVER_TOKEN_ord-1_abc123',
          'isPaid': false,
        };

        final meetup = MeetupModel.fromJson(json);
        expect(meetup.id, 'ord-1');
        expect(meetup.isConfirmed, isTrue);
        expect(meetup.isProposed, isFalse);
        expect(meetup.locationName, 'UoA Student Hub');
        expect(meetup.hasCoordinates, isTrue);
        expect(meetup.qrToken, 'QR_HANDOVER_TOKEN_ord-1_abc123');
        expect(meetup.isPaid, isFalse);
      },
    );

    test('MeetupPushMessage parses correctly from push notification data', () {
      final pushData = {
        'type': 'meetup_confirmed',
        'orderId': 'order-999',
        'itemId': 'item-888',
        'itemTitle': 'Scientific Calculator',
        'scheduledAt': '2026-09-12T10:30:00.000Z',
        'locationName': 'General Library 5 Alfred St',
      };

      final push = MeetupPushMessage.fromData(pushData);
      expect(push, isNotNull);
      expect(push!.orderId, 'order-999');
      expect(push.itemTitle, 'Scientific Calculator');
      expect(push.locationName, 'General Library 5 Alfred St');
    });

    testWidgets('LocationBubble renders location pin and coordinates', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationBubble(
              location: const ChatLocationPayload(
                name: 'UoA Student Hub (Alfred Nathan House)',
                latitude: -36.8519,
                longitude: 174.7686,
              ),
              isMine: false,
              createdAt: DateTime.now(),
            ),
          ),
        ),
      );

      expect(
        find.text('UoA Student Hub (Alfred Nathan House)'),
        findsOneWidget,
      );
      expect(find.textContaining('-36.8519'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets(
      'MeetupCardBubble renders proposal details and action buttons',
      (tester) async {
        final fakeRepo = FakeMeetupRepository();
        final provider = MeetupProvider(repository: fakeRepo);
        final authProvider = AuthProvider(userRepository: MockUserRepository());

        final payload = ChatMeetupPayload(
          orderId: 'order-123',
          scheduledAt: DateTime(2026, 9, 10, 14, 0),
          locationName: 'UoA Engineering Quad',
          latitude: -36.8520,
          longitude: 174.7703,
          proposalStatus: 'proposed',
          proposedBy: 'other-user',
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: provider),
              ChangeNotifierProvider.value(value: authProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: MeetupCardBubble(
                  meetup: payload,
                  isMine: false,
                  createdAt: DateTime.now(),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Meetup Proposal'), findsOneWidget);
        expect(find.text('UoA Engineering Quad'), findsOneWidget);
        expect(find.byKey(const Key('meetup_map_order-123')), findsOneWidget);
        expect(find.text('Open map'), findsOneWidget);
        expect(find.text('Accept'), findsOneWidget);
        expect(find.text('Decline'), findsOneWidget);
      },
    );

    testWidgets(
      'MeetupQrScreen renders confirmed schedule, QR code, and reserved payment section',
      (tester) async {
        final fakeRepo = FakeMeetupRepository();
        final meetup = MeetupModel(
          id: 'order-456',
          orderNumber: 'ORD-456',
          itemId: 'item-456',
          itemTitle: 'Vintage Leather Jacket',
          itemPriceNzd: '120',
          itemImageUrl: '',
          status: 'meeting_scheduled',
          role: 'buying',
          sellerId: 'seller-1',
          sellerName: 'Emma Watson',
          buyerId: 'buyer-1',
          buyerName: 'Current User',
          proposalStatus: 'confirmed',
          scheduledAt: DateTime(2026, 9, 15, 15, 30),
          locationName: 'Britomart Transport Centre',
          latitude: -36.8443,
          longitude: 174.7684,
          qrToken: 'QR_HANDOVER_TOKEN_order-456_testtoken',
          paymentConfirmed: true,
        );
        fakeRepo.sampleMeetup = meetup;

        final provider = MeetupProvider(repository: fakeRepo);
        final authProvider = AuthProvider(userRepository: MockUserRepository());

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: provider),
              ChangeNotifierProvider.value(value: authProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: MeetupQrScreen(
                  orderId: 'order-456',
                  initialMeetup: meetup,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check header and item
        expect(find.text('Vintage Leather Jacket'), findsOneWidget);
        expect(find.text('Britomart Transport Centre'), findsOneWidget);
        expect(
          find.text('Ready for Handover · QR Code Unlocked'),
          findsOneWidget,
        );

        // Check QR code card
        expect(find.byKey(const Key('meetup_qr_image')), findsOneWidget);
        expect(find.text('Copy verification token'), findsOneWidget);
        expect(find.byKey(const Key('buyer_scan_qr_button')), findsOneWidget);

        // Check Direct Confirmation Action
        expect(
          find.byKey(const Key('buyer_confirm_receipt_button')),
          findsOneWidget,
        );
        expect(find.text('Confirm Receipt'), findsOneWidget);
      },
    );

    testWidgets('an unpaid meetup cannot unlock handover with a QR token', (
      tester,
    ) async {
      final meetup = MeetupModel(
        id: 'order-unpaid',
        orderNumber: 'ORD-UNPAID',
        itemId: 'item-unpaid',
        itemTitle: 'Desk Lamp',
        itemPriceNzd: '45',
        itemImageUrl: '',
        status: 'meeting_scheduled',
        role: 'buying',
        sellerId: 'seller-1',
        sellerName: 'Seller',
        buyerId: 'buyer-1',
        buyerName: 'Buyer',
        proposalStatus: 'confirmed',
        scheduledAt: DateTime(2026, 9, 20, 10),
        locationName: 'Student Hub',
        qrToken: 'QR_HANDOVER_TOKEN_order-unpaid_test',
        paymentConfirmed: false,
      );
      final repository = FakeMeetupRepository()..sampleMeetup = meetup;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => MeetupProvider(repository: repository),
            ),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(userRepository: MockUserRepository()),
            ),
          ],
          child: MaterialApp(
            home: MeetupQrScreen(orderId: meetup.id, initialMeetup: meetup),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('payment_required_gate_card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('meetup_qr_image')), findsNothing);
      expect(
        find.byKey(const Key('buyer_confirm_receipt_button')),
        findsNothing,
      );
    });

    testWidgets(
      'MeetupCardBubble renders distinct actions for seller and buyer when confirmed',
      (tester) async {
        final fakeRepo = FakeMeetupRepository();
        fakeRepo.sampleMeetup = MeetupModel(
          id: 'order-789',
          orderNumber: 'ORD-789',
          itemId: 'item-789',
          itemTitle: 'Vintage Lamp',
          itemPriceNzd: '45',
          itemImageUrl: '',
          status: 'paid',
          role: 'selling',
          sellerId: 'seller-1',
          sellerName: 'Alice',
          buyerId: 'buyer-1',
          buyerName: 'Bob',
          proposalStatus: 'confirmed',
          scheduledAt: DateTime(2026, 9, 20, 10, 0),
          locationName: 'Ponsonby Central',
          qrToken: 'QR_HANDOVER_TOKEN_789',
        );
        final provider = MeetupProvider(repository: fakeRepo);
        await provider.loadMyMeetups('test-token');
        final authProvider = AuthProvider(userRepository: MockUserRepository());

        final payload = ChatMeetupPayload(
          orderId: 'order-789',
          scheduledAt: DateTime(2026, 9, 20, 10, 0),
          locationName: 'Ponsonby Central',
          proposalStatus: 'confirmed',
        );

        // 1. Render as Seller (isBuyer = false)
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: provider),
              ChangeNotifierProvider.value(value: authProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: MeetupCardBubble(
                  meetup: payload,
                  isMine: true,
                  isBuyer: false,
                  createdAt: DateTime.now(),
                ),
              ),
            ),
          ),
        );

        expect(find.text('View Order Progress'), findsOneWidget);
        expect(find.text('Handover check-in'), findsOneWidget);
        expect(find.text('Scan at handover'), findsNothing);

        // 2. Render as Buyer (isBuyer = true)
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: provider),
              ChangeNotifierProvider.value(value: authProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: MeetupCardBubble(
                  meetup: payload,
                  isMine: false,
                  isBuyer: true,
                  createdAt: DateTime.now(),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Scan at handover'), findsOneWidget);
        expect(find.text('View Order Progress'), findsOneWidget);
        expect(find.text('Handover check-in'), findsNothing);
      },
    );

    testWidgets(
      'MeetupCardBubble updates immediately to confirmed state upon tapping Accept',
      (tester) async {
        final fakeRepo = FakeMeetupRepository();
        fakeRepo.sampleMeetup = MeetupModel(
          id: 'order-123',
          orderNumber: 'ORD-123',
          itemId: 'item-1',
          itemTitle: 'Item',
          itemPriceNzd: '20',
          itemImageUrl: '',
          status: 'meeting_scheduled',
          role: 'selling',
          sellerId: 'user-1',
          sellerName: 'User',
          buyerId: 'buyer-1',
          buyerName: 'Buyer',
          proposalStatus: 'confirmed',
          scheduledAt: DateTime(2026, 9, 20, 14, 0),
          locationName: 'UoA Student Hub',
        );
        SharedPreferences.setMockInitialValues({
          'jwt_token': 'mock-jwt-token',
          'current_user':
              '{"id":"user-1","displayName":"User","trustScore":100,"isVerified":true}',
        });
        final provider = MeetupProvider(repository: fakeRepo);
        final authProvider = AuthProvider(userRepository: MockUserRepository());

        final payload = ChatMeetupPayload(
          orderId: 'order-123',
          scheduledAt: DateTime(2026, 9, 20, 14, 0),
          locationName: 'UoA Student Hub',
          proposalStatus: 'proposed',
          proposedBy: 'buyer-1',
        );

        bool statusChangedCalled = false;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: provider),
              ChangeNotifierProvider.value(value: authProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: MeetupCardBubble(
                  meetup: payload,
                  isMine: false,
                  isBuyer: false,
                  createdAt: DateTime.now(),
                  onStatusChanged: () => statusChangedCalled = true,
                ),
              ),
            ),
          ),
        );

        expect(find.text('Meetup Proposal'), findsOneWidget);
        expect(find.text('Accept'), findsOneWidget);

        // Tap accept
        await tester.tap(find.text('Accept'));
        await tester.pumpAndSettle();

        expect(fakeRepo.acceptCalled, isTrue);
        expect(statusChangedCalled, isTrue);
        // Card immediately transitions to Confirmed
        expect(find.text('Meetup Confirmed'), findsOneWidget);
        expect(
          find.text('Awaiting buyer payment to unlock handover QR'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'MeetupCardBubble respects onBeforeAccept callback when acceptance is aborted',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'jwt_token': 'mock-jwt-token',
          'current_user':
              '{"id":"user-1","displayName":"User","trustScore":100,"isVerified":true}',
        });
        final fakeRepo = FakeMeetupRepository();
        final provider = MeetupProvider(repository: fakeRepo);
        final authProvider = AuthProvider(userRepository: MockUserRepository());

        final payload = ChatMeetupPayload(
          orderId: 'order-123',
          scheduledAt: DateTime(2026, 9, 20, 14, 0),
          locationName: 'UoA Student Hub',
          proposalStatus: 'proposed',
          proposedBy: 'buyer-1',
        );

        bool promptShowed = false;

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: provider),
              ChangeNotifierProvider.value(value: authProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: MeetupCardBubble(
                  meetup: payload,
                  isMine: false,
                  isBuyer: false,
                  createdAt: DateTime.now(),
                  onBeforeAccept: () async {
                    promptShowed = true;
                    return false; // user cancelled in dialog
                  },
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Accept'));
        await tester.pumpAndSettle();

        expect(promptShowed, isTrue);
        expect(fakeRepo.acceptCalled, isFalse);
        // Remains proposed because user rejected confirmation
        expect(find.text('Meetup Proposal'), findsOneWidget);
      },
    );

    testWidgets(
      'MeetupCardBubble displays superseded/cancelled state without action buttons',
      (tester) async {
        final fakeRepo = FakeMeetupRepository();
        final provider = MeetupProvider(repository: fakeRepo);
        final authProvider = AuthProvider(userRepository: MockUserRepository());

        final payload = ChatMeetupPayload(
          orderId: 'order-123',
          scheduledAt: DateTime(2026, 9, 20, 14, 0),
          locationName: 'UoA Student Hub',
          proposalStatus: 'cancelled',
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: provider),
              ChangeNotifierProvider.value(value: authProvider),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: MeetupCardBubble(
                  meetup: payload,
                  isMine: false,
                  isBuyer: false,
                  createdAt: DateTime.now(),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Meetup Cancelled'), findsOneWidget);
        expect(
          find.text('This proposal was superseded or cancelled.'),
          findsOneWidget,
        );
        expect(find.text('Accept'), findsNothing);
      },
    );
  });
}
