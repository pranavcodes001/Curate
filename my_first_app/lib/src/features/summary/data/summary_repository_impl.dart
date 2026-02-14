import '../domain/models/summary.dart';
import '../domain/repositories/summary_repository.dart';
import '../../../core/models/route_arguments.dart';
import 'summary_api_client.dart';
import '../../../core/cache/cache_store.dart';

class SummaryRepositoryImpl implements SummaryRepository {
  SummaryRepositoryImpl({SummaryApiClient? apiClient})
    : _apiClient = apiClient ?? SummaryApiClient();

  final SummaryApiClient _apiClient;
  static const Duration _summaryTtl = Duration(days: 7);

  String _cacheKey(String hnId, SummaryTargetType type) {
    return 'summary:${type.name}:$hnId';
  }

  Summary _mapSummary(Map<String, dynamic> raw, String hnId) {
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
  Future<Summary?> fetchSummary(String hnId, SummaryTargetType type) async {
    final cached = CacheStore.instance.getJson(_cacheKey(hnId, type));
    if (cached is Map<String, dynamic>) {
      try {
        return _mapSummary(cached, hnId);
      } catch (_) {
        // ignore cache parse issues
      }
    } else if (cached is Map) {
      try {
        return _mapSummary(Map<String, dynamic>.from(cached), hnId);
      } catch (_) {}
    }

    final raw = await _apiClient.fetchSummary(hnId, type);
    if (raw == null) return null;
    await CacheStore.instance.setJson(_cacheKey(hnId, type), raw, _summaryTtl);
    return _mapSummary(raw, hnId);
  }

  @override
  Future<Summary> generateSummary(String hnId, SummaryTargetType type) async {
    final raw = await _apiClient.generateSummary(hnId, type);
    await CacheStore.instance.setJson(_cacheKey(hnId, type), raw, _summaryTtl);
    return _mapSummary(raw, hnId);
  }
}
