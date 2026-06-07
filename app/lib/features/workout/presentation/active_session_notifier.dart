import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/features/workout/data/workout_repository.dart';
import 'package:fitness_ai/features/workout/domain/exercise_log.dart';
import 'package:fitness_ai/features/workout/domain/set_log.dart';
import 'package:fitness_ai/features/workout/domain/workout_plan.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

/// State for the active workout session.
class ActiveSessionState {
  const ActiveSessionState({
    required this.session,
    this.currentExerciseIndex = 0,
    this.isCompleted = false,
    this.warmup = const [],
    this.warmupChecked = const [],
    this.resumed = false,
  });

  final WorkoutSession session;
  final int currentExerciseIndex;
  final bool isCompleted;

  /// True when this session was reopened from history (resume). The original
  /// duration is preserved instead of recomputing from the start time.
  final bool resumed;

  /// Warmup items for this day (their text labels).
  final List<String> warmup;

  /// Warmup checklist state (one bool per warmup item).
  final List<bool> warmupChecked;

  ExerciseLog? get currentExercise {
    if (currentExerciseIndex >= session.exercises.length) return null;
    return session.exercises[currentExerciseIndex];
  }

  int get totalExercises => session.exercises.length;
  int get completedExercises => session.exercises
      .where((e) => e.skipped || e.sets.every((s) => s.completed))
      .length;

  /// Whether all warmup items are checked.
  bool get warmupAllDone =>
      warmupChecked.isNotEmpty && warmupChecked.every((c) => c);

  /// Number of warmup items completed.
  int get warmupDoneCount => warmupChecked.where((c) => c).length;

  ActiveSessionState copyWith({
    WorkoutSession? session,
    int? currentExerciseIndex,
    bool? isCompleted,
    List<String>? warmup,
    List<bool>? warmupChecked,
    bool? resumed,
  }) {
    return ActiveSessionState(
      session: session ?? this.session,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      isCompleted: isCompleted ?? this.isCompleted,
      warmup: warmup ?? this.warmup,
      warmupChecked: warmupChecked ?? this.warmupChecked,
      resumed: resumed ?? this.resumed,
    );
  }
}

/// Manages the active workout session state.
class ActiveSessionNotifier extends Notifier<ActiveSessionState?> {
  @override
  ActiveSessionState? build() => null;

  WorkoutRepository get _repo => ref.read(workoutRepositoryProvider);

  /// Start a new session from a workout day plan.
  /// Pre-fills weights from the last completed session for the same day.
  void startSession(WorkoutDay day, {String? planId}) {
    // Pre-fill weights from the most recent time each exercise was performed,
    // across the whole history (independent of day name / plan), matching by
    // exercise name. This keeps pre-fill working even after renaming days or
    // switching plans.
    final completed = _repo
        .getAllLocalSessions() // newest-first
        .where((s) => s.isCompleted)
        .toList();

    String norm(String s) => s.trim().toLowerCase();

    ExerciseLog? lastExerciseNamed(String name) {
      final target = norm(name);
      for (final s in completed) {
        for (final e in s.exercises) {
          if (norm(e.exerciseName) == target &&
              e.sets.any((st) => st.completed && st.weight > 0)) {
            return e;
          }
        }
      }
      return null;
    }

    final exercises = day.exercises.map((ep) {
      final repsInt = int.tryParse(ep.reps) ?? 10;
      final prevExercise = lastExerciseNamed(ep.exerciseName);
      final lastWeighted = prevExercise == null
          ? const <SetLog>[]
          : prevExercise.sets
              .where((s) => s.completed && s.weight > 0)
              .toList();

      return ExerciseLog(
        exerciseId: ep.exerciseId ?? '',
        exerciseName: ep.exerciseName,
        exerciseType: ep.exerciseType,
        restSeconds: ep.restSeconds,
        notes: ep.notes ?? '',
        supersetGroup: ep.supersetGroup,
        sets: List.generate(ep.sets, (i) {
          // Use the matching set index if available, otherwise the last
          // weighted set from that exercise's most recent session.
          double prefillWeight = 0;
          if (prevExercise != null) {
            if (i < prevExercise.sets.length &&
                prevExercise.sets[i].completed &&
                prevExercise.sets[i].weight > 0) {
              prefillWeight = prevExercise.sets[i].weight;
            } else if (lastWeighted.isNotEmpty) {
              prefillWeight = lastWeighted.last.weight;
            }
          }
          return SetLog(
            setNumber: i + 1,
            plannedReps: repsInt,
            weight: prefillWeight,
          );
        }),
      );
    }).toList();

    final session = WorkoutSession(
      id: _repo.generateSessionId(),
      planId: planId,
      dayName: day.name,
      startedAt: DateTime.now(),
      exercises: exercises,
    );

    // Use the day's warm-up if defined, otherwise a sensible default so the
    // warm-up checklist is always shown during a workout.
    final warmup = day.warmup.isNotEmpty ? day.warmup : kDefaultWarmup;

    state = ActiveSessionState(
      session: session,
      warmup: warmup,
      warmupChecked: List.filled(warmup.length, false),
    );
    _save();
  }

