import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/models/report_draft.dart';
import 'package:kiwishare/repositories/report_repository.dart';
import 'package:kiwishare/theme/app_theme.dart';
import 'package:kiwishare/views/profile/report_screen.dart';

void main() {
  Widget buildReportScreen({
    ReportContext reportContext = const ReportContext.general(),
    ReportSubmitter? onSubmit,
    ReportRepository? reportRepository,
    String? authToken,
  }) => MaterialApp(
    theme: buildKiwiShareTheme(),
    home: ReportScreen(
      reportContext: reportContext,
      onSubmit: onSubmit,
      reportRepository: reportRepository,
      authToken: authToken,
    ),
  );

  testWidgets('target card renders a supplied API image with semantics', (
    tester,
  ) async {
    const avatarUrl = 'https://cdn.example.test/avatars/sophie.jpg';
    await tester.pumpWidget(
      buildReportScreen(
        reportContext: const ReportContext(
          targetType: ReportTargetType.user,
          targetId: 'user-1',
          targetLabel: 'Sophie M.',
          targetImageUrl: avatarUrl,
          contextType: ReportContextType.chat,
          contextId: 'chat-1',
        ),
      ),
    );

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('report_target_image')),
    );
    expect(avatar.foregroundImage, isA<NetworkImage>());
    expect((avatar.foregroundImage! as NetworkImage).url, avatarUrl);
    final semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const Key('report_target_image')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.label, 'Avatar for Sophie M.');
    expect(semantics.properties.image, isTrue);
  });

  testWidgets('target card keeps its semantic icon without an image URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildReportScreen(
        reportContext: const ReportContext(
          targetType: ReportTargetType.user,
          targetLabel: 'Sophie M.',
          contextType: ReportContextType.chat,
        ),
      ),
    );

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('report_target_image')),
    );
    expect(avatar.foregroundImage, isNull);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('default submit action waits for a persisted report receipt', (
    tester,
  ) async {
    final repository = _RecordingReportRepository();
    await tester.pumpWidget(
      buildReportScreen(
        reportRepository: repository,
        authToken: 'signed-in-token',
      ),
    );

    await tester.tap(find.byKey(const Key('report_reason_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Something else').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('report_details_field')),
      'A detailed safety concern that should be stored.',
    );
    await tester.ensureVisible(find.byKey(const Key('submit_report_button')));
    await tester.tap(find.byKey(const Key('submit_report_button')));
    await tester.pumpAndSettle();

    expect(repository.token, 'signed-in-token');
    expect(
      repository.draft?.details,
      'A detailed safety concern that should be stored.',
    );
    expect(find.text('Report submitted'), findsOneWidget);
  });

  testWidgets('listing form sends the selected reason to the report API', (
    tester,
  ) async {
    late http.Request request;
    final repository = RestReportRepository(
      client: MockClient((sent) async {
        request = sent;
        return http.Response(
          jsonEncode({
            'status': 'success',
            'report': {
              'id': '66d222222222222222222222',
              'status': 'pending',
              'createdAt': '2026-09-17T02:03:04.000Z',
            },
          }),
          201,
        );
      }),
    );
    await tester.pumpWidget(
      buildReportScreen(
        reportContext: const ReportContext(
          targetType: ReportTargetType.listing,
          targetId: '66d111111111111111111111',
          contextType: ReportContextType.listing,
          contextId: '66d111111111111111111111',
        ),
        reportRepository: repository,
        authToken: 'signed-in-token',
      ),
    );

    await tester.tap(find.byKey(const Key('report_reason_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Counterfeit item').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('report_details_field')),
      'The branding does not match the manufacturer.',
    );
    final submit = find.byKey(const Key('submit_report_button'));
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(request.method, 'POST');
    expect(request.url.path, '/api/reports');
    expect(request.headers['Authorization'], 'Bearer signed-in-token');
    expect(jsonDecode(request.body), {
      'targetType': 'listing',
      'targetId': '66d111111111111111111111',
      'contextType': 'listing',
      'contextId': '66d111111111111111111111',
      'reason': 'counterfeit_item',
      'details': 'The branding does not match the manufacturer.',
    });
    expect(find.text('Report submitted'), findsOneWidget);
  });

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

  testWidgets('waits for a receipt and prevents repeated submission', (
    tester,
  ) async {
    final pending = Completer<void>();
    var submissions = 0;
    await tester.pumpWidget(
      buildReportScreen(
        onSubmit: (_) {
          submissions++;
          return pending.future;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('report_reason_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Something else').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('report_details_field')),
      'The account repeatedly asked for an unsafe meetup.',
    );
    final submit = find.byKey(const Key('submit_report_button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(submissions, 1);
    expect(find.text('Report submitted'), findsNothing);
    expect(find.text('Submitting…'), findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    pending.complete();
    await tester.pumpAndSettle();
    expect(submissions, 1);
    expect(find.text('Report submitted'), findsOneWidget);
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

class _RecordingReportRepository extends ReportRepository {
  ReportDraft? draft;
  String? token;

  @override
  Future<ReportSubmission> submitReport({
    required ReportDraft draft,
    required String token,
  }) async {
    this.draft = draft;
    this.token = token;
    return ReportSubmission(
      id: '66d222222222222222222222',
      status: 'pending',
      createdAt: DateTime.utc(2026, 8, 31),
    );
  }
}
