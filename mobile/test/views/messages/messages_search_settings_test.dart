import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/chat_conversation_model.dart';
import 'package:kiwishare/providers/chat_provider.dart';
import 'package:kiwishare/views/messages/messages_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_chat_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'chat_push_notifications_enabled': true,
      'chat_sound_enabled': true,
    });
  });

  testWidgets('Chat screen header has Search and Settings buttons', (tester) async {
    final conversations = [
      testConversation(
        id: 'c1',
        participantName: 'Alice NZ',
        itemTitle: 'Vintage Leather Jacket',
        lastMessage: 'Is this still available?',
        direction: ChatDirection.buying,
      ),
      testConversation(
        id: 'c2',
        participantName: 'Bob Student',
        itemTitle: 'Auckland Uni Textbook',
        lastMessage: 'Can we meetup tomorrow at library?',
        direction: ChatDirection.selling,
      ),
    ];

    final repo = FakeChatRepository(conversations: conversations);
    final provider = ChatProvider(repository: repo);

    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          chatProvider: provider,
          authToken: 'test-token',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify search and settings buttons exist
    expect(find.byKey(const Key('chat_search_button')), findsOneWidget);
    expect(find.byKey(const Key('chat_settings_button')), findsOneWidget);

    // Both conversations shown initially
    expect(find.text('Alice NZ'), findsOneWidget);
    expect(find.text('Bob Student'), findsOneWidget);

    // Tap search button to toggle search mode
    await tester.tap(find.byKey(const Key('chat_search_button')));
    await tester.pumpAndSettle();

    // Search field appears
    expect(find.byKey(const Key('chat_search_field')), findsOneWidget);

    // Enter query 'Textbook'
    await tester.enterText(find.byKey(const Key('chat_search_field')), 'Textbook');
    await tester.pumpAndSettle();

    // Only Bob Student conversation matches
    expect(find.text('Alice NZ'), findsNothing);
    expect(find.text('Bob Student'), findsOneWidget);

    // Tap cancel search
    await tester.tap(find.byKey(const Key('chat_cancel_search_button')));
    await tester.pumpAndSettle();

    // Both conversations back
    expect(find.text('Alice NZ'), findsOneWidget);
    expect(find.text('Bob Student'), findsOneWidget);

    // Tap Settings button
    await tester.tap(find.byKey(const Key('chat_settings_button')));
    await tester.pumpAndSettle();

    // Settings sheet opens with push notification switch
    expect(find.text('Chat Settings'), findsOneWidget);
    expect(find.byKey(const Key('chat_push_notifications_switch')), findsOneWidget);
    expect(find.byKey(const Key('chat_sound_switch')), findsOneWidget);
  });
}
