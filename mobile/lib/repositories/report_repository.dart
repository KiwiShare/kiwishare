import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/report_draft.dart';
import '../models/report_history_entry.dart';

class ReportRepositoryException implements Exception {
  const ReportRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReportAuthenticationException extends ReportRepositoryException {
  const ReportAuthenticationException()
    : super('Your session has expired. Please sign in again.');
}

class ReportRepository {
  ReportRepository({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<ReportHistoryEntry>> fetchHistory({required String token}) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/api/reports'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    final body = _decodeBody(response.body);
    final errorMessage = body?['message']?.toString();

    if (response.statusCode == 401 ||
        (response.statusCode == 403 &&
            (errorMessage?.contains('authorization token') ?? false))) {
      throw const ReportAuthenticationException();
    }
    if (response.statusCode != 200) {
      throw ReportRepositoryException(
        errorMessage != null && errorMessage.trim().isNotEmpty
            ? errorMessage
            : 'We could not load your reports. Check your connection and try again.',
      );
    }

    final rawReports = body?['reports'];
    if (rawReports is! List) {
      throw const ReportRepositoryException(
        'The report service returned an invalid history.',
      );
    }

    try {
      return rawReports
          .map(
            (raw) => ReportHistoryEntry.fromJson(
              Map<String, dynamic>.from(raw as Map),
            ),
          )
          .toList(growable: false);
    } on Object {
      throw const ReportRepositoryException(
        'The report service returned an invalid history.',
      );
    }
  }

  Future<void> submit(ReportDraft draft, {required String token}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/api/reports'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(draft.toRequestMap()),
    );
    if (response.statusCode != 201) {
      throw Exception('Could not submit your report. Please try again.');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['report'] is! Map || data['report']['id'] is! String) {
      throw const FormatException('Missing report receipt.');
    }
  }

  Map<String, dynamic>? _decodeBody(String responseBody) {
    if (responseBody.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(responseBody);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }
}
