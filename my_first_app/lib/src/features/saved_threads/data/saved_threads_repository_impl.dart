import '../domain/models/saved_thread.dart';
import 'saved_threads_api_client.dart';

class SavedThreadsRepositoryImpl {
  SavedThreadsRepositoryImpl({SavedThreadsApiClient? apiClient})
    : _api = apiClient ?? SavedThreadsApiClient();

  final SavedThreadsApiClient _api;

  Future<List<SavedThread>> listThreads() async {
    final raw = await _api.listThreads();
    return raw
        .map<SavedThread>((item) => _mapThread(item))
        .toList(growable: false);
  }

  Future<SavedThread> getThread(int id) async {
    final raw = await _api.getThread(id);
    return _mapThread(raw);
  }

  Future<void> createThread(String storyHnId, List<String> commentIds) {
    return _api.createThread(storyHnId, commentIds);
  }

  SavedThread _mapThread(dynamic item) {
    if (item is! Map) {
      throw Exception('Invalid saved thread');
    }
    final itemsRaw = item['items'];
    final items = <SavedThreadItem>[];
    if (itemsRaw is List) {
      for (final i in itemsRaw) {
        if (i is Map) {
          final aiSummaryRaw = i['ai_summary'];
          final aiSummary = (aiSummaryRaw is Map)
              ? aiSummaryRaw.cast<String, dynamic>()
              : null;

          items.add(
            SavedThreadItem(
              itemType: i['item_type']?.toString() ?? '',
              hnId: i['hn_id']?.toString() ?? '',
              rawText: i['raw_text'] as String?,
              aiSummary: aiSummary,
              modelName: i['model_name'] as String?,
              modelVersion: i['model_version']?.toString() ?? '',
              createdAt: i['created_at']?.toString() ?? '',
            ),
          );
        }
      }
    }
    return SavedThread(
      id: item['id'] as int? ?? 0,
      storyHnId: item['story_hn_id']?.toString() ?? '',
      title: item['title'] as String?,
      url: item['url'] as String?,
      createdAt: item['created_at']?.toString() ?? '',
      items: items,
    );
  }
}
