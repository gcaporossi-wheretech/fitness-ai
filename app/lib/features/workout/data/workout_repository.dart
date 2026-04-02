import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:fitness_ai/core/constants/api_constants.dart';
import 'package:fitness_ai/core/network/api_client.dart';
import 'package:fitness_ai/core/network/api_exception.dart';
import 'package:fitness_ai/core/storage/hive_storage.dart';
import 'package:fitness_ai/features/workout/domain/exercise.dart';
import 'package:fitness_ai/features/workout/domain/workout_plan.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

const _uuid = Uuid();

/// Repository for workout data.
/// Offline-first: writes to Hive, then syncs to API.
class WorkoutRepository {
  WorkoutRepository({required this.apiClient});

  final ApiClient apiClient;

  // ============================================================
  // Sessions (local-first)
  // ============================================================

  /// Save a session to local Hive storage.
  Future<void> saveSessionLocally(WorkoutSession session) async {
    await HiveStorage.sessions.put(session.id, session.toJson());
  }

  /// Get a session by ID from local storage.
  WorkoutSession? getSession(String id) {
    final data = HiveStorage.sessions.get(id);
    if (data == null) return null;
    return WorkoutSession.fromJson(Map<String, dynamic>.from(data));
  }

  /// Get all local sessions, most recent first.
  List<WorkoutSession> getAllLocalSessions() {
    return HiveStorage.sessions.values
        .map((m) => WorkoutSession.fromJson(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  /// Get unsynced sessions that need to be sent to the API.
  List<WorkoutSession> getUnsyncedSessions() {
    return getAllLocalSessions()
        .where((s) => s.isCompleted && !s.synced)
        .toList();
  }

  /// Generate a new session ID.
  String generateSessionId() => _uuid.v4();

  /// Sync a completed session to the API.
  Future<void> syncSession(WorkoutSession session) async {
    try {
      await apiClient.post(
        ApiConstants.workoutSessions,
        data: {
          'client_id': session.id,
          'plan_id': session.planId,
          'day_name': session.dayName,
          'started_at': session.startedAt.toIso8601String(),
          'completed_at': session.completedAt?.toIso8601String(),
          'duration_seconds': session.durationSeconds,
          'exercises': session.exercises
              .where((e) => !e.skipped)
              .map((e) => e.toApiJson())
              .toList(),
          'notes': session.notes.isNotEmpty ? session.notes : null,
        },
      );
      // Mark as synced locally
      final synced = session.copyWith(synced: true);
      await saveSessionLocally(synced);
    } on DioException catch (e) {
      // If conflict (duplicate), mark as synced
      if (e.response?.statusCode == 409) {
        final synced = session.copyWith(synced: true);
        await saveSessionLocally(synced);
      } else {
        throw ApiException.fromDioException(e);
      }
    }
  }

  /// Sync all unsynced sessions.
  Future<int> syncAllPending() async {
    final pending = getUnsyncedSessions();
    int synced = 0;
    for (final session in pending) {
      try {
        await syncSession(session);
        synced++;
      } catch (_) {
        // Continue syncing other sessions
      }
    }
    return synced;
  }

  // ============================================================
  // Plans (API-first with local cache)
  // ============================================================

  /// Fetch workout plans from API and cache locally.
  Future<List<WorkoutPlan>> fetchPlans() async {
    try {
      final response = await apiClient.get(ApiConstants.workoutPlans);
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];
      final plans = items
          .map((item) =>
              WorkoutPlan.fromJson(item as Map<String, dynamic>))
          .toList();

      // Cache locally
      for (final plan in plans) {
        await HiveStorage.plans.put(plan.id, plan.toJson());
      }

      return plans;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get cached plans from Hive (for offline use).
  List<WorkoutPlan> getCachedPlans() {
    return HiveStorage.plans.values
        .map((m) => WorkoutPlan.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  // ============================================================
  // Exercises (API-first with local cache)
  // ============================================================

  /// Fetch exercises catalog from API and cache locally.
  Future<List<Exercise>> fetchExercises() async {
    try {
      final response = await apiClient.get(ApiConstants.workoutExercises);
      final items = (response.data as List?) ?? [];
      final exercises = items
          .map((item) => Exercise.fromJson(item as Map<String, dynamic>))
          .toList();

      // Cache locally
      for (final ex in exercises) {
        await HiveStorage.exercises.put(ex.id, ex.toJson());
      }

      return exercises;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get cached exercises from Hive (for offline use).
  List<Exercise> getCachedExercises() {
    return HiveStorage.exercises.values
        .map((m) => Exercise.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}

/// Provider for workout repository.
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(apiClient: ref.watch(apiClientProvider));
});
