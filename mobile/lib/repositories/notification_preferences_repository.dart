import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

abstract class NotificationPreferencesRepository {
  Future<bool> fetchWatchlistPriceDrop({required String token});
  Future<bool> updateWatchlistPriceDrop({
    required String token,
    required bool enabled,
  });
}

class RestNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  RestNotificationPreferencesRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  @override
  Future<bool> fetchWatchlistPriceDrop({required String token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/preferences'),
      headers: _headers(token),
    );
    if (response.statusCode != 200) {
      throw const NotificationPreferencesException();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final preferences = body['preferences'] as Map<String, dynamic>?;
    final value = preferences?['watchlistPriceDrop'];
    if (value is! bool) throw const NotificationPreferencesException();
    return value;
  }

  @override
  Future<bool> updateWatchlistPriceDrop({
    required String token,
    required bool enabled,
  }) async {
    final response = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/preferences'),
      headers: _headers(token),
      body: jsonEncode({'watchlistPriceDrop': enabled}),
    );
    if (response.statusCode != 200) {
      throw const NotificationPreferencesException();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['preferences']
            as Map<String, dynamic>?)?['watchlistPriceDrop'] ==
        enabled;
  }
}

class NotificationPreferencesException implements Exception {
  const NotificationPreferencesException();
}
