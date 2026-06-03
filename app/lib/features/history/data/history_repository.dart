import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/constants/api_constants.dart';
import 'package:fitness_ai/core/network/api_client.dart';
import 'package:fitness_ai/core/network/api_exception.dart';
import 'package:fitness_ai/core/storage/hive_storage.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

/// Repository for workout history.
/// Reads from local Hive cache, syncs with API.
class HistoryRepository {
  HistoryRepository({required this.apiClient});

  final ApiClient apiClient;

  /// Get all local sessions sorted by date (newest first).
  /// Parsing is per-record defensive: a single malformed cached entry can
  /// never blank the whole screen.
  List<WorkoutSession> getLocalSessions() {
    final out = <WorkoutSession>[];
    for (final m in HiveStorage.sessions.values) {
      try {
        final s = WorkoutSession.fromJson(Map<String, dynamic>.from(m as Map));
        if (s.isCompleted) out.add(s);
      } catch (_) {
        // skip corrupt/incompatible cached record
      }
    }
    out.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return out;
  }

  /// Fetch sessions from API and cache locally.
  Future<List<WorkoutSession>> fetchSessions({
    DateTime? from,
    DateTime? to,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };
      if (from != null) params['from'] = from.toIso8601String();
      if (to != null) params['to'] = to.toIso8601String();

      final response = await apiClient.get(
        ApiConstants.workoutSessions,
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];
      final sessions = items
          .map((item) =>
              WorkoutSession.fromJson(item as Map<String, dynamic>))
          .toList();

      // Cache locally
      for (final session in sessions) {
        final cached = session.copyWith(synced: true);
        await HiveStorage.sessions.put(cached.id, cached.toJson());
      }

      return sessions;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Provider for history repository.
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(apiClient: ref.watch(apiClientProvider));
});
