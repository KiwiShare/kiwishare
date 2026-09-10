import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/services/chat_photo_upload_service.dart';
import 'package:kiwishare/services/r2_upload_service.dart';

void main() {
  test('uploads chat bytes to the configured R2 chat folder', () async {
    final requests = <http.Request>[];
    final uploader = R2ChatPhotoUploader(
      uploader: R2UploadService(
        uploadFolder: 'test/pr-97/chat',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'uploadUrl': 'https://r2.example.test/signed-upload',
                'publicUrl':
                    'https://assets.kiwishare.online/test/pr-97/chat/photo.png',
              }),
              200,
            );
          }
          return http.Response('', 200);
        }),
      ),
    );

    final publicUrl = await uploader.uploadPhoto(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'photo.png',
      contentType: 'image/png',
      authToken: 'valid-token',
    );

    expect(
      publicUrl,
      'https://assets.kiwishare.online/test/pr-97/chat/photo.png',
    );
    expect(jsonDecode(requests.first.body)['folder'], 'test/pr-97/chat');
    expect(requests.last.method, 'PUT');
    expect(requests.last.bodyBytes, [1, 2, 3]);
  });

  test('preserves an expired session reported by R2', () async {
    final uploader = R2ChatPhotoUploader(
      uploader: R2UploadService(
        client: MockClient((_) async => http.Response('{}', 403)),
      ),
    );

    await expectLater(
      uploader.uploadPhoto(
        bytes: Uint8List.fromList([1]),
        fileName: 'photo.jpg',
        contentType: 'image/jpeg',
        authToken: 'expired-token',
      ),
      throwsA(isA<ChatPhotoAuthenticationException>()),
    );
  });
}
