import 'dart:convert';
import '../../../core/network/api_client.dart';
import '../../../core/models/route_arguments.dart';

class SummaryApiClient {
  SummaryApiClient({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<Map<String, dynamic>?> fetchSummary(String hnId, SummaryTargetType type) async {
    final path = type == SummaryTargetType.comment
        ? '/v1/comments/$hnId/summary'
        : '/v1/stories/$hnId/summary';
    final resp = await _api.get(path);

    if (resp.statusCode == 404) {
      return null;
    }

    if (resp.statusCode != 200) {
      throw Exception('Summary request failed: ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected summary response shape');
    }

    return decoded;
  }

  Future<Map<String, dynamic>> generateSummary(String hnId, SummaryTargetType type) async {
    final path = type == SummaryTargetType.comment
        ? '/v1/comments/$hnId/summary/generate'
        : '/v1/stories/$hnId/summary/generate';
    final resp = await _api.post(path, auth: true);
    if (resp.statusCode != 200 && resp.statusCode != 202) {
      throw Exception('Generate summary failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected generate response shape');
    }
    return decoded;
  }
}
