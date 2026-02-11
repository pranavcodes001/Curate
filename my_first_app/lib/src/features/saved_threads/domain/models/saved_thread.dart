class SavedThread {
  final int id;
  final String storyHnId;
  final String? title;
  final String? url;
  final String createdAt;
  final List<SavedThreadItem> items;

  const SavedThread({
    required this.id,
    required this.storyHnId,
    required this.title,
    this.url,
    required this.createdAt,
    required this.items,
  });
}

class SavedThreadItem {
  final String itemType;
  final String hnId;
  final String? rawText;
  final Map<String, dynamic>? aiSummary;
  final String? modelName;
  final String modelVersion;
  final String createdAt;

  const SavedThreadItem({
    required this.itemType,
    required this.hnId,
    required this.rawText,
    required this.aiSummary,
    required this.modelName,
    required this.modelVersion,
    required this.createdAt,
  });
}
