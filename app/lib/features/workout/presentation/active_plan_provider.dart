import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/features/auth/domain/auth_state.dart';
import 'package:fitness_ai/features/auth/presentation/auth_notifier.dart';
import 'package:fitness_ai/features/history/data/history_repository.dart';
import 'package:fitness_ai/features/workout/data/workout_repository.dart';
import 'package:fitness_ai/features/workout/domain/workout_plan.dart';

/// Loads the user's active workout plan.
///
/// Watches the auth state so it only calls the API once the user is
/// authenticated (the JWT is then guaranteed stored and attachable) and
/// re-runs automatically when auth changes — this avoids a race where the
/// home builds before the token is ready and caches an empty result.
///
/// Hydrates plans + recent sessions from the server so data appears on any
/// device after login, and falls back to the local Hive cache when offline.
final activePlanProvider = FutureProvider.autoDispose<WorkoutPlan?>((ref) async {
  final repo = ref.read(workoutRepositoryProvider);
  final auth = ref.watch(authNotifierProvider);

  WorkoutPlan? pickActive(List<WorkoutPlan> plans) {
    if (plans.isEmpty) return null;
    return plans.firstWhere((p) => p.isActive, orElse: () => plans.first);
  }

  // Not authenticated yet: show whatever is cached locally (usually nothing).
  if (auth is! AuthAuthenticated) {
    return pickActive(repo.getCachedPlans());
  }

  final history = ref.read(historyRepositoryProvider);
  List<WorkoutPlan> plans;
  try {
    plans = await repo.fetchPlans();
    // Best-effort: pull recent sessions for history + weight pre-fill.
    try {
      await history.fetchSessions(perPage: 50);
    } catch (_) {}
  } catch (_) {
    // Offline or transient error: fall back to the local cache.
    plans = repo.getCachedPlans();
  }
  return pickActive(plans);
});
