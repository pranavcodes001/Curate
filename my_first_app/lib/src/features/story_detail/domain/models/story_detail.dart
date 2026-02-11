class StoryDetail {
  final String hnId;
  final String? title;
  final String? url;
  final int? score;
  final int? time;
  final String? text;
  final List<CommentPreview> commentPreview;

  const StoryDetail({
    required this.hnId,
    required this.title,
    required this.url,
    required this.score,
    required this.time,
    required this.text,
    required this.commentPreview,
  });
}

class CommentPreview {
  final String commentHnId;
  final String? parentHnId;
  final String? author;
  final int? time;
  final String? text;

  final List<CommentPreview> children; // Added for recursion

  const CommentPreview({
    required this.commentHnId,
    this.parentHnId,
    required this.author,
    required this.time,
    required this.text,
    this.children = const [],
  });
}
