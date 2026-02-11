import '../models/summary.dart';
import '../../../../core/models/route_arguments.dart';

abstract class SummaryRepository {
  Future<Summary?> fetchSummary(String hnId, SummaryTargetType type);
  Future<Summary> generateSummary(String hnId, SummaryTargetType type);
}
