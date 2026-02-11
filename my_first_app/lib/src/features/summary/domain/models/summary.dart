class Summary {
  final String hnId;
  final String? modelVersion;
  final String? modelName;
  final String? tldr;
  final List<String> keyPoints;
  final String? consensus;
  final String? createdAt;
  final String? updatedAt;

  const Summary({
    required this.hnId,
    required this.modelVersion,
    required this.modelName,
    required this.tldr,
    required this.keyPoints,
    required this.consensus,
    required this.createdAt,
    required this.updatedAt,
  });
}
