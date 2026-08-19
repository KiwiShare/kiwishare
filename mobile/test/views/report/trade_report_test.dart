import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/messages/conversation_screen.dart';

void main() {
  testWidgets('trade card opens a contextual trade report', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKiwiShareTheme(),
        home: const ConversationScreen(
          participantName: 'Jenny Yin',
          chatId: 'chat_1',
          reportedUserId: 'user_2',
          tradeId: 'trade_3',
          itemTitle: 'Monstera plant',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('report_trade_button')));
    await tester.pumpAndSettle();

    expect(find.text('Report a trade concern'), findsOneWidget);
    expect(find.text('Jenny Yin'), findsOneWidget);
    expect(find.text('Trade for Monstera plant'), findsOneWidget);
  });
}
