import '../domain/models/story_detail.dart';
import 'story_detail_api_client.dart';

class StoryDetailRepositoryImpl {
  StoryDetailRepositoryImpl({StoryDetailApiClient? apiClient})
    : _apiClient = apiClient ?? StoryDetailApiClient();

  final StoryDetailApiClient _apiClient;

  Future<StoryDetail> fetchDetail(String hnId) async {
    final raw = await _apiClient.fetchDetail(hnId);
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
    final detail = StoryDetail(
      hnId: raw['hn_id']?.toString() ?? hnId,
      title: raw['title'] as String?,
      url: raw['url'] as String?,
      score: raw['score'] as int?,
      time: raw['time'] as int?,
      text: raw['text'] as String?,
      commentPreview: previews,
    );
    try {
      await _apiClient.markRead(detail.hnId);
    } catch (_) {
      // best-effort
    }
    return detail;
  }
}
