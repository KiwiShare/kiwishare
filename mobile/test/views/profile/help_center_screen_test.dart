import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/views/profile/help_center_screen.dart';

void main() {
  Widget buildSubject({int initialTabIndex = 0}) {
    return MaterialApp(
      home: HelpCenterScreen(initialTabIndex: initialTabIndex),
    );
  }

  group('HelpCenterScreen', () {
    testWidgets('renders How It Works tab with 5 steps and welcome hero', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(initialTabIndex: 0));
      await tester.pumpAndSettle();

      expect(find.text('Help & Guides'), findsOneWidget);
      expect(find.text('Welcome to KiwiShare'), findsOneWidget);
      expect(find.text('5 Steps to Successful Campus Trading'), findsOneWidget);
      expect(find.text('STEP 1'), findsOneWidget);
      expect(find.text('Browse & Discover Campus Deals'), findsOneWidget);
      expect(find.text('STEP 2'), findsOneWidget);
      expect(find.text('Chat, Negotiate & Post Easily'), findsOneWidget);
    });

    testWidgets('switches to FAQs tab and displays questions', (tester) async {
      await tester.pumpWidget(buildSubject(initialTabIndex: 1));
      await tester.pumpAndSettle();

      expect(find.text('Q&A & FAQs'), findsOneWidget);
      expect(
        find.text('What is the Meetup QR code and how does handover work?'),
        findsOneWidget,
      );
      expect(
        find.text('What is the "Backup verification code / QR" used for?'),
        findsOneWidget,
      );
      expect(
        find.text('What is KiwiGold and how do I use it?'),
        findsOneWidget,
      );
    });

    testWidgets('expands FAQ item and reveals detailed answer', (tester) async {
      await tester.pumpWidget(buildSubject(initialTabIndex: 1));
      await tester.pumpAndSettle();

      final backupQrQuestion = find.text(
        'What is the "Backup verification code / QR" used for?',
      );
      expect(backupQrQuestion, findsOneWidget);

      await tester.tap(backupQrQuestion);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'If the seller\'s phone camera has difficulty scanning',
        ),
        findsOneWidget,
      );
    });

    testWidgets('filters FAQs using search query', (tester) async {
      await tester.pumpWidget(buildSubject(initialTabIndex: 1));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'KiwiGold');
      await tester.pumpAndSettle();

      expect(
        find.text('What is KiwiGold and how do I use it?'),
        findsOneWidget,
      );
      expect(find.text('How do I earn more KiwiGold?'), findsOneWidget);
      // Non-matching question should be filtered out
      expect(
        find.text('Where is the safest place to meet on campus?'),
        findsNothing,
      );
    });

    testWidgets('shows empty state when no FAQs match search', (tester) async {
      await tester.pumpWidget(buildSubject(initialTabIndex: 1));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'XYZUnknownQuery123');
      await tester.pumpAndSettle();

      expect(
        find.text('No answers found for "XYZUnknownQuery123"'),
        findsOneWidget,
      );
    });
  });
}