  /// Log weight and reps for a specific set.
  void logSet({
    required int exerciseIndex,
    required int setIndex,
    required double weight,
    required int reps,
  }) {
    final s = state;
    if (s == null) return;

    final exercises = List<ExerciseLog>.from(s.session.exercises);
    final exercise = exercises[exerciseIndex];
    final sets = List<SetLog>.from(exercise.sets);

    sets[setIndex] = sets[setIndex].copyWith(
      weight: weight,
      actualReps: reps,
      completed: true,
    );
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);

    state = s.copyWith(
      session: s.session.copyWith(exercises: exercises),
    );
    _save();
  }

  /// Log duration for a timed exercise set.
  void logTimedSet({
    required int exerciseIndex,
    required int setIndex,
    required int durationSeconds,
  }) {
    final s = state;
    if (s == null) return;

    final exercises = List<ExerciseLog>.from(s.session.exercises);
    final exercise = exercises[exerciseIndex];
    final sets = List<SetLog>.from(exercise.sets);

    sets[setIndex] = sets[setIndex].copyWith(
      durationSeconds: durationSeconds,
      completed: true,
    );
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);

    state = s.copyWith(
      session: s.session.copyWith(exercises: exercises),
    );
    _save();
  }

  /// Log a bodyweight set (reps only, no weight).
  void logBodyweightSet({
    required int exerciseIndex,
    required int setIndex,
    required int reps,
  }) {
    logSet(
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
      weight: 0,
      reps: reps,
    );
  }

  /// Undo a completed set.
  void undoSet({required int exerciseIndex, required int setIndex}) {
    final s = state;
    if (s == null) return;

    final exercises = List<ExerciseLog>.from(s.session.exercises);
    final exercise = exercises[exerciseIndex];
    final sets = List<SetLog>.from(exercise.sets);

    sets[setIndex] = sets[setIndex].copyWith(completed: false);
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);

    state = s.copyWith(
      session: s.session.copyWith(exercises: exercises),
    );
    _save();
  }

  /// Skip an exercise.
  void skipExercise(int exerciseIndex) {
    final s = state;
    if (s == null) return;

    final exercises = List<ExerciseLog>.from(s.session.exercises);
    exercises[exerciseIndex] =
        exercises[exerciseIndex].copyWith(skipped: true);

    state = s.copyWith(
      session: s.session.copyWith(exercises: exercises),
    );
    _save();
  }

  /// Unskip a previously skipped exercise.
  void unskipExercise(int exerciseIndex) {
    final s = state;
    if (s == null) return;

    final exercises = List<ExerciseLog>.from(s.session.exercises);
    exercises[exerciseIndex] =
        exercises[exerciseIndex].copyWith(skipped: false);

    state = s.copyWith(
      session: s.session.copyWith(exercises: exercises),
    );
    _save();
  }

  /// Add a new set to an exercise (copies weight from last set).
  void addSet({required int exerciseIndex}) {
    final s = state;
    if (s == null) return;

    final exercises = List<ExerciseLog>.from(s.session.exercises);
    final exercise = exercises[exerciseIndex];
    final sets = List<SetLog>.from(exercise.sets);

    // Copy weight/reps from the previous set when one exists; otherwise start
    // a fresh set (handles exercises that ended up with zero sets).
    final lastSet = sets.isNotEmpty ? sets.last : null;
    sets.add(SetLog(
      setNumber: sets.length + 1,
      plannedReps: lastSet?.plannedReps ?? 10,
      weight: lastSet?.weight ?? 0,
    ));
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);

    state = s.copyWith(
      session: s.session.copyWith(exercises: exercises),
    );
    _save();
  }

  /// Remove a set from an exercise (minimum 1 set).
  void removeSet({required int exerciseIndex, required int setIndex}) {
    final s = state;
    if (s == null) return;

    final exercises = List<ExerciseLog>.from(s.session.exercises);
    final exercise = exercises[exerciseIndex];
    final sets = List<SetLog>.from(exercise.sets);

    if (sets.length <= 1) return;
    sets.removeAt(setIndex);
    // Renumber
    for (var i = 0; i < sets.length; i++) {
      sets[i] = sets[i].copyWith(setNumber: i + 1);
    }
    exercises[exerciseIndex] = exercise.copyWith(sets: sets);

    state = s.copyWith(
      session: s.session.copyWith(exercises: exercises),
    );
    _save();
  }

  /// Add a custom exercise to the current session.
  void addCustomExercise({
    required String name,
    required int sets,
    required int reps,
    String exerciseType = 'weighted',
  }) {
    final s = state;
    if (s == null) return;

    // Always create at least one set so the exercise is immediately usable
    // and the "+ Serie" control has a set to copy from.
    final setCount = sets < 1 ? 1 : sets;
    final repsValue = reps < 1 ? 10 : reps;
    final exercises = List<ExerciseLog>.from(s.session.exercises);
    exercises.add(ExerciseLog(
      exerciseId: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      exerciseName: name,
      exerciseType: exerciseType,
      sets: List.generate(
          setCount, (i) => SetLog(setNumber: i + 1, plannedReps: repsValue)),
    ));

    state = s.copyWith(
      session: s.session.copyWith(exercises: exercises),
    );
    _save();
  }

  /// Move to a specific exercise index.
  void goToExercise(int index) {
    final s = state;
    if (s == null) return;
    if (index < 0 || index >= s.session.exercises.length) return;
    state = s.copyWith(currentExerciseIndex: index);
  }

  /// Complete the workout session.
  void completeSession() {
    final s = state;
    if (s == null) return;

    // For a resumed session we keep the original duration (the user is just
    // correcting/adding to a past workout, not training again from the original
    // start time — recomputing now - startedAt would give absurd values like 60h).
    final elapsed = DateTime.now().difference(s.session.startedAt).inSeconds;
    // Defensive cap: a real gym session is never longer than ~4h. Anything
    // beyond means the user left the app open and forgot to finish, so we clamp
    // it instead of storing an absurd duration.
    const maxSessionSeconds = 4 * 60 * 60;
    final duration = s.resumed
        ? (s.session.durationSeconds ?? elapsed.clamp(0, maxSessionSeconds))
        : elapsed.clamp(0, maxSessionSeconds);
    state = s.copyWith(
      session: s.session.copyWith(
        completedAt: DateTime.now(),
        durationSeconds: duration,
      ),
      isCompleted: true,
    );
    _save();
  }

  /// Toggle a warmup item checkbox.
  void toggleWarmup(int index) {
    final s = state;
    if (s == null) return;
    if (index < 0 || index >= s.warmupChecked.length) return;

    final updated = List<bool>.from(s.warmupChecked);
    updated[index] = !updated[index];
    state = s.copyWith(warmupChecked: updated);
  }

  /// Set the three end-of-workout feedback metrics (each 1-5, 0 = not rated):
  /// overall quality, perceived fatigue, and pump sensation.
  void setRatings({
    required int overall,
    required int fatigue,
    required int pump,
  }) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
      session: s.session.copyWith(
        overallRating: overall.clamp(0, 5),
        fatigueRating: fatigue.clamp(0, 5),
        pumpRating: pump.clamp(0, 5),
      ),
    );
    _save();
  }

  /// Resume a previously saved session (e.g. finished by mistake) so it can be
  /// continued and completed. Keeps the same id, plan and start time; clears
  /// the completed flag and marks it unsynced so it re-syncs once finished.
  void resumeSession(WorkoutSession session) {
    final resumed = WorkoutSession(
      id: session.id,
      planId: session.planId,
      dayName: session.dayName,
      startedAt: session.startedAt,
      completedAt: null,
      // Keep the original duration so re-completing doesn't recompute an absurd
      // value from the original start time (see completeSession).
      durationSeconds: session.durationSeconds,
      exercises: session.exercises,
      notes: session.notes,
      synced: false,
      overallRating: session.overallRating,
      fatigueRating: session.fatigueRating,
      pumpRating: session.pumpRating,
    );
    state = ActiveSessionState(
      session: resumed,
      resumed: true,
      warmup: const [],
      warmupChecked: const [],
    );
    _save();
  }

  /// Close and discard the active session UI.
  void closeSession() {
    state = null;
  }

  Future<void> _save() async {
    final s = state;
    if (s == null) return;
    await _repo.saveSessionLocally(s.session);
  }
}

/// Provider for the active workout session.
final activeSessionProvider =
    NotifierProvider<ActiveSessionNotifier, ActiveSessionState?>(
        ActiveSessionNotifier.new);
