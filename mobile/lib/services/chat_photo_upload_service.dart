import 'dart:typed_data';

import '../config/api_config.dart';
import 'r2_upload_service.dart';

abstract interface class ChatPhotoUploader {
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String authToken,
  });
}

class ChatPhotoUploadException implements Exception {
  const ChatPhotoUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatPhotoAuthenticationException extends ChatPhotoUploadException {
  const ChatPhotoAuthenticationException()
    : super('Your session has expired. Please sign in again.');
}

class R2ChatPhotoUploader implements ChatPhotoUploader {
  R2ChatPhotoUploader({ListingPhotoUploader? uploader, String? uploadFolder})
    : _uploader =
          uploader ??
          R2UploadService(
            uploadFolder: uploadFolder ?? _defaultChatUploadFolder(),
          );

  final ListingPhotoUploader _uploader;

  @override
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String authToken,
  }) async {
    try {
      return await _uploader.uploadImage(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        authToken: authToken,
      );
    } on ListingPhotoAuthenticationException {
      throw const ChatPhotoAuthenticationException();
    } on ListingPhotoUploadException catch (error) {
      throw ChatPhotoUploadException(error.message);
    }
  }
}

String _defaultChatUploadFolder() {
  final controlledTestFolder = ApiConfig.r2UploadFolder.trim();
  return controlledTestFolder.isEmpty
      ? 'images/chat'
      : '$controlledTestFolder/chat';
}
