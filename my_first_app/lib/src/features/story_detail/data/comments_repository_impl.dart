import '../domain/models/story_detail.dart';
import 'story_detail_api_client.dart';

class CommentsRepositoryImpl {
  CommentsRepositoryImpl({StoryDetailApiClient? apiClient})
    : _apiClient = apiClient ?? StoryDetailApiClient();

  final StoryDetailApiClient _apiClient;

  Future<List<CommentPreview>> fetchComments(String hnId, {int? limit}) async {
    final raw = await _apiClient.fetchComments(hnId, limit: limit);

    // 1. Parse all raw items into flat objects
    final flatList = <CommentPreview>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        flatList.add(
          CommentPreview(
            commentHnId: item['comment_hn_id']?.toString() ?? '',
            parentHnId: item['parent_hn_id']?.toString(),
            author: item['author'] as String?,
            time: item['time'] as int?,
            text: item['text'] as String?,
            children: [],
          ),
        );
      }
    }

    // 2. Build Tree
    // Map ID -> Comment object
    final idMap = {for (var c in flatList) c.commentHnId: c};
    final rootComments = <CommentPreview>[];

    for (final c in flatList) {
      if (c.parentHnId == hnId || c.parentHnId == null) {
        // Direct reply to story -> Root
        rootComments.add(c);
      } else {
        // Reply to another comment -> Find parent
        final parent = idMap[c.parentHnId];
        if (parent != null) {
          parent.children.add(c);
        } else {
          // Orphan (parent not in this batch) -> Treat as root or discard?
          // For now, treat as root so we don't lose it
          rootComments.add(c);
        }
      }
    }

    return rootComments;
  }
}
