import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/repositories/report_repository.dart';

void main() {
  test(
    'loads authenticated report history from the real API contract',
    () async {
      late http.Request captured;
      final repository = ReportRepository(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            '''{
            "status": "success",
            "reports": [
              {
                "id": "66e640ee3d3540355741abcd",
                "targetType": "user",
                "contextType": "chat",
                "reason": "harassment_or_abusive_behaviour",
                "details": "The member repeatedly sent threatening messages.",
                "status": "pending",
                "createdAt": "2026-09-14T01:00:00.000Z"
              }
            ]
          }''',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final reports = await repository.fetchHistory(token: 'member-token');

      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/reports');
      expect(captured.headers['Authorization'], 'Bearer member-token');
      expect(reports, hasLength(1));
      expect(reports.single.typeLabel, 'Chat report');
      expect(reports.single.reasonLabel, 'Harassment or abusive behaviour');
      expect(reports.single.statusLabel, 'Submitted');
      expect(reports.single.shortReference, '5741ABCD');
    },
  );

  test(
    'returns an empty list when the authenticated account has no reports',
    () async {
      final repository = ReportRepository(
        client: MockClient(
          (_) async => http.Response('{"status":"success","reports":[]}', 200),
        ),
      );

      expect(await repository.fetchHistory(token: 'member-token'), isEmpty);
    },
  );

  test(
    'surfaces an expired session separately from ordinary load errors',
    () async {
      final expired = ReportRepository(
        client: MockClient(
          (_) async => http.Response(
            '{"status":"error","message":"Invalid or expired authorization token."}',
            403,
          ),
        ),
      );
      final unavailable = ReportRepository(
        client: MockClient(
          (_) async => http.Response(
            '{"status":"error","message":"Report history is unavailable."}',
            503,
          ),
        ),
      );

      expect(
        () => expired.fetchHistory(token: 'expired-token'),
        throwsA(isA<ReportAuthenticationException>()),
      );
      expect(
        () => unavailable.fetchHistory(token: 'member-token'),
        throwsA(
          isA<ReportRepositoryException>().having(
            (error) => error.message,
            'message',
            'Report history is unavailable.',
          ),
        ),
      );
    },
  );

  test(
    'rejects malformed report records instead of showing made-up data',
    () async {
      final repository = ReportRepository(
        client: MockClient(
          (_) async => http.Response(
            '{"status":"success","reports":[{"id":"missing-fields"}]}',
            200,
          ),
        ),
      );

      expect(
        () => repository.fetchHistory(token: 'member-token'),
        throwsA(
          isA<ReportRepositoryException>().having(
            (error) => error.message,
            'message',
            'The report service returned an invalid history.',
          ),
        ),
      );
    },
  );
}
