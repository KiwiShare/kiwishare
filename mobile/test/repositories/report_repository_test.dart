import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/models/report_draft.dart';
import 'package:kiwishare/repositories/report_repository.dart';

const _reason = ReportReason(
  code: 'misleading_information',
  label: 'Misleading information',
  description: 'The listing details are inaccurate',
  icon: Icons.fact_check_outlined,
);

const _draft = ReportDraft(
  context: ReportContext(
    targetType: ReportTargetType.listing,
    targetId: '66d111111111111111111111',
    contextType: ReportContextType.listing,
    contextId: '66d111111111111111111111',
  ),
  reason: _reason,
  details: 'The photos and description show different items.',
);

void main() {
  test(
    'posts only approved client fields and parses the stored receipt',
    () async {
      late http.Request captured;
      final repository = RestReportRepository(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'report': {
                'id': '66d222222222222222222222',
                'reporterId': '66d333333333333333333333',
                'targetType': 'listing',
                'targetId': '66d111111111111111111111',
                'contextType': 'listing',
                'contextId': '66d111111111111111111111',
                'reason': 'misleading_information',
                'details': 'The photos and description show different items.',
                'status': 'pending',
                'createdAt': '2026-08-31T03:04:05.000Z',
              },
            }),
            201,
          );
        }),
      );

      final receipt = await repository.submitReport(
        draft: _draft,
        token: 'valid-token',
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/reports');
      expect(captured.headers['Authorization'], 'Bearer valid-token');
      expect(jsonDecode(captured.body), {
        'targetType': 'listing',
        'targetId': '66d111111111111111111111',
        'contextType': 'listing',
        'contextId': '66d111111111111111111111',
        'reason': 'misleading_information',
        'details': 'The photos and description show different items.',
      });
      expect(jsonDecode(captured.body), isNot(contains('reporterId')));
      expect(jsonDecode(captured.body), isNot(contains('status')));
      expect(jsonDecode(captured.body), isNot(contains('createdAt')));
      expect(receipt.id, '66d222222222222222222222');
      expect(receipt.status, 'pending');
      expect(receipt.createdAt, DateTime.utc(2026, 8, 31, 3, 4, 5));
    },
  );

  test('identifies an expired authenticated session', () async {
    final repository = RestReportRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'status': 'error',
            'message': 'Invalid or expired authorization token.',
          }),
          401,
        ),
      ),
    );

    expect(
      () => repository.submitReport(draft: _draft, token: 'expired-token'),
      throwsA(isA<ReportAuthenticationException>()),
    );
  });

  test(
    'does not treat a private-context rejection as an expired session',
    () async {
      const message = 'Report context is not available to this user.';
      final repository = RestReportRepository(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'status': 'error', 'message': message}),
            403,
          ),
        ),
      );

      expect(
        () => repository.submitReport(draft: _draft, token: 'valid-token'),
        throwsA(
          isA<ReportRepositoryException>()
              .having((error) => error.message, 'message', message)
              .having(
                (error) => error is ReportAuthenticationException,
                'is authentication error',
                isFalse,
              ),
        ),
      );
    },
  );

  test('preserves the safe duplicate-report response', () async {
    const message =
        'You have already submitted this report. We will review it shortly.';
    final repository = RestReportRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'status': 'error', 'message': message}),
          409,
        ),
      ),
    );

    expect(
      () => repository.submitReport(draft: _draft, token: 'valid-token'),
      throwsA(
        isA<ReportRepositoryException>().having(
          (error) => error.message,
          'message',
          message,
        ),
      ),
    );
  });

  test(
    'rejects a malformed success response instead of showing success',
    () async {
      final repository = RestReportRepository(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'status': 'success',
              'report': {'status': 'pending'},
            }),
            201,
          ),
        ),
      );

      expect(
        () => repository.submitReport(draft: _draft, token: 'valid-token'),
        throwsA(
          isA<ReportRepositoryException>().having(
            (error) => error.message,
            'message',
            'The report service returned an invalid confirmation.',
          ),
        ),
      );
    },
  );
}
