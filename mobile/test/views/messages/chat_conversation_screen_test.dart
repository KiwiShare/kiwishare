import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/models/chat_message_model.dart';
import 'package:kiwishare/models/report_draft.dart';
import 'package:kiwishare/models/order_model.dart';
import 'package:kiwishare/navigation/app_route_observer.dart';
import 'package:kiwishare/config/api_config.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/providers/order_provider.dart';
import 'package:kiwishare/repositories/chat_repository.dart';
import 'package:kiwishare/repositories/order_repository.dart';
import 'package:kiwishare/services/chat_photo_upload_service.dart';
import 'package:kiwishare/services/chat_voice_service.dart';
import 'package:kiwishare/services/listing_image_picker.dart';
import 'package:kiwishare/services/notification_permission_coordinator.dart';
import 'package:kiwishare/services/push_notification_service.dart';
import 'package:provider/provider.dart';
import 'package:kiwishare/providers/auth_provider.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/views/messages/chat_conversation_screen.dart';
import 'package:kiwishare/views/profile/payment_methods_screen.dart';
import 'package:kiwishare/views/profile/public_profile_screen.dart';
import 'package:kiwishare/views/profile/report_screen.dart';
import 'package:kiwishare/views/shared/widgets/review_bottom_sheet.dart';
import 'package:kiwishare/widgets/notification_permission_dialog.dart';

import '../../support/fake_chat_photo_uploader.dart';
import '../../support/fake_chat_repository.dart';
import '../../support/fake_chat_voice_service.dart';

Widget _buildSubject({
  required FakeChatRepository repository,
  ChatConversationModel? conversation,
  String? authToken = 'valid-token',
  TextScaler textScaler = TextScaler.noScaling,
  EdgeInsets viewPadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  ChatPhotoUploader? photoUploader,
  ListingImagePicker? imagePicker,
  ChatVoiceUploader? voiceUploader,
  ChatVoiceRecorder? voiceRecorder,
  NotificationPermissionCoordinator? permissionCoordinator,
  bool enablePolling = false,
  Duration? pollingInterval,
}) {
  final value = conversation ?? testConversation();
  return MaterialApp(
    navigatorObservers: [appRouteObserver],
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF064B3A)),
    ),
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: textScaler,
        padding: viewInsets == EdgeInsets.zero ? viewPadding : EdgeInsets.zero,
        viewPadding: viewPadding,
        viewInsets: viewInsets,
      ),
      child: ChatConversationScreen(
        conversation: value,
        chatProvider: ChatProvider(
          repository: repository,
          photoUploader: photoUploader,
          voiceUploader: voiceUploader,
        ),
        authToken: authToken,
        imagePicker: imagePicker,
        voiceRecorder: voiceRecorder,
        permissionCoordinator: permissionCoordinator,
        enablePolling: enablePolling,
        pollingInterval: pollingInterval,
      ),
    ),
  );
}

class _ConversationOrderRepository implements OrderRepository {
  _ConversationOrderRepository(this.orders);

  final List<OrderModel> orders;

  @override
  Future<List<OrderModel>> fetchMyOrders({
    required String token,
    String? type,
    String? status,
  }) async => orders;

  @override
  Future<OrderModel> fetchOrderDetails({
    required String orderId,
    required String token,
  }) async => orders.firstWhere((order) => order.id == orderId);

  @override
  Future<OrderModel> createOrGetOrder({
    required String itemId,
    required String token,
  }) async => orders.first;

  @override
  Future<OrderModel> refundOrder({
    required String orderId,
    required String token,
    String? reason,
  }) async => orders.firstWhere((order) => order.id == orderId);
}

