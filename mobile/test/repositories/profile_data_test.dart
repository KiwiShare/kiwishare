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
    'authProvider': 'email_password',
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
    final profile = await repo.fetchProfile('token');
    expect(profile.trustScore, 87);
    expect(profile.authProvider, 'email_password');
  });
  test(
    'profile fetch distinguishes expired sessions and server errors',
    () async {
      final expired = RestUserRepository(
        client: MockClient(
          (_) async => http.Response(
            '{"status":"error","message":"Invalid or expired authorization token."}',
            401,
          ),
        ),
      );
      await expectLater(
        expired.fetchProfile('expired-token'),
        throwsA(isA<UserAuthenticationException>()),
      );

      final serverError = RestUserRepository(
        client: MockClient((_) async => http.Response('{}', 500)),
      );
      await expectLater(
        serverError.fetchProfile('token'),
        throwsA(isA<UserRepositoryException>()),
      );
    },
  );
  test(
    'password change keeps incorrect password separate from expired token',
    () async {
      final wrongPassword = RestUserRepository(
        client: MockClient(
          (_) async => http.Response(
            '{"message":"Current password is incorrect."}',
            401,
          ),
        ),
      );
      await expectLater(
        wrongPassword.changePassword(
          token: 'token',
          currentPassword: 'old',
          newPassword: 'new-password',
        ),
        throwsA(
          predicate(
            (Object error) =>
                error.toString().contains('Current password is incorrect.'),
          ),
        ),
      );

      final expired = RestUserRepository(
        client: MockClient(
          (_) async => http.Response(
            '{"message":"Invalid or expired authorization token."}',
            401,
          ),
        ),
      );
      await expectLater(
        expired.changePassword(
          token: 'expired-token',
          currentPassword: 'old',
          newPassword: 'new-password',
        ),
        throwsA(isA<UserAuthenticationException>()),
      );
    },
  );
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
  test('password reset requests and confirms through auth endpoints', () async {
    final seen = <String>[];
    final repo = RestUserRepository(
      client: MockClient((request) async {
        seen.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/request-password-reset')) {
          expect(body, {'email': 'reset@example.com'});
          return http.Response('{"status":"success"}', 200);
        }
        expect(body, {
          'email': 'reset@example.com',
          'code': '123456',
          'newPassword': 'new-password',
        });
        return http.Response('{"status":"success"}', 200);
      }),
    );

    await repo.requestPasswordReset('Reset@Example.com');
    await repo.resetPassword(
      email: 'Reset@Example.com',
      code: '123456',
      newPassword: 'new-password',
    );

    expect(seen, [
      '/api/auth/request-password-reset',
      '/api/auth/reset-password',
    ]);
  });
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
    expect(statuses, ['active,reserved,draft,delisted', 'sold']);
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
