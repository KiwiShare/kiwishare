import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/services/listing_publish_service.dart';
import 'package:kiwishare/services/r2_upload_service.dart';

void main() {
  const token = 'valid-jwt-token';
  final photo = ListingPhotoDraft(
    bytes: Uint8List.fromList([1, 2, 3]),
    fileName: 'desk.png',
    contentType: 'image/png',
  );

  ListingDraft draft() => ListingDraft(
    title: ' Solid wood desk ',
    priceNzd: '120.00',
    locationLabel: 'Mount Eden, Auckland',
    latitude: -36.88,
    longitude: 174.76,
    category: 'Furniture',
    condition: 'Like new',
    description: 'A sturdy study desk.',
    attributes: const {'material': 'Oak'},
    photos: [photo],
  );

  test('uploads photos and creates an authenticated listing', () async {
    late http.Request capturedRequest;
    final uploader = FakePhotoUploader(
      urls: ['https://assets.kiwishare.online/images/desk.png'],
    );
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'status': 'created',
          'item': {
            'id': 'item-1',
            'title': 'Solid wood desk',
            'priceNzd': '120.00',
            'location': 'Mount Eden, Auckland',
            'imageUrl': 'https://assets.kiwishare.online/images/desk.png',
            'images': [
              {'url': 'https://assets.kiwishare.online/images/desk.png'},
            ],
            'isSustainable': true,
            'category': 'Furniture',
            'status': 'active',
            'description': 'A sturdy study desk.',
            'condition': 'like_new',
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = RestListingPublishService(
      client: client,
      photoUploader: uploader,
    );

    final item = await service.publish(draft: draft(), authToken: token);

    expect(item.id, 'item-1');
    expect(item.allImages, ['https://assets.kiwishare.online/images/desk.png']);
    expect(uploader.uploadedFiles, ['desk.png']);
    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/api/usedItems');
    expect(capturedRequest.headers['Authorization'], 'Bearer $token');

    final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(body['title'], 'Solid wood desk');
    expect(body['condition'], 'like_new');
    expect(body['images'], [
      {
        'url': 'https://assets.kiwishare.online/images/desk.png',
        'thumbnailUrl': 'https://assets.kiwishare.online/images/desk.png',
        'sortOrder': 0,
      },
    ]);
    expect(body['isSustainable'], false);
    expect(body['attributes'], {'material': 'Oak'});
    expect(body['location'], {
      'city': 'Auckland',
      'suburb': 'Mount Eden',
      'latitude': -36.88,
      'longitude': 174.76,
    });
  });

  test('reports an expired session without claiming success', () async {
    final service = RestListingPublishService(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'message': 'Invalid token'}), 403),
      ),
      photoUploader: FakePhotoUploader(
        urls: ['https://assets.kiwishare.online/images/desk.png'],
      ),
    );

    await expectLater(
      service.publish(draft: draft(), authToken: token),
      throwsA(
        isA<ListingAuthenticationException>().having(
          (error) => error.message,
          'message',
          'Your session has expired. Please sign in again.',
        ),
      ),
    );
  });

  test('preserves an expired session reported by photo upload', () async {
    final service = RestListingPublishService(
      client: MockClient((_) async => http.Response('{}', 201)),
      photoUploader: AuthenticationFailurePhotoUploader(),
    );

    await expectLater(
      service.publish(draft: draft(), authToken: token),
      throwsA(isA<ListingAuthenticationException>()),
    );
  });

  test('does not create the item when a photo upload fails', () async {
    var createCalls = 0;
    final service = RestListingPublishService(
      client: MockClient((_) async {
        createCalls += 1;
        return http.Response('{}', 201);
      }),
      photoUploader: FakePhotoUploader(failure: 'R2 is unavailable'),
    );

    await expectLater(
      service.publish(draft: draft(), authToken: token),
      throwsA(
        isA<ListingPublishException>().having(
          (error) => error.message,
          'message',
          'R2 is unavailable',
        ),
      ),
    );
    expect(createCalls, 0);
  });

  test('R2 upload failure never returns a fabricated public URL', () async {
    final uploader = R2UploadService(
      client: MockClient(
        (_) async =>
            http.Response(jsonEncode({'message': 'Upload failed'}), 500),
      ),
    );

    await expectLater(
      uploader.uploadImage(
        bytes: photo.bytes,
        fileName: photo.fileName,
        contentType: photo.contentType,
        authToken: token,
      ),
      throwsA(
        isA<ListingPhotoUploadException>().having(
          (error) => error.message,
          'message',
          'Upload failed',
        ),
      ),
    );
  });

  test(
    'R2 preserves authentication failures from the presign endpoint',
    () async {
      final uploader = R2UploadService(
        client: MockClient((_) async => http.Response('{}', 403)),
      );

      await expectLater(
        uploader.uploadImage(
          bytes: photo.bytes,
          fileName: photo.fileName,
          contentType: photo.contentType,
          authToken: token,
        ),
        throwsA(isA<ListingPhotoAuthenticationException>()),
      );
    },
  );

  test('R2 uploads raw bytes through a server-issued presigned URL', () async {
    final requests = <http.Request>[];
    final uploader = R2UploadService(
      uploadFolder: 'test/pr-171',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://r2.example.test/signed-upload',
              'publicUrl': 'https://assets.kiwishare.online/images/desk.png',
            }),
            200,
          );
        }
        return http.Response('', 200);
      }),
    );

    final url = await uploader.uploadImage(
      bytes: photo.bytes,
      fileName: photo.fileName,
      contentType: photo.contentType,
      authToken: token,
    );

    expect(url, 'https://assets.kiwishare.online/images/desk.png');
    expect(requests, hasLength(2));
    expect(requests.first.method, 'POST');
    expect(requests.first.url.path, '/api/upload/presign');
    expect(requests.first.headers['Authorization'], 'Bearer $token');
    expect(jsonDecode(requests.first.body)['folder'], 'test/pr-171');
    expect(requests.last.method, 'PUT');
    expect(requests.last.bodyBytes, photo.bytes);
    expect(requests.last.headers['Content-Type'], 'image/png');
  });

  test('R2 falls back to server upload when direct upload fails', () async {
    final requests = <http.Request>[];
    final uploader = R2UploadService(
      uploadFolder: 'test/local',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/upload/presign') {
          return http.Response(
            jsonEncode({
              'uploadUrl': 'https://r2.example.test/signed-upload',
              'publicUrl': 'https://assets.kiwishare.online/images/direct.png',
            }),
            200,
          );
        }
        if (request.method == 'PUT') {
          return http.Response('signature mismatch', 403);
        }
        if (request.url.path == '/api/upload') {
          return http.Response(
            jsonEncode({
              'url': 'https://assets.kiwishare.online/images/fallback.png',
            }),
            201,
          );
        }
        return http.Response('{}', 404);
      }),
    );

    final url = await uploader.uploadImage(
      bytes: photo.bytes,
      fileName: photo.fileName,
      contentType: photo.contentType,
      authToken: token,
    );

    expect(url, 'https://assets.kiwishare.online/images/fallback.png');
    expect(requests.map((request) => request.method), ['POST', 'PUT', 'POST']);
    expect(requests.last.url.path, '/api/upload');
    final fallbackBody = jsonDecode(requests.last.body);
    expect(fallbackBody['imageBase64'], base64Encode(photo.bytes));
    expect(fallbackBody['folder'], 'test/local');
  });
}

class FakePhotoUploader implements ListingPhotoUploader {
  FakePhotoUploader({this.urls = const [], this.failure});

  final List<String> urls;
  final String? failure;
  final List<String> uploadedFiles = [];
  int _nextUrl = 0;

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
    required String authToken,
  }) async {
    uploadedFiles.add(fileName);
    if (failure != null) {
      throw ListingPhotoUploadException(failure!);
    }
    return urls[_nextUrl++];
  }
}

class AuthenticationFailurePhotoUploader implements ListingPhotoUploader {
  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
    required String authToken,
  }) {
    throw const ListingPhotoAuthenticationException();
  }
}
