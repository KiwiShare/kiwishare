import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/report_draft.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/profile/report_screen.dart';

void main() {
  Widget buildReportScreen({
    ReportContext reportContext = const ReportContext.general(),
    ReportSubmitter? onSubmit,
  }) => MaterialApp(
    theme: buildKiwiShareTheme(),
    home: ReportScreen(reportContext: reportContext, onSubmit: onSubmit),
  );

  testWidgets(
    'report form validates and produces the approved request fields',
    (tester) async {
      ReportDraft? submittedDraft;
      await tester.pumpWidget(
        buildReportScreen(onSubmit: (draft) async => submittedDraft = draft),
      );

      await tester.ensureVisible(find.byKey(const Key('submit_report_button')));
      await tester.tap(find.byKey(const Key('submit_report_button')));
      await tester.pump();

      expect(find.text('Choose a reason.'), findsOneWidget);
      expect(find.text('Enter at least 10 characters.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('report_reason_field')));
      await tester.tap(find.byKey(const Key('report_reason_field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scam or fraud').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('report_details_field')),
        'The seller requested a gift card before our meetup.',
      );
      await tester.ensureVisible(find.byKey(const Key('submit_report_button')));
      await tester.tap(find.byKey(const Key('submit_report_button')));
      await tester.pumpAndSettle();

      expect(find.text('Report submitted'), findsOneWidget);
      expect(submittedDraft, isNotNull);
      expect(submittedDraft!.toRequestMap(), {
        'targetType': 'general',
        'contextType': 'general',
        'reason': 'scam_or_fraud',
        'details': 'The seller requested a gift card before our meetup.',
      });
      expect(submittedDraft!.toRequestMap(), isNot(contains('reporterId')));
      expect(submittedDraft!.toRequestMap(), isNot(contains('status')));
      expect(submittedDraft!.toRequestMap(), isNot(contains('createdAt')));
    },
  );

  testWidgets('recoverable submission failure preserves report details', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildReportScreen(
        onSubmit: (_) async => throw Exception('connection unavailable'),
      ),
    );

    await tester.tap(find.byKey(const Key('report_reason_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Something else').last);
    await tester.pumpAndSettle();

    const details = 'The behaviour made me feel unsafe during the meetup.';
    await tester.enterText(
      find.byKey(const Key('report_details_field')),
      details,
    );
    await tester.ensureVisible(find.byKey(const Key('submit_report_button')));
    await tester.tap(find.byKey(const Key('submit_report_button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'We could not submit your report. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text(details), findsOneWidget);
  });

  testWidgets('report form remains usable at 200 percent text scaling', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKiwiShareTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: const ReportScreen(),
        ),
      ),
    );

    final submitButton = find.byKey(const Key('submit_report_button'));
    for (
      var attempt = 0;
      attempt < 4 && submitButton.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();

    expect(submitButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
