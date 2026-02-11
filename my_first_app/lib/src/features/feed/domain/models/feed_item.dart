// Feed Item model
// Responsibility: Define the immutable data model for a single feed item (story preview).

class FeedItem {
  final String hnId;
  final String? title;
  final String? url;
  final int? score;
  final int? time;
  final bool isRead;
  final List<String>? tags;

  const FeedItem({
    required this.hnId,
    required this.title,
    required this.url,
    required this.score,
    required this.time,
    this.isRead = false,
    this.tags,
  });
}