void main() {
  testWidgets('loads private history and marks incoming messages read', (
    tester,
  ) async {
    final conversation = testConversation(unreadCount: 2);
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(id: '1', text: 'Is the chair available?', isMine: false),
          testMessage(id: '2', text: 'Yes, it is.', isMine: true),
        ],
      },
    );
    await tester.pumpWidget(
      _buildSubject(repository: repository, conversation: conversation),
    );
    await tester.pumpAndSettle();

    expect(repository.messageFetches, 1);
    expect(repository.markReadCalls, 1);
    expect(
      find.byKey(const Key('conversation_participant_name')),
      findsOneWidget,
    );
    expect(find.text('Sophie M.'), findsOneWidget);
    expect(find.text('Ergonomic Office Chair'), findsOneWidget);
    expect(find.byKey(const Key('chat_message_1')), findsOneWidget);
    expect(find.byKey(const Key('chat_message_2')), findsOneWidget);
  });

  testWidgets('opens the shared report form with chat participant context', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject(repository: FakeChatRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_more_actions')));
    await tester.pumpAndSettle();
    expect(find.text('Report user'), findsOneWidget);

    await tester.tap(find.text('Report user'));
    await tester.pumpAndSettle();

    final reportScreen = tester.widget<ReportScreen>(find.byType(ReportScreen));
    expect(reportScreen.reportContext.targetType, ReportTargetType.user);
    expect(reportScreen.reportContext.targetId, 'participant-conversation-1');
    expect(reportScreen.reportContext.targetLabel, 'Sophie M.');
    expect(reportScreen.reportContext.contextType, ReportContextType.chat);
    expect(reportScreen.reportContext.contextId, 'conversation-1');
    expect(
      reportScreen.reportContext.contextLabel,
      'Chat about Ergonomic Office Chair',
    );
    expect(find.text('Sophie M.'), findsOneWidget);
    expect(find.text('Chat about Ergonomic Office Chair'), findsOneWidget);

    await tester.tap(find.byKey(const Key('report_reason_field')));
    await tester.pumpAndSettle();
    expect(find.text('Scam or fraud'), findsOneWidget);
    expect(find.text('Harassment or abusive behaviour'), findsOneWidget);
    expect(find.text('Unsafe meetup behaviour'), findsOneWidget);
    expect(find.text('Fake identity or impersonation'), findsOneWidget);
    expect(find.text('Something else'), findsOneWidget);
    expect(find.text('Repeatedly did not show up'), findsNothing);
    expect(find.text('Suspicious payment request'), findsNothing);
    expect(find.text('Asked to move off KiwiShare'), findsNothing);
  });

  testWidgets('does not offer reporting when signed out', (tester) async {
    await tester.pumpWidget(
      _buildSubject(repository: FakeChatRepository(), authToken: null),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_more_actions')));
    await tester.pumpAndSettle();
    expect(find.text('Report user'), findsNothing);
  });

  testWidgets('does not mark an in-flight initial load read after navigation', (
    tester,
  ) async {
    final pendingMessages = Completer<ChatMessagePage>();
    final repository = FakeChatRepository()
      ..messageCompleters.add(pendingMessages);
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        conversation: testConversation(unreadCount: 1),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(repository.messageFetches, 1);

    final context = tester.element(find.byType(ChatConversationScreen));
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covering route')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    pendingMessages.complete(
      ChatMessagePage(
        messages: [testMessage(id: '1', text: 'Unseen', isMine: false)],
        hasMore: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.markReadCalls, 0);
  });

  testWidgets('marks deferred messages after returning to the chat', (
    tester,
  ) async {
    final pendingMessages = Completer<ChatMessagePage>();
    final incoming = testMessage(id: '1', text: 'Deferred', isMine: false);
    final repository = FakeChatRepository()
      ..messageCompleters.add(pendingMessages);
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        conversation: testConversation(unreadCount: 1),
      ),
    );
    await tester.pump();
    await tester.pump();

    final context = tester.element(find.byType(ChatConversationScreen));
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covering route')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    repository.messages['conversation-1'] = [incoming];
    pendingMessages.complete(
      ChatMessagePage(messages: [incoming], hasMore: false),
    );
    await tester.pump();
    expect(repository.markReadCalls, 0);

    Navigator.of(tester.element(find.text('Covering route'))).pop();
    await tester.pumpAndSettle();

    expect(repository.messageFetches, 2);
    expect(repository.markReadCalls, 1);
  });

  testWidgets('does not mark an in-flight load read while backgrounded', (
    tester,
  ) async {
    final pendingMessages = Completer<ChatMessagePage>();
    final incoming = testMessage(id: '1', text: 'Backgrounded', isMine: false);
    final repository = FakeChatRepository()
      ..messageCompleters.add(pendingMessages);
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        conversation: testConversation(unreadCount: 1),
      ),
    );
    await tester.pump();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    repository.messages['conversation-1'] = [incoming];
    pendingMessages.complete(
      ChatMessagePage(messages: [incoming], hasMore: false),
    );
    await tester.pump();

    expect(repository.markReadCalls, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repository.messageFetches, 2);
    expect(repository.markReadCalls, 1);
  });

  testWidgets('shows Read only under the latest sent message when viewed', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(
            id: '1',
            text: 'First sent',
            isMine: true,
            status: 'read',
            readAt: DateTime.utc(2026, 8, 27, 8, 31),
          ),
          testMessage(
            id: '2',
            text: 'Latest sent',
            isMine: true,
            status: 'read',
            readAt: DateTime.utc(2026, 8, 27, 8, 32),
          ),
          testMessage(id: '3', text: 'Reply', isMine: false, status: 'read'),
        ],
      },
    );

    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_read_receipt_1')), findsNothing);
    expect(find.byKey(const Key('chat_read_receipt_2')), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.bySemanticsLabel('You sent Latest sent, read'), findsOneWidget);
  });

  testWidgets('does not show a stale receipt when the latest send is unread', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(id: '1', text: 'Viewed', isMine: true, status: 'read'),
          testMessage(id: '2', text: 'Waiting', isMine: true),
        ],
      },
    );

    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsNothing);
  });

  testWidgets('shows a read receipt for the latest sent location', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(
            id: '1',
            text: 'Shared location',
            isMine: true,
            type: 'location',
            location: const ChatLocationPayload(
              name: 'Auckland Library',
              latitude: -36.8521,
              longitude: 174.7692,
            ),
            status: 'read',
          ),
        ],
      },
    );

    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_location_1')), findsOneWidget);
    expect(find.byKey(const Key('chat_read_receipt_1')), findsOneWidget);
  });

  testWidgets('shows a read receipt for the latest sent meetup card', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(
            id: '1',
            text: 'Meetup proposed',
            isMine: true,
            type: 'meetup',
            meetup: ChatMeetupPayload(
              orderId: 'order-1',
              scheduledAt: DateTime.utc(2026, 8, 28, 2),
              locationName: 'Auckland Library',
              proposalStatus: 'confirmed',
            ),
            status: 'read',
          ),
        ],
      },
    );

    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_meetup_card_1')), findsOneWidget);
    expect(find.byKey(const Key('chat_read_receipt_1')), findsOneWidget);
  });

  testWidgets(
    'pending order without a confirmed meetup never renders Meetup Scheduled',
    (tester) async {
      final orderProvider = OrderProvider(
        repository: _ConversationOrderRepository([
          OrderModel(
            id: 'order-pending',
            orderNumber: 'ORD-PENDING',
            status: 'pending_payment',
            role: 'buying',
            itemId: 'item-conversation-1',
            item: const OrderItemInfo(
              id: 'item-conversation-1',
              title: 'Ergonomic Office Chair',
              priceNzd: '65.00',
              imageUrl: '',
            ),
            counterparty: const OrderCounterparty(
              id: 'participant-conversation-1',
              displayName: 'Sophie M.',
              role: 'seller',
            ),
            createdAt: DateTime.utc(2026, 9, 29),
            updatedAt: DateTime.utc(2026, 9, 29),
          ),
        ]),
      );
      await orderProvider.loadMyOrders('valid-token');

      await tester.pumpWidget(
        ChangeNotifierProvider<OrderProvider>.value(
          value: orderProvider,
          child: _buildSubject(repository: FakeChatRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Meetup Scheduled'), findsNothing);
      expect(find.textContaining('Transaction Ready'), findsNothing);
      expect(find.text('Payment Complete — Schedule Handover'), findsNothing);
    },
  );

  testWidgets(
    'treats a meetup proposal as a proposal until the other person confirms it',
    (tester) async {
      final repository = FakeChatRepository(
        messages: {
          'conversation-1': [
            testMessage(
              id: '10',
              text: 'Meetup proposed',
              isMine: true,
              type: 'meetup',
              meetup: ChatMeetupPayload(
                orderId: 'order-proposal-1',
                scheduledAt: DateTime.utc(2026, 9, 30, 1),
                locationName: 'Auckland Central Library',
                latitude: -36.8527,
                longitude: 174.7660,
                proposalStatus: 'proposed',
              ),
            ),
          ],
        },
      );

      await tester.pumpWidget(_buildSubject(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Meetup Proposal Sent'), findsOneWidget);
      expect(find.textContaining('Meetup Scheduled'), findsNothing);
      expect(find.text('Waiting for response...'), findsNothing);
      expect(
        find.text('Proposal sent. The other person can accept or decline it.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('meetup_map_order-proposal-1')),
        findsOneWidget,
      );
    },
  );

  testWidgets('refreshes read receipts after returning from the background', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [testMessage(id: '1', text: 'Waiting', isMine: true)],
      },
    );
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsNothing);

    repository.messages['conversation-1'] = [
      testMessage(
        id: '1',
        text: 'Waiting',
        isMine: true,
        status: 'read',
        readAt: DateTime.utc(2026, 8, 27, 8, 31),
      ),
    ];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repository.messageFetches, 2);
    expect(find.byKey(const Key('chat_read_receipt_1')), findsOneWidget);
  });

  testWidgets('does not refresh a covered chat when the app resumes', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [testMessage(id: '1', text: 'Waiting', isMine: true)],
      },
    );
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ChatConversationScreen));
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Covering route')),
      ),
    );
    await tester.pumpAndSettle();
    repository.messages['conversation-1'] = [
      testMessage(id: '1', text: 'Waiting', isMine: true, status: 'read'),
    ];

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(repository.messageFetches, 1);
  });

  testWidgets('photo sheet removes and restores actual chat visibility', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();
    expect(
      chatVisibilityTracker.isVisible(
        conversationId: 'conversation-1',
        sessionToken: 'valid-token',
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('chat_action_panel_toggle_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_add_photo_button')));
    await tester.pumpAndSettle();
    expect(find.text('Send a photo'), findsOneWidget);
    expect(
      chatVisibilityTracker.isVisible(
        conversationId: 'conversation-1',
        sessionToken: 'valid-token',
      ),
      isFalse,
    );

    Navigator.of(tester.element(find.text('Send a photo'))).pop();
    await tester.pumpAndSettle();
    expect(
      chatVisibilityTracker.isVisible(
        conversationId: 'conversation-1',
        sessionToken: 'valid-token',
      ),
      isTrue,
    );
  });

  testWidgets('keeps voice playback exposed to accessibility services', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(
            id: '1',
            text: '',
            isMine: false,
            type: 'voice',
            audioUrl: 'https://example.test/voice.m4a',
            durationMs: 4000,
          ),
        ],
      },
    );

    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    final playButton = find.byKey(const Key('chat_voice_play_1'));
    expect(playButton, findsOneWidget);
    expect(
      tester
          .getSemantics(playButton)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('aligns received content left and sent content right', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(id: '1', text: 'Hi', isMine: false),
          testMessage(id: '2', text: 'Mine', isMine: true),
        ],
      },
    );
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    final receivedBubble = find.byKey(const Key('chat_message_1'));
    final sentBubble = find.byKey(const Key('chat_message_2'));
    expect(
      tester.getTopLeft(receivedBubble).dx,
      lessThan(tester.getTopLeft(sentBubble).dx),
    );

    final receivedLabels = find.descendant(
      of: receivedBubble,
      matching: find.byType(Text),
    );
    expect(receivedLabels, findsNWidgets(2));
    expect(
      tester.getTopLeft(receivedLabels.at(0)).dx,
      closeTo(tester.getTopLeft(receivedLabels.at(1)).dx, 0.1),
    );

    final sentLabels = find.descendant(
      of: sentBubble,
      matching: find.byType(Text),
    );
    expect(sentLabels, findsNWidgets(2));
    expect(
      tester.getBottomRight(sentLabels.at(0)).dx,
      closeTo(tester.getBottomRight(sentLabels.at(1)).dx, 0.1),
    );
  });

  testWidgets('shows the empty state for a newly created conversation', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(repository.messageFetches, 1);
    expect(repository.markReadCalls, 0);
    expect(find.byKey(const Key('conversation_empty_state')), findsOneWidget);
    expect(find.byKey(const Key('conversation_error_state')), findsNothing);
  });

  testWidgets('keeps the retry state for a genuine history fetch failure', (
    tester,
  ) async {
    final repository = FakeChatRepository()
      ..messageError = const ChatRepositoryException(
        'Messages could not be loaded. Please try again.',
      );
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation_error_state')), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    repository.messageError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.messageFetches, 2);
    expect(find.byKey(const Key('conversation_empty_state')), findsOneWidget);
    expect(find.byKey(const Key('conversation_error_state')), findsNothing);
  });

  testWidgets(
    'appends to fixed-length history and clears the composer after API success',
    (tester) async {
      final repository = FakeChatRepository();
      await tester.pumpWidget(_buildSubject(repository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('chat_message_input')),
        '  Can I collect this tomorrow?  ',
      );
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      expect(repository.sendCalls, 1);
      expect(repository.sentTexts, ['Can I collect this tomorrow?']);
      expect(find.text('Can I collect this tomorrow?'), findsOneWidget);
      final input = tester.widget<TextField>(
        find.byKey(const Key('chat_message_input')),
      );
      expect(input.controller?.text, isEmpty);
    },
  );

  testWidgets(
    'persists a text message before offering permission and decline is independent',
    (tester) async {
      final repository = FakeChatRepository();
      final permissionController = _FakePermissionController();
      final coordinator = NotificationPermissionCoordinator(
        permissionController: permissionController,
        storage: _MemoryPermissionStorage(),
      );
      await tester.pumpWidget(
        _buildSubject(
          repository: repository,
          permissionCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('chat_message_input')),
        'Persist before permission',
      );
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();

      expect(repository.sentTexts, ['Persist before permission']);
      expect(find.text('Persist before permission'), findsOneWidget);
      expect(
        find.byKey(NotificationPermissionDialogKeys.dialog),
        findsOneWidget,
      );
      expect(permissionController.requestCalls, 0);

      await tester.tap(find.byKey(NotificationPermissionDialogKeys.dismiss));
      await tester.pumpAndSettle();

      expect(repository.sentTexts, ['Persist before permission']);
      expect(find.text('Persist before permission'), findsOneWidget);
      expect(permissionController.requestCalls, 0);
    },
  );

  testWidgets(
    'permission failure cannot turn a successful message into failure',
    (tester) async {
      final repository = FakeChatRepository();
      final permissionController = _FakePermissionController()
        ..failRequest = true;
      final coordinator = NotificationPermissionCoordinator(
        permissionController: permissionController,
        storage: _MemoryPermissionStorage(),
      );
      await tester.pumpWidget(
        _buildSubject(
          repository: repository,
          permissionCoordinator: coordinator,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('chat_message_input')),
        'Permission is best effort',
      );
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(NotificationPermissionDialogKeys.enable));
      await tester.pumpAndSettle();

      expect(repository.sentTexts, ['Permission is best effort']);
      expect(find.text('Permission is best effort'), findsOneWidget);
      expect(find.byKey(const Key('conversation_inline_error')), findsNothing);
      expect(permissionController.requestCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed message send never offers notification permission', (
    tester,
  ) async {
    final repository = FakeChatRepository()
      ..sendError = const ChatRepositoryException('Message send failed.');
    final permissionController = _FakePermissionController();
    final coordinator = NotificationPermissionCoordinator(
      permissionController: permissionController,
      storage: _MemoryPermissionStorage(),
    );
    await tester.pumpWidget(
      _buildSubject(repository: repository, permissionCoordinator: coordinator),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat_message_input')),
      'This does not persist',
    );
    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation_inline_error')), findsOneWidget);
    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsNothing);
    expect(permissionController.statusCalls, 0);
    expect(permissionController.requestCalls, 0);
  });

  testWidgets('rapid text sends create only one contextual rationale', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final permissionController = _FakePermissionController();
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        permissionCoordinator: NotificationPermissionCoordinator(
          permissionController: permissionController,
          storage: _MemoryPermissionStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chat_message_input')), 'Once');

    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.pumpAndSettle();

    expect(repository.sendCalls, 1);
    expect(find.byKey(NotificationPermissionDialogKeys.dialog), findsOneWidget);
    expect(permissionController.statusCalls, 1);
  });

  testWidgets('route disposal while permission status is pending is safe', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final status = Completer<PushPermissionStatus>();
    final permissionController = _FakePermissionController()
      ..statusCompleter = status;
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        permissionCoordinator: NotificationPermissionCoordinator(
          permissionController: permissionController,
          storage: _MemoryPermissionStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chat_message_input')),
      'Persist then leave',
    );
    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('Different route')));
    status.complete(PushPermissionStatus.notDetermined);
    await tester.pumpAndSettle();

    expect(repository.sentTexts, ['Persist then leave']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful location send is rendered before permission lookup', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final permissionController = _FakePermissionController()
      ..status = PushPermissionStatus.denied;
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        permissionCoordinator: NotificationPermissionCoordinator(
          permissionController: permissionController,
          storage: _MemoryPermissionStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_action_panel_toggle_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_share_location_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UoA General Library (5 Alfred St)'));
    await tester.pumpAndSettle();

    expect(find.text('UoA General Library (5 Alfred St)'), findsOneWidget);
    expect(permissionController.statusCalls, 1);
  });

  testWidgets('chooses, uploads, sends, and renders a gallery photo', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatPhotoUploader();
    final picker = _FakeChatImagePicker();
    final permissionController = _FakePermissionController()
      ..status = PushPermissionStatus.denied;
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        photoUploader: uploader,
        imagePicker: picker,
        permissionCoordinator: NotificationPermissionCoordinator(
          permissionController: permissionController,
          storage: _MemoryPermissionStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_action_panel_toggle_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_add_photo_button')));
    await tester.pumpAndSettle();
    expect(find.text('Send a photo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat_choose_photo_option')));
    await tester.pumpAndSettle();

    expect(picker.galleryCalls, 1);
    expect(uploader.uploadCalls, 1);
    expect(uploader.uploadedFileName, endsWith('.png'));
    expect(uploader.uploadedContentType, 'image/png');
    expect(repository.sentImageUrls, [uploader.url]);
    expect(find.byKey(const Key('chat_message_image_sent-1')), findsOneWidget);
    expect(permissionController.statusCalls, 1);
  });

  testWidgets('recovers and sends a photo after Android recreates the screen', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatPhotoUploader();
    final picker = _FakeChatImagePicker(
      lostPhotos: [
        XFile.fromData(
          Uint8List.fromList([4, 5, 6]),
          name: 'recovered.jpg',
          mimeType: 'image/jpeg',
        ),
      ],
    );
    final permissionController = _FakePermissionController();

    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        photoUploader: uploader,
        imagePicker: picker,
        permissionCoordinator: NotificationPermissionCoordinator(
          permissionController: permissionController,
          storage: _MemoryPermissionStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(picker.recoveryCalls, 1);
    expect(uploader.uploadCalls, 1);
    expect(uploader.uploadedFileName, endsWith('.jpg'));
    expect(uploader.uploadedBytes, Uint8List.fromList([4, 5, 6]));
    expect(repository.sentImageUrls, [uploader.url]);
    expect(permissionController.statusCalls, 0);
  });

  testWidgets('records, uploads, sends, and renders a voice message', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatVoiceUploader();
    final recorder = FakeChatVoiceRecorder();
    final permissionController = _FakePermissionController()
      ..status = PushPermissionStatus.denied;
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        voiceUploader: uploader,
        voiceRecorder: recorder,
        permissionCoordinator: NotificationPermissionCoordinator(
          permissionController: permissionController,
          storage: _MemoryPermissionStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    expect(recorder.startCalls, 0);
    expect(find.byKey(const Key('chat_voice_hold_tab')), findsOneWidget);
    expect(find.text('Hold to Talk'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat_hold_to_talk_button'))),
    );
    await tester.pump();
    expect(recorder.startCalls, 1);
    expect(find.byKey(const Key('chat_voice_recording_timer')), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
    expect(uploader.uploadCalls, 1);
    expect(repository.sentAudioUrls, [uploader.url]);
    expect(find.byKey(const Key('chat_voice_play_sent-1')), findsOneWidget);
    expect(find.text('0:04'), findsOneWidget);
    expect(permissionController.statusCalls, 1);
  });

  testWidgets('holding the voice tab and releasing sends the recording', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatVoiceUploader();
    final recorder = FakeChatVoiceRecorder();
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        voiceUploader: uploader,
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat_hold_to_talk_button'))),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(recorder.startCalls, 1);
    expect(recorder.stopCalls, 1);
    expect(uploader.uploadCalls, 1);
    expect(repository.sentAudioUrls, [uploader.url]);
  });

  testWidgets('sliding up then releasing cancels a voice message', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatVoiceUploader();
    final recorder = FakeChatVoiceRecorder();
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        voiceUploader: uploader,
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat_hold_to_talk_button'))),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(find.textContaining('release to cancel'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(recorder.cancelCalls, 1);
    expect(uploader.uploadCalls, 0);
    expect(repository.sentAudioUrls, isEmpty);
    expect(find.byKey(const Key('chat_voice_recording_timer')), findsNothing);
    expect(find.byKey(const Key('chat_voice_hold_tab')), findsOneWidget);
  });

  testWidgets('voice mode switches back to the text composer', (tester) async {
    await tester.pumpWidget(_buildSubject(repository: FakeChatRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    expect(find.byKey(const Key('chat_voice_hold_tab')), findsOneWidget);
    expect(find.byKey(const Key('chat_message_input')), findsNothing);

    await tester.tap(find.byKey(const Key('chat_keyboard_mode_button')));
    await tester.pump();
    expect(find.byKey(const Key('chat_message_input')), findsOneWidget);
    expect(find.byKey(const Key('chat_voice_hold_tab')), findsNothing);
  });

  testWidgets('auto-stops with headroom before the hard duration limit', (
    tester,
  ) async {
    final repository = FakeChatRepository();
    final uploader = FakeChatVoiceUploader();
    final recorder = FakeChatVoiceRecorder();
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        voiceUploader: uploader,
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat_hold_to_talk_button'))),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 59));
    await tester.pumpAndSettle();

    expect(recorder.stopCalls, 1);
    expect(uploader.uploadCalls, 1);
    expect(find.byKey(const Key('chat_voice_recording_timer')), findsNothing);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('keeps hold-to-talk locked while stop is finalizing', (
    tester,
  ) async {
    final stopGate = Completer<void>();
    final recorder = FakeChatVoiceRecorder(stopGate: stopGate);
    await tester.pumpWidget(
      _buildSubject(
        repository: FakeChatRepository(),
        voiceUploader: FakeChatVoiceUploader(),
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat_hold_to_talk_button'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final holdSurface = tester.widget<Listener>(
      find.byKey(const Key('chat_hold_to_talk_button')),
    );
    expect(holdSurface.onPointerDown, isNull);
    stopGate.complete();
    await tester.pumpAndSettle();
    expect(recorder.startCalls, 1);
  });

  testWidgets('keeps hold-to-talk locked while cancel is finalizing', (
    tester,
  ) async {
    final cancelGate = Completer<void>();
    final recorder = FakeChatVoiceRecorder(cancelGate: cancelGate);
    await tester.pumpWidget(
      _buildSubject(
        repository: FakeChatRepository(),
        voiceUploader: FakeChatVoiceUploader(),
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat_hold_to_talk_button'))),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final holdSurface = tester.widget<Listener>(
      find.byKey(const Key('chat_hold_to_talk_button')),
    );
    expect(holdSurface.onPointerDown, isNull);
    cancelGate.complete();
    await tester.pumpAndSettle();
    expect(recorder.startCalls, 1);
  });

  testWidgets('locks hold-to-talk while recorder startup is pending', (
    tester,
  ) async {
    final startGate = Completer<void>();
    final recorder = FakeChatVoiceRecorder(startGate: startGate);
    await tester.pumpWidget(
      _buildSubject(repository: FakeChatRepository(), voiceRecorder: recorder),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat_hold_to_talk_button'))),
    );
    await tester.pump();

    final holdSurface = tester.widget<Listener>(
      find.byKey(const Key('chat_hold_to_talk_button')),
    );
    expect(holdSurface.onPointerDown, isNull);
    expect(recorder.startCalls, 1);

    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    startGate.complete();
    await tester.pumpAndSettle();
    expect(recorder.startCalls, 1);
    expect(recorder.cancelCalls, 1);
  });

  testWidgets('releasing a hold during recorder startup still sends', (
    tester,
  ) async {
    final startGate = Completer<void>();
    final repository = FakeChatRepository();
    final uploader = FakeChatVoiceUploader();
    final recorder = FakeChatVoiceRecorder(startGate: startGate);
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        voiceUploader: uploader,
        voiceRecorder: recorder,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat_hold_to_talk_button'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(recorder.stopCalls, 0);

    startGate.complete();
    await tester.pumpAndSettle();
    expect(recorder.stopCalls, 1);
    expect(uploader.uploadCalls, 1);
    expect(repository.sentAudioUrls, [uploader.url]);
  });

  testWidgets('sequences cancellation before recorder disposal', (
    tester,
  ) async {
    final startGate = Completer<void>();
    final cancelGate = Completer<void>();
    final recorder = FakeChatVoiceRecorder(
      startGate: startGate,
      cancelGate: cancelGate,
    );
    await tester.pumpWidget(
      _buildSubject(repository: FakeChatRepository(), voiceRecorder: recorder),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();
    await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat_hold_to_talk_button'))),
    );
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    expect(recorder.callOrder, ['start']);

    startGate.complete();
    await tester.pump();
    expect(recorder.callOrder, ['start', 'cancel']);
    cancelGate.complete();
    await tester.pump();
    expect(recorder.callOrder, ['start', 'cancel', 'dispose']);
  });

  testWidgets('resolves relative image proxy URLs against the API origin', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(
            id: '7',
            type: 'image',
            text: '',
            imageUrl: '/api/images/test/pr-97/chat/photo.jpg',
            isMine: false,
          ),
        ],
      },
    );

    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.byKey(const Key('chat_message_image_7')),
    );
    expect(
      (image.image as NetworkImage).url,
      '${ApiConfig.baseUrl}/api/images/test/pr-97/chat/photo.jpg',
    );
  });

  testWidgets('preserves the draft and explains a moderation rejection', (
    tester,
  ) async {
    final repository = FakeChatRepository()
      ..sendError = const ChatRepositoryException(
        'Your message contains language that is not allowed. Please edit it and try again.',
      );
    await tester.pumpWidget(_buildSubject(repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat_message_input')),
      'Please keep this draft',
    );
    await tester.tap(find.byKey(const Key('chat_send_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation_inline_error')), findsOneWidget);
    expect(
      find.text(
        'Your message contains language that is not allowed. Please edit it and try again.',
      ),
      findsOneWidget,
    );
    final input = tester.widget<TextField>(
      find.byKey(const Key('chat_message_input')),
    );
    expect(input.controller?.text, 'Please keep this draft');
  });

  testWidgets('shows signed-out and empty conversation states', (tester) async {
    final signedOutRepository = FakeChatRepository();
    await tester.pumpWidget(
      _buildSubject(repository: signedOutRepository, authToken: null),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('conversation_signed_out_state')),
      findsOneWidget,
    );
    expect(signedOutRepository.messageFetches, 0);

    await tester.pumpWidget(_buildSubject(repository: FakeChatRepository()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversation_empty_state')), findsOneWidget);
  });

  testWidgets('disables sending when a conversation is closed', (tester) async {
    final repository = FakeChatRepository();
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        conversation: testConversation(status: 'closed'),
      ),
    );
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('chat_message_input')),
    );
    final sendButton = tester.widget<IconButton>(
      find.byKey(const Key('chat_send_button')),
    );
    expect(input.enabled, isFalse);
    expect(sendButton.onPressed, isNull);
    expect(find.text('Conversation closed'), findsOneWidget);
  });

  testWidgets('remains readable at 200 percent text scaling', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSubject(
        repository: FakeChatRepository(
          messages: {
            'conversation-1': [
              testMessage(
                id: '1',
                text: 'This message remains readable when text is enlarged.',
                isMine: false,
              ),
            ],
          },
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('conversation_message_list')), findsOneWidget);
  });

  testWidgets('keeps composer actions above the Android navigation inset', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const navigationInset = 24.0;
    await tester.pumpWidget(
      _buildSubject(
        repository: FakeChatRepository(),
        viewPadding: const EdgeInsets.only(bottom: navigationInset),
      ),
    );
    await tester.pumpAndSettle();

    final safeArea = tester.widget<SafeArea>(
      find.byKey(const Key('chat_composer_safe_area')),
    );
    expect(safeArea.top, isFalse);
    expect(safeArea.bottom, isTrue);
    expect(safeArea.maintainBottomViewPadding, isTrue);

    final sendButtonBottom = tester
        .getBottomRight(find.byKey(const Key('chat_send_button')))
        .dy;
    expect(sendButtonBottom, lessThanOrEqualTo(844 - navigationInset));
  });

  testWidgets(
    'retains the composer navigation inset while the keyboard is open',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _buildSubject(
          repository: FakeChatRepository(),
          viewPadding: const EdgeInsets.only(bottom: 24),
          viewInsets: const EdgeInsets.only(bottom: 300),
        ),
      );
      await tester.pumpAndSettle();

      final safeArea = tester.widget<SafeArea>(
        find.byKey(const Key('chat_composer_safe_area')),
      );
      expect(safeArea.maintainBottomViewPadding, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat message input requests focus and message list has keyboard dismiss on drag',
    (tester) async {
      final repository = FakeChatRepository(
        messages: {
          'conversation-1': [
            testMessage(id: '1', text: 'Hello', isMine: false),
          ],
        },
      );
      await tester.pumpWidget(_buildSubject(repository: repository));
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(
        find.byKey(const Key('conversation_message_list')),
      );
      expect(
        listView.keyboardDismissBehavior,
        ScrollViewKeyboardDismissBehavior.onDrag,
      );

      final inputFinder = find.byKey(const Key('chat_message_input'));
      expect(inputFinder, findsOneWidget);

      await tester.tap(inputFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final textField = tester.widget<TextField>(inputFinder);
      expect(textField.focusNode?.hasFocus, isTrue);

      // Tap outside to unfocus
      await tester.tap(find.byKey(const Key('conversation_message_list')));
      await tester.pump();
      expect(textField.focusNode?.hasFocus, isFalse);
    },
  );

  testWidgets('in-conversation polling dynamically updates message history', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(id: '1', text: 'Initial message', isMine: false),
        ],
      },
    );
    await tester.pumpWidget(
      _buildSubject(
        repository: repository,
        enablePolling: true,
        pollingInterval: const Duration(milliseconds: 50),
      ),
    );
    await tester.pump();
    expect(find.text('Initial message'), findsOneWidget);

    // Simulate another message arriving
    repository.messages['conversation-1'] = [
      testMessage(id: '1', text: 'Initial message', isMine: false),
      testMessage(id: '2', text: 'New incoming message', isMine: false),
    ];

    await tester.pump(const Duration(milliseconds: 70));
    await tester.pump(const Duration(milliseconds: 70));

    expect(find.text('New incoming message'), findsOneWidget);
  });

  testWidgets(
    'tapping participant header navigates to counterpart public profile',
    (tester) async {
      final repository = FakeChatRepository();
      final mockUserRepo = MockUserRepository();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserRepository>.value(value: mockUserRepo),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(userRepository: mockUserRepo),
            ),
          ],
          child: _buildSubject(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final header = find.byKey(const Key('conversation_participant_header'));
      expect(header, findsOneWidget);
      await tester.tap(header);
      await tester.pumpAndSettle();

      expect(find.byType(PublicProfileScreen), findsOneWidget);
    },
  );

  testWidgets(
    'tapping counterpart avatar on received message opens public profile',
    (tester) async {
      final repository = FakeChatRepository(
        messages: {
          'conversation-1': [
            testMessage(id: '101', text: 'Hello', isMine: false),
          ],
        },
      );
      final mockUserRepo = MockUserRepository();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserRepository>.value(value: mockUserRepo),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(userRepository: mockUserRepo),
            ),
          ],
          child: _buildSubject(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final avatars = find.byType(CircleAvatar);
      expect(avatars, findsWidgets);
      // Tap counterpart avatar next to the received message
      await tester.tap(avatars.last);
      await tester.pumpAndSettle();

      expect(find.byType(PublicProfileScreen), findsOneWidget);
    },
  );

  testWidgets(
    'completed transaction shows leave review card and opens ReviewBottomSheet',
    (tester) async {
      final repository = FakeChatRepository(
        messages: {
          'conversation-1': [
            testMessage(
              id: '102',
              text: '🤝 [Transaction Completed] Handover complete!',
              isMine: false,
            ),
          ],
        },
      );
      final mockUserRepo = MockUserRepository();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<UserRepository>.value(value: mockUserRepo),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(userRepository: mockUserRepo),
            ),
          ],
          child: _buildSubject(repository: repository),
        ),
      );
      await tester.pumpAndSettle();

      final reviewBtn = find.byKey(const Key('chat_order_leave_review_btn'));
      expect(reviewBtn, findsOneWidget);
      await tester.tap(reviewBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ReviewBottomSheet), findsOneWidget);
    },
  );

  testWidgets('seller payout Wallet opens the payment methods screen', (
    tester,
  ) async {
    final repository = FakeChatRepository(
      messages: {
        'conversation-1': [
          testMessage(
            id: '103',
            text: '🤝 [Transaction Completed] Handover complete!',
            isMine: false,
          ),
        ],
      },
    );
    final mockUserRepo = MockUserRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<UserRepository>.value(value: mockUserRepo),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(userRepository: mockUserRepo),
          ),
        ],
        child: _buildSubject(
          repository: repository,
          conversation: testConversation(direction: ChatDirection.selling),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wallet'), findsOneWidget);
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentMethodsScreen), findsOneWidget);
    expect(find.text('Please sign in to manage your wallet.'), findsOneWidget);
  });

  testWidgets('captures the voice recording composer for review evidence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildSubject(
        repository: FakeChatRepository(),
        voiceRecorder: FakeChatVoiceRecorder(),
        voiceUploader: FakeChatVoiceUploader(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_record_voice_button')));
    await tester.pump();

    expect(find.byKey(const Key('chat_voice_hold_tab')), findsOneWidget);
    expect(find.text('Hold to Talk'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('chat_hold_to_talk_button'))),
    );
    await tester.pump();

    expect(find.byKey(const Key('chat_voice_recording_tab')), findsOneWidget);
    expect(find.byKey(const Key('chat_voice_recording_timer')), findsOneWidget);
    expect(find.textContaining('release to send'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(find.textContaining('release to cancel'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}

class _FakePermissionController implements PushPermissionController {
  @override
  int? activeSessionGeneration = 1;
  @override
  String? activeUserId = 'user-1';
  PushPermissionStatus status = PushPermissionStatus.notDetermined;
  bool failRequest = false;
  Completer<PushPermissionStatus>? statusCompleter;
  int statusCalls = 0;
  int requestCalls = 0;

  @override
  Future<PushPermissionStatus> getPermissionStatus() async {
    statusCalls += 1;
    return statusCompleter?.future ?? status;
  }

  @override
  Future<PushPermissionStatus> requestPermissionAndSync({
    int? expectedSessionGeneration,
    String? expectedUserId,
  }) async {
    requestCalls += 1;
    if (failRequest) throw StateError('Native permission unavailable');
    return PushPermissionStatus.authorized;
  }

  @override
  Future<PushPermissionStatus> synchronizeIfAuthorized({
    int? expectedSessionGeneration,
    String? expectedUserId,
  }) async => status;
}

class _MemoryPermissionStorage implements NotificationPermissionStorage {
  int? nextEligibleAtMs;

  @override
  Future<int?> getNextEligibleAtMs() async => nextEligibleAtMs;

  @override
  Future<void> setNextEligibleAtMs(int value) async => nextEligibleAtMs = value;

  @override
  Future<void> removeObsoleteDismissal() async {}
}

class _FakeChatImagePicker implements ListingImagePicker {
  _FakeChatImagePicker({this.lostPhotos = const []});

  final List<XFile> lostPhotos;
  int galleryCalls = 0;
  int recoveryCalls = 0;

  @override
  Future<List<XFile>> chooseFromGallery({required int limit}) async {
    galleryCalls += 1;
    return [
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'chair.png',
        mimeType: 'image/png',
      ),
    ];
  }

  @override
  Future<List<XFile>> recoverLostPhotos() async {
    recoveryCalls += 1;
    return lostPhotos;
  }

  @override
  Future<XFile?> takePhoto() async => null;
}
