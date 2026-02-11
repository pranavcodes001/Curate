import '../domain/models/summary.dart';
import '../domain/repositories/summary_repository.dart';
import '../../../core/models/route_arguments.dart';
import 'summary_api_client.dart';

class SummaryRepositoryImpl implements SummaryRepository {
  SummaryRepositoryImpl({SummaryApiClient? apiClient})
    : _apiClient = apiClient ?? SummaryApiClient();

  final SummaryApiClient _apiClient;

  @override
  Future<Summary?> fetchSummary(String hnId, SummaryTargetType type) async {
    final raw = await _apiClient.fetchSummary(hnId, type);
    if (raw == null) return null;

    final keyPointsRaw = raw['key_points'];
    final keyPoints = <String>[];
    if (keyPointsRaw is List) {
      for (final item in keyPointsRaw) {
        if (item is String) {
          keyPoints.add(item);
        } else if (item != null) {
          keyPoints.add(item.toString());
        }
      }
    }

    return Summary(
      hnId: raw['hn_id']?.toString() ?? hnId,
      modelVersion: raw['model_version'] as String?,
      modelName: raw['model_name'] as String?,
      tldr: raw['tldr'] as String?,
      keyPoints: keyPoints,
      consensus: raw['consensus'] as String?,
      createdAt: raw['created_at'] as String?,
      updatedAt: raw['updated_at'] as String?,
    );
  }

  @override
  Future<Summary> generateSummary(String hnId, SummaryTargetType type) async {
    final raw = await _apiClient.generateSummary(hnId, type);
    final keyPointsRaw = raw['key_points'];
    final keyPoints = <String>[];
    if (keyPointsRaw is List) {
      for (final item in keyPointsRaw) {
        if (item is String) {
          keyPoints.add(item);
        } else if (item != null) {
          keyPoints.add(item.toString());
        }
      }
    }

    return Summary(
      hnId: raw['hn_id']?.toString() ?? hnId,
      modelVersion: raw['model_version'] as String?,
      modelName: raw['model_name'] as String?,
      tldr: raw['tldr'] as String?,
      keyPoints: keyPoints,
      consensus: raw['consensus'] as String?,
      createdAt: raw['created_at'] as String?,
      updatedAt: raw['updated_at'] as String?,
    );
  }
}
