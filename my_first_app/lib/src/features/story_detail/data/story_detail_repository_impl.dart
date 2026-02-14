import '../domain/models/story_detail.dart';
import 'story_detail_api_client.dart';
import '../../../core/cache/cache_store.dart';

class StoryDetailRepositoryImpl {
  StoryDetailRepositoryImpl({StoryDetailApiClient? apiClient})
    : _apiClient = apiClient ?? StoryDetailApiClient();

  final StoryDetailApiClient _apiClient;
  static const Duration _detailTtl = Duration(hours: 24);

  Future<StoryDetail> fetchDetail(String hnId) async {
    final cacheKey = 'story:detail:$hnId';
    StoryDetail? cachedDetail;
    final cached = CacheStore.instance.getJson(cacheKey);
    try {
      if (cached is Map<String, dynamic>) {
        cachedDetail = _mapDetail(cached, hnId);
      } else if (cached is Map) {
        cachedDetail = _mapDetail(Map<String, dynamic>.from(cached), hnId);
      }
    } catch (_) {
      cachedDetail = null;
    }

    try {
      final raw = await _apiClient.fetchDetail(hnId);
      await CacheStore.instance.setJson(cacheKey, raw, _detailTtl);
      final detail = _mapDetail(raw, hnId);
      try {
        await _apiClient.markRead(detail.hnId);
      } catch (_) {
        // best-effort
      }
      return detail;
    } catch (_) {
      if (cachedDetail != null) {
        return cachedDetail;
      }
      rethrow;
    }

  }

  StoryDetail _mapDetail(Map<String, dynamic> raw, String hnId) {
    final previewRaw = raw['comment_preview'];
    final previews = <CommentPreview>[];
    if (previewRaw is List) {
      for (final item in previewRaw) {
        if (item is Map<String, dynamic>) {
          previews.add(
            CommentPreview(
              commentHnId: item['comment_hn_id']?.toString() ?? '',
              parentHnId: item['parent_hn_id']?.toString(),
              author: item['author'] as String?,
              time: item['time'] as int?,
              text: item['text'] as String?,
            ),
          );
        }
      }
    }
    return StoryDetail(
      hnId: raw['hn_id']?.toString() ?? hnId,
      title: raw['title'] as String?,
      url: raw['url'] as String?,
      score: raw['score'] as int?,
      time: raw['time'] as int?,
      text: raw['text'] as String?,
      commentPreview: previews,
    );
  }
}
