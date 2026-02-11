import '../domain/models/feed_item.dart';
import '../domain/repositories/feed_repository.dart';
import 'feed_api_client.dart';

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl({FeedApiClient? apiClient})
    : _apiClient = apiClient ?? FeedApiClient();

  final FeedApiClient _apiClient;

  @override
  Future<List<FeedItem>> fetchInterestFeed({int? limit}) async {
    final raw = await _apiClient.fetchInterestFeed(limit: limit);

    return raw
        .map<FeedItem>((item) {
          if (item is! Map<String, dynamic>) {
            throw Exception('Invalid feed item shape');
          }

          final hnId = item['hn_id']?.toString() ?? '';
          return FeedItem(
            hnId: hnId,
            title: item['title'] as String?,
            url: item['url'] as String?,
            score: item['score'] as int?,
            time: item['time'] as int?,
            isRead: item['is_read'] as bool? ?? false,
            tags: (item['tags'] as List?)?.map((e) => e.toString()).toList(),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<FeedItem>> fetchTopStories({int? limit}) async {
    final raw = await _apiClient.fetchTopStories(limit: limit);
    return raw
        .map<FeedItem>((item) {
          if (item is! Map<String, dynamic>) {
            throw Exception('Invalid feed item shape');
          }

          final hnId = item['hn_id']?.toString() ?? '';
          return FeedItem(
            hnId: hnId,
            title: item['title'] as String?,
            url: item['url'] as String?,
            score: item['score'] as int?,
            time: item['time'] as int?,
            isRead: item['is_read'] as bool? ?? false,
            tags: (item['tags'] as List?)?.map((e) => e.toString()).toList(),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> markSeen(List<String> hnIds) async {
    final ids = hnIds
        .map(int.tryParse)
        .whereType<int>()
        .toList(growable: false);
    if (ids.isEmpty) return;
    await _apiClient.markSeen(ids);
  }

  @override
  Future<void> dismissStory(String hnId) async {
    final id = int.tryParse(hnId);
    if (id == null) return;
    await _apiClient.dismiss([id]);
  }
}
