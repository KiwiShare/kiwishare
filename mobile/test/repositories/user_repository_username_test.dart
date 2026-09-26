import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/repositories/user_repository.dart';

void main() {
  test('updateProfile surfaces backend username conflict message', () async {
    final repository = RestUserRepository(
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'That username is already taken.'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      () => repository.updateProfile(token: 'token', username: 'sam'),
      throwsA(
        isA<UserRepositoryException>().having(
          (error) => error.message,
          'message',
          'That username is already taken.',
        ),
      ),
    );
  });
}
