import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/views/support/support_chat_screen.dart';

void main() {
  testWidgets('SupportChatScreen renders markdown without raw asterisks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SupportChatScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify KiwiShare Support appbar title
    expect(find.text('KiwiShare Support'), findsOneWidget);

    // Verify raw markdown asterisks are not shown
    expect(find.textContaining('**HOW IT WORKS:**'), findsNothing);
    expect(find.textContaining('**Browse & Watchlist**'), findsNothing);
    expect(find.textContaining('**SAFETY & REPORTING:**'), findsNothing);
    expect(find.textContaining('**customer@kiwishare.online**'), findsNothing);

    // Verify parsed plain text is rendered inside Text.rich spans
    expect(find.textContaining('HOW IT WORKS:'), findsOneWidget);
    expect(find.textContaining('Browse & Watchlist'), findsOneWidget);
    expect(find.textContaining('SAFETY & REPORTING:'), findsOneWidget);
    expect(find.textContaining('customer@kiwishare.online'), findsWidgets);
  });
}
