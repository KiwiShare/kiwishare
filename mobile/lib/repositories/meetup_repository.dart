import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/meetup_model.dart';

class MeetupRepositoryException implements Exception {
  const MeetupRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class MeetupRepository {
  Future<MeetupModel> proposeMeetup({
    required String itemId,
    String? conversationId,
    required DateTime scheduledAt,
    required String locationName,
    double? latitude,
    double? longitude,
    String? note,
    required String token,
  });

  Future<MeetupModel> acceptMeetup({
    required String orderId,
    required String token,
    String? messageId,
    DateTime? scheduledAt,
    String? locationName,
  });

  Future<void> declineMeetup({required String orderId, required String token});

  Future<List<MeetupModel>> fetchMyMeetups({required String token});

  Future<MeetupModel> fetchMeetupDetails({
    required String orderId,
    required String token,
  });

  Future<Map<String, dynamic>> claimHandover({
    required String claimCode,
    String? itemId,
    required String token,
  });

  Future<Map<String, dynamic>> confirmHandover({
    required String orderId,
    required String token,
  });
}

class RestMeetupRepository implements MeetupRepository {
  RestMeetupRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> _headers(String token) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  @override
  Future<MeetupModel> proposeMeetup({
    required String itemId,
    String? conversationId,
    required DateTime scheduledAt,
    required String locationName,
    double? latitude,
    double? longitude,
    String? note,
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/meetups/propose'),
      headers: _headers(token),
      body: jsonEncode({
        'itemId': itemId,
        'conversationId': ?conversationId,
        'scheduledAt': scheduledAt.toIso8601String(),
        'locationName': locationName,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'note': ?note,
      }),
    );
    final data = _responseMap(response);
    final meetupJson = data['meetup'];
    if (meetupJson is! Map) {
      throw const MeetupRepositoryException(
        'Invalid response when proposing meetup.',
      );
    }
    return MeetupModel.fromJson(Map<String, dynamic>.from(meetupJson));
  }

  @override
  Future<MeetupModel> acceptMeetup({
    required String orderId,
    required String token,
    String? messageId,
    DateTime? scheduledAt,
    String? locationName,
  }) async {
    final bodyData = <String, dynamic>{
      'messageId': ?messageId,
      if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
      'locationName': ?locationName,
    };
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/meetups/$orderId/accept'),
      headers: _headers(token),
      body: bodyData.isNotEmpty ? jsonEncode(bodyData) : null,
    );
    final data = _responseMap(response);
    final meetupJson = data['meetup'];
    if (meetupJson is! Map) {
      throw const MeetupRepositoryException(
        'Invalid response when accepting meetup.',
      );
    }
    return MeetupModel.fromJson(Map<String, dynamic>.from(meetupJson));
  }

  @override
  Future<void> declineMeetup({
    required String orderId,
    required String token,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/meetups/$orderId/decline'),
      headers: _headers(token),
    );
    _responseMap(response);
  }

  @override
  Future<List<MeetupModel>> fetchMyMeetups({required String token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/meetups/my'),
      headers: _headers(token),
    );
    final data = _responseMap(response);
    final list = data['meetups'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((m) => MeetupModel.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  @override
  Future<MeetupModel> fetchMeetupDetails({
    required String orderId,
    required String token,
  }) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/meetups/$orderId'),
      headers: _headers(token),
    );
    final data = _responseMap(response);
    final meetupJson = data['meetup'];
    if (meetupJson is! Map) {
      throw const MeetupRepositoryException(
        'Invalid response fetching meetup.',
      );
    }
    return MeetupModel.fromJson(Map<String, dynamic>.from(meetupJson));
  }

  Map<String, dynamic> _responseMap(http.Response response) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) data = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MeetupRepositoryException(
        data?['message']?.toString() ??
            'Meetup operation failed. Please try again.',
      );
    }
    if (data == null) {
      throw const MeetupRepositoryException(
        'Invalid response from meetup service.',
      );
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> claimHandover({
    required String claimCode,
    String? itemId,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/transactions/handover/claim',
    );
    final response = await _client.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'claimCode': claimCode, 'itemId': ?itemId}),
    );
    return _responseMap(response);
  }

  @override
  Future<Map<String, dynamic>> confirmHandover({
    required String orderId,
    required String token,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/meetups/$orderId/confirm-handover',
    );
    final response = await _client.post(uri, headers: _headers(token));
    return _responseMap(response);
  }
}
