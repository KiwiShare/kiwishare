import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/report_draft.dart';

class ReportRepository {
  ReportRepository({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

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
}
