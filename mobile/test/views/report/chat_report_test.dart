import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/messages/conversation_screen.dart';

void main() {
  testWidgets('chat menu opens a contextual user report', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKiwiShareTheme(),
        home: const ConversationScreen(
          participantName: 'Jenny Yin',
          chatId: 'chat_1',
          reportedUserId: 'user_2',
          itemTitle: 'Monstera plant',
        ),
      ),
    );

    await tester.tap(find.byTooltip('Conversation options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report user'));
    await tester.pumpAndSettle();

    expect(find.text('Report user'), findsOneWidget);
    expect(find.text('Jenny Yin'), findsOneWidget);
    expect(find.text('Conversation about Monstera plant'), findsOneWidget);
  });
}
