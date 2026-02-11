import 'dart:convert';
import '../../../core/network/api_client.dart';

class FeedApiClient {
  FeedApiClient({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<dynamic>> fetchTopStories({int? limit}) async {
    final resp = await _apiClient.get(
      '/v1/stories',
      query: limit == null ? null : {'limit': '$limit'},
      auth: false,
    );
    if (resp.statusCode != 200) {
      throw Exception('Top stories request failed: ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected top stories response shape');
    }
    return decoded;
  }

  Future<List<dynamic>> fetchInterestFeed({int? limit}) async {
    final resp = await _apiClient.get(
      '/v1/feed',
      query: limit == null ? null : {'limit': '$limit'},
      auth: true,
    );
    if (resp.statusCode != 200) {
      throw Exception('Feed request failed: ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected feed response shape');
    }
    return decoded;
  }

  Future<void> markSeen(List<int> hnIds) async {
    if (hnIds.isEmpty) return;
    final resp = await _apiClient.post(
      '/v1/feed/seen',
      auth: true,
      body: {'hn_ids': hnIds},
    );
    if (resp.statusCode != 200) {
      throw Exception('Feed seen request failed: ${resp.statusCode}');
    }
  }

  Future<void> dismiss(List<int> hnIds) async {
    if (hnIds.isEmpty) return;
    final resp = await _apiClient.post(
      '/v1/feed/dismiss',
      auth: true,
      body: {'hn_ids': hnIds},
    );
    if (resp.statusCode != 200) {
      throw Exception('Feed dismiss request failed: ${resp.statusCode}');
    }
  }
}
