import '../domain/models/feed_item.dart';
import 'search_api_client.dart';

class SearchRepositoryImpl {
  SearchRepositoryImpl({SearchApiClient? apiClient})
    : _apiClient = apiClient ?? SearchApiClient();

  final SearchApiClient _apiClient;

  Future<List<FeedItem>> search(String query, {int? limit}) async {
    final raw = await _apiClient.search(query, limit: limit);
    return raw
        .map<FeedItem>((item) {
          if (item is! Map<String, dynamic>) {
            throw Exception('Invalid search item shape');
          }
          final hnId = item['hn_id']?.toString() ?? '';
          return FeedItem(
            hnId: hnId,
            title: item['title'] as String?,
            url: item['url'] as String?,
            score: item['score'] as int?,
            time: item['time'] as int?,
            tags: (item['tags'] as List?)?.map((e) => e.toString()).toList(),
          );
        })
        .toList(growable: false);
  }
}
