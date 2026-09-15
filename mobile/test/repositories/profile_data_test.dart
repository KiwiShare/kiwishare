import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/models/report_draft.dart';
import 'package:kiwishare/repositories/user_repository.dart';
import 'package:kiwishare/repositories/report_repository.dart';
import 'package:kiwishare/repositories/item_repository.dart';

void main() {
  final user = {
    'id': 'user-1',
    'displayName': 'Jenny',
    'avatarUrl': null,
    'trustScore': 87,
    'isVerified': true,
  };
  test('profile fetch authenticates and reads database score', () async {
    final repo = RestUserRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/api/users/me');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response(jsonEncode({'user': user}), 200);
      }),
    );
    expect((await repo.fetchProfile('token')).trustScore, 87);
  });
  test(
    'avatar reset is sent explicitly without changing name or score',
    () async {
      final repo = RestUserRepository(
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(jsonDecode(request.body), {'avatarUrl': ''});
          return http.Response(jsonEncode({'user': user}), 200);
        }),
      );
      expect(
        (await repo.updateProfile(token: 'token', avatarUrl: '')).avatarUrl,
        isNull,
      );
    },
  );
  test('selling and sold use authenticated server filters', () async {
    final statuses = <String?>[];
    final repo = RestItemRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/api/users/me/usedItems');
        expect(request.headers['Authorization'], 'Bearer token');
        statuses.add(request.url.queryParameters['status']);
        return http.Response('[]', 200);
      }),
    );
    await repo.fetchMyItems(sold: false, token: 'token');
    await repo.fetchMyItems(sold: true, token: 'token');
    expect(statuses, ['active,reserved', 'sold']);
  });
  final draft = ReportDraft(
    context: const ReportContext.general(),
    reason: ReportReasonCatalog.userAndTrade.last,
    details: '  Suspicious payment request.  ',
  );
  test('report sends real payload and requires a persisted receipt', () async {
    final repo = ReportRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/api/reports');
        expect(request.headers['Authorization'], 'Bearer token');
        expect(jsonDecode(request.body), {
          'targetType': 'general',
          'contextType': 'general',
          'reason': 'other',
          'details': 'Suspicious payment request.',
        });
        return http.Response(
          '{"status":"success","report":{"id":"report-1","status":"pending","createdAt":"2026-09-14T10:00:00.000Z"}}',
          201,
        );
      }),
    );
    await repo.submit(draft, token: 'token');
  });
  test(
    'failed or malformed report response cannot be treated as success',
    () async {
      for (final response in [
        http.Response('{}', 401),
        http.Response('{}', 500),
        http.Response('{}', 201),
      ]) {
        final repo = ReportRepository(
          client: MockClient((_) async => response),
        );
        await expectLater(
          repo.submit(draft, token: 'token'),
          throwsA(isA<Exception>()),
        );
      }
    },
  );
}
