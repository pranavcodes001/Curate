import '../domain/models/feed_item.dart';
import '../domain/repositories/feed_repository.dart';
import 'feed_api_client.dart';
import '../../../core/cache/cache_store.dart';

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl({FeedApiClient? apiClient})
    : _apiClient = apiClient ?? FeedApiClient();

  final FeedApiClient _apiClient;
  static const Duration _topFeedTtl = Duration(hours: 24);
  static const Duration _interestFeedTtl = Duration(hours: 24);

  List<FeedItem> _mapFeedItems(List<dynamic> raw) {
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
  Future<List<FeedItem>> fetchInterestFeed({int? limit, bool forceRefresh = false}) async {
    final key = 'feed:interest:${limit ?? "default"}';
    if (!forceRefresh) {
      final cached = CacheStore.instance.getJson(key);
      if (cached is List) {
        try {
          return _mapFeedItems(cached.cast<dynamic>());
        } catch (_) {
          // ignore cache parse issues
        }
      }
    }

    try {
      final raw = await _apiClient.fetchInterestFeed(limit: limit);
      await CacheStore.instance.setJson(key, raw, _interestFeedTtl);
      return _mapFeedItems(raw);
    } catch (_) {
      final cached = CacheStore.instance.getJson(key);
      if (cached is List) {
        return _mapFeedItems(cached.cast<dynamic>());
      }
      rethrow;
    }
  }

  @override
  Future<List<FeedItem>> fetchTopStories({int? limit, bool forceRefresh = false}) async {
    final key = 'feed:top:${limit ?? "default"}';
    if (!forceRefresh) {
      final cached = CacheStore.instance.getJson(key);
      if (cached is List) {
        try {
          return _mapFeedItems(cached.cast<dynamic>());
        } catch (_) {
          // ignore cache parse issues
        }
      }
    }

    try {
      final raw = await _apiClient.fetchTopStories(limit: limit);
      await CacheStore.instance.setJson(key, raw, _topFeedTtl);
      return _mapFeedItems(raw);
    } catch (_) {
      final cached = CacheStore.instance.getJson(key);
      if (cached is List) {
        return _mapFeedItems(cached.cast<dynamic>());
      }
      rethrow;
    }
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
