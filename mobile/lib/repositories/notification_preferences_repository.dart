import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class WatchlistNotificationPreferences {
  const WatchlistNotificationPreferences({
    required this.priceChanges,
    required this.nearbyCategory,
  });

  final bool priceChanges;
  final bool nearbyCategory;
}

abstract class NotificationPreferencesRepository {
  Future<bool> fetchWatchlistPriceDrop({required String token});
  Future<bool> updateWatchlistPriceDrop({
    required String token,
    required bool enabled,
  });
}

abstract interface class ExtendedNotificationPreferencesRepository {
  Future<WatchlistNotificationPreferences> fetchWatchlistPreferences({
    required String token,
  });

  Future<WatchlistNotificationPreferences> updateWatchlistPreferences({
    required String token,
    bool? priceChanges,
    bool? nearbyCategory,
  });
}

class RestNotificationPreferencesRepository
    implements
        NotificationPreferencesRepository,
        ExtendedNotificationPreferencesRepository {
  RestNotificationPreferencesRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  WatchlistNotificationPreferences _parsePreferences(
    Map<String, dynamic>? preferences,
  ) {
    final priceChanges =
        preferences?['watchlistPriceChange'] ??
        preferences?['watchlistPriceDrop'] ??
        true;
    final nearbyCategory = preferences?['watchlistNearbyCategory'] ?? false;
    if (priceChanges is! bool || nearbyCategory is! bool) {
      throw const NotificationPreferencesException();
    }
    return WatchlistNotificationPreferences(
      priceChanges: priceChanges,
      nearbyCategory: nearbyCategory,
    );
  }

  @override
  Future<bool> fetchWatchlistPriceDrop({required String token}) async {
    return (await fetchWatchlistPreferences(token: token)).priceChanges;
  }

  @override
  Future<bool> updateWatchlistPriceDrop({
    required String token,
    required bool enabled,
  }) async {
    final result = await updateWatchlistPreferences(
      token: token,
      priceChanges: enabled,
    );
    return result.priceChanges == enabled;
  }

  @override
  Future<WatchlistNotificationPreferences> fetchWatchlistPreferences({
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/preferences'),
      headers: _headers(token),
    );
    if (response.statusCode != 200) {
      throw const NotificationPreferencesException();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return _parsePreferences(body['preferences'] as Map<String, dynamic>?);
  }

  @override
  Future<WatchlistNotificationPreferences> updateWatchlistPreferences({
    required String token,
    bool? priceChanges,
    bool? nearbyCategory,
  }) async {
    final payload = <String, dynamic>{
      'watchlistPriceChange': ?priceChanges,
      'watchlistNearbyCategory': ?nearbyCategory,
    };
    if (payload.isEmpty) {
      return fetchWatchlistPreferences(token: token);
    }

    final response = await _client.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/notifications/preferences'),
      headers: _headers(token),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) {
      throw const NotificationPreferencesException();
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return _parsePreferences(body['preferences'] as Map<String, dynamic>?);
  }
}

class NotificationPreferencesException implements Exception {
  const NotificationPreferencesException();
}
