import 'dart:convert';
import '../../../core/network/api_client.dart';

class StoryDetailApiClient {
  StoryDetailApiClient({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> fetchDetail(String hnId) async {
    final resp = await _apiClient.get('/v1/stories/$hnId');
    if (resp.statusCode != 200) {
      throw Exception('Story detail failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected story detail response');
    }
    return decoded;
  }

  Future<List<dynamic>> fetchComments(String hnId, {int? limit}) async {
    final resp = await _apiClient.get(
      '/v1/stories/$hnId/comments',
      query: limit == null ? null : {'limit': '$limit'},
    );
    if (resp.statusCode != 200) {
      throw Exception('Comments failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected comments response');
    }
    return decoded;
  }

  Future<void> markRead(String hnId) async {
    final resp = await _apiClient.post('/v1/stories/$hnId/read', auth: true);
    if (resp.statusCode != 200) {
      throw Exception('Mark read failed: ${resp.statusCode}');
    }
  }
}
