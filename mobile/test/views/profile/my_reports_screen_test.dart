import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/models/report_history_entry.dart';
import 'package:kiwishare/repositories/report_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/profile/my_reports_screen.dart';

void main() {
  final reports = [
    ReportHistoryEntry(
      id: '66e640ee3d3540355741abcd',
      targetType: 'user',
      contextType: 'chat',
      reason: 'harassment_or_abusive_behaviour',
      details: 'The member repeatedly sent threatening messages.',
      status: 'pending',
      createdAt: DateTime.utc(2026, 9, 14, 1),
    ),
    ReportHistoryEntry(
      id: '66e640ee3d3540355741dcba',
      targetType: 'listing',
      contextType: 'listing',
      reason: 'misleading_information',
      details: 'The photos and description show different items.',
      status: 'reviewed',
      createdAt: DateTime.utc(2026, 8, 18, 1),
    ),
  ];

  Widget buildScreen({
    required ReportHistoryLoader loader,
    ThemeData? theme,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return MaterialApp(
      theme: theme ?? buildKiwiShareTheme(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: textScaler,
        ),
        child: MyReportsScreen(loadReports: loader),
      ),
    );
  }

  testWidgets(
    'shows report details and review progress returned by the loader',
    (tester) async {
      await tester.pumpWidget(buildScreen(loader: () async => reports));
      await tester.pumpAndSettle();

      expect(find.text('My reports'), findsOneWidget);
      expect(find.byKey(const Key('report-history-list')), findsOneWidget);
      expect(find.text('Chat report'), findsOneWidget);
      expect(find.text('Listing report'), findsOneWidget);
      expect(find.text('Harassment or abusive behaviour'), findsOneWidget);
      expect(
        find.text('The member repeatedly sent threatening messages.'),
        findsOneWidget,
      );
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Reviewed'), findsOneWidget);
      expect(find.text('Reference 5741ABCD'), findsOneWidget);
      expect(
        find.textContaining('Status updates show review progress'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows an honest empty state without sample reports', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(loader: () async => []));
    await tester.pumpAndSettle();

    expect(find.text('No reports yet'), findsOneWidget);
    expect(
      find.text(
        'Reports you submit to KiwiShare will appear here with their review status.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('report-history-list')), findsNothing);
  });

  testWidgets('offers retry after a recoverable history failure', (
    tester,
  ) async {
    var attempts = 0;
    Future<List<ReportHistoryEntry>> load() async {
      attempts += 1;
      if (attempts == 1) {
        throw const ReportRepositoryException(
          'Report history is temporarily unavailable.',
        );
      }
      return reports.take(1).toList();
    }

    await tester.pumpWidget(buildScreen(loader: load));
    await tester.pumpAndSettle();
    expect(find.text('Could not load reports'), findsOneWidget);
    expect(
      find.text('Report history is temporarily unavailable.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('retry-report-history')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Chat report'), findsOneWidget);
    expect(find.text('Could not load reports'), findsNothing);
  });

  testWidgets('supports dark mode and 200 percent text scaling', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildScreen(
        loader: () async => reports.take(1).toList(),
        theme: buildKiwiShareDarkTheme(),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Chat report'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
  });
}
