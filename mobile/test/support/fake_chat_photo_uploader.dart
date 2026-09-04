import 'dart:typed_data';

import 'package:kiwishare/services/chat_photo_upload_service.dart';

class FakeChatPhotoUploader implements ChatPhotoUploader {
  FakeChatPhotoUploader({
    this.url = 'https://assets.kiwishare.online/images/chat/photo.jpg',
    this.error,
  });

  final String url;
  final ChatPhotoUploadException? error;
  int uploadCalls = 0;
  Uint8List? uploadedBytes;
  String? uploadedFileName;
  String? uploadedContentType;

  @override
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String authToken,
  }) async {
    uploadCalls += 1;
    uploadedBytes = bytes;
    uploadedFileName = fileName;
    uploadedContentType = contentType;
    if (error != null) throw error!;
    return url;
  }
}
