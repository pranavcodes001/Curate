import 'dart:convert';
import '../../../core/network/api_client.dart';

class SavedThreadsApiClient {
  SavedThreadsApiClient({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<dynamic>> listThreads() async {
    final resp = await _api.get('/v1/saved_threads', auth: true);
    if (resp.statusCode != 200) {
      throw Exception('Saved threads failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected saved threads response');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> getThread(int id) async {
    final resp = await _api.get('/v1/saved_threads/$id', auth: true);
    if (resp.statusCode != 200) {
      throw Exception('Saved thread failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected saved thread response');
    }
    return decoded;
  }

  Future<void> createThread(String storyHnId, List<String> commentIds) async {
    final resp = await _api.post(
      '/v1/saved_threads',
      auth: true,
      body: {
        'story_hn_id': int.tryParse(storyHnId) ?? 0,
        'comment_hn_ids': commentIds.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toList(),
      },
    );
    if (resp.statusCode != 202) {
      throw Exception('Save thread failed: ${resp.statusCode}');
    }
  }
}
