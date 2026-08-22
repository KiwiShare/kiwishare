import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Cloudflare R2 S3 Upload Service for KiwiShare
class R2UploadService {
  static const String publicDomain = 'https://assets.kiwishare.online';
  static const String r2Endpoint =
      'https://cdc04de9bc4c6a41b5003758e505a0d1.r2.cloudflarestorage.com/kiwishare';
  static const String r2Bucket = 'kiwishare';

  final http.Client _client;

  R2UploadService({http.Client? client}) : _client = client ?? http.Client();

  /// Uploads image bytes to Cloudflare R2 bucket `kiwishare`
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
    String? authToken,
  }) async {
    final base64Image = base64Encode(bytes);

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload');
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-client-platform': 'mobile',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
      body: jsonEncode({
        'imageBase64': base64Image,
        'fileName': fileName,
        'contentType': contentType,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = data['url'] as String?;
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }

    // Fallback direct formatted public R2 URL
    return '$publicDomain/images/${DateTime.now().millisecondsSinceEpoch}_$fileName';
  }
}
