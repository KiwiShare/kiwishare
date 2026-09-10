import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Thin abstraction over the `/api/notifications/devices` endpoints.
abstract class PushDeviceRepository {
  /// Registers [token] for the authenticated [jwtToken] user.
  Future<void> registerToken({
    required String token,
    required String platform, // 'android' | 'ios'
    required String jwtToken,
  });

  /// Removes [token] for the authenticated user.
  /// The backend permits a five-minute grace period for a just-expired JWT so
  /// logout can remove this authenticated session's exact token.
  Future<void> unregisterToken({
    required String token,
    required String jwtToken,
  });
}

class RestPushDeviceRepository implements PushDeviceRepository {
  final http.Client _client;

  RestPushDeviceRepository({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
    required String jwtToken,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/devices'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $jwtToken',
      },
      body: jsonEncode({'token': token, 'platform': platform}),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to register push device token (${response.statusCode}).',
      );
    }
  }

  @override
  Future<void> unregisterToken({
    required String token,
    required String jwtToken,
  }) async {
    final request = http.Request(
      'DELETE',
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/devices'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwtToken',
    });
    request.body = jsonEncode({'token': token});
    final streamedResponse = await _client.send(request);
    if (streamedResponse.statusCode != 200) {
      throw Exception(
        'Failed to unregister push device token (${streamedResponse.statusCode}).',
      );
    }
  }
}
