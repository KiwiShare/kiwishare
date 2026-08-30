import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/main.dart';

Widget _subject({required int unreadCount, bool active = false}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: ChatNavigationIcon(unreadCount: unreadCount, active: active),
      ),
    ),
  );
}

void main() {
  testWidgets('hides the chat badge when there are no unread messages', (
    tester,
  ) async {
    await tester.pumpWidget(_subject(unreadCount: 0));

    final badge = tester.widget<Badge>(
      find.byKey(const Key('chat_navigation_badge')),
    );
    expect(badge.isLabelVisible, isFalse);
    expect(find.bySemanticsLabel('Chat'), findsOneWidget);
  });

  testWidgets('shows unread total and accessible chat label', (tester) async {
    await tester.pumpWidget(_subject(unreadCount: 3));

    final badge = tester.widget<Badge>(
      find.byKey(const Key('chat_navigation_badge')),
    );
    expect(badge.isLabelVisible, isTrue);
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('Chat, 3 unread messages'), findsOneWidget);
  });

  testWidgets('caps the visual label without losing the semantic total', (
    tester,
  ) async {
    await tester.pumpWidget(_subject(unreadCount: 120, active: true));

    expect(find.text('99+'), findsOneWidget);
    expect(find.bySemanticsLabel('Chat, 120 unread messages'), findsOneWidget);
    expect(
      find.byKey(const Key('chat_navigation_badge_active')),
      findsOneWidget,
    );
  });
}
