import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

abstract interface class ListingPhotoUploader {
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
    required String authToken,
  });
}

class ListingPhotoUploadException implements Exception {
  const ListingPhotoUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ListingPhotoAuthenticationException extends ListingPhotoUploadException {
  const ListingPhotoAuthenticationException()
    : super('Your session has expired. Please sign in again.');
}

/// Cloudflare R2 S3 Upload Service for KiwiShare
class R2UploadService implements ListingPhotoUploader {
  final http.Client _client;
  final String _uploadFolder;

  R2UploadService({http.Client? client, String? uploadFolder})
    : _client = client ?? http.Client(),
      _uploadFolder = uploadFolder ?? ApiConfig.r2UploadFolder;

  /// Uploads image bytes to Cloudflare R2 bucket `kiwishare`
  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
    required String authToken,
  }) async {
    return uploadFile(
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      authToken: authToken,
      startFailureMessage:
          'A photo upload could not be started. Please try again.',
      uploadFailureMessage: 'A photo could not be uploaded. Please try again.',
    );
  }

  Future<String> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String authToken,
    required String startFailureMessage,
    required String uploadFailureMessage,
  }) async {
    final presignResponse = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/upload/presign'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'x-client-platform': 'mobile',
        'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'fileName': fileName,
        'contentType': contentType,
        if (_uploadFolder.trim().isNotEmpty) 'folder': _uploadFolder.trim(),
      }),
    );

    if (presignResponse.statusCode == 401 ||
        presignResponse.statusCode == 403) {
      throw const ListingPhotoAuthenticationException();
    }
    if (presignResponse.statusCode != 200) {
      throw ListingPhotoUploadException(
        _errorMessage(presignResponse.body, fallback: startFailureMessage),
      );
    }

    try {
      final data = jsonDecode(presignResponse.body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final uploadUrl = data['uploadUrl'] as String?;
      final publicUrl = data['publicUrl'] as String?;
      if (uploadUrl == null ||
          uploadUrl.isEmpty ||
          publicUrl == null ||
          publicUrl.isEmpty) {
        throw const FormatException();
      }

      final uploadResponse = await _client.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': contentType},
        body: bytes,
      );
      if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
        throw ListingPhotoUploadException(
          _errorMessage(uploadResponse.body, fallback: uploadFailureMessage),
        );
      }
      return publicUrl;
    } on ListingPhotoUploadException {
      rethrow;
    } catch (_) {
      throw const ListingPhotoUploadException(
        'The upload service returned an invalid response. Please try again.',
      );
    }
  }

  String _errorMessage(String responseBody, {required String fallback}) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map<String, dynamic> && data['message'] is String) {
        final serverMessage = (data['message'] as String).trim();
        if (serverMessage.isNotEmpty) {
          return serverMessage;
        }
      }
    } catch (_) {
      // Keep the user-safe fallback when the server does not return JSON.
    }
    return fallback;
  }
}
