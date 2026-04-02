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
  });

  final WorkoutSession session;
  final int currentExerciseIndex;
  final bool isCompleted;

  ExerciseLog? get currentExercise {
    if (currentExerciseIndex >= session.exercises.length) return null;
    return session.exercises[currentExerciseIndex];
  }

  int get totalExercises => session.exercises.length;
  int get completedExercises => session.exercises
      .where((e) => e.skipped || e.sets.every((s) => s.completed))
      .length;

  ActiveSessionState copyWith({
    WorkoutSession? session,
    int? currentExerciseIndex,
    bool? isCompleted,
  }) {
    return ActiveSessionState(
      session: session ?? this.session,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Manages the active workout session state.
class ActiveSessionNotifier extends Notifier<ActiveSessionState?> {
  @override
  ActiveSessionState? build() => null;

  WorkoutRepository get _repo => ref.read(workoutRepositoryProvider);

  /// Start a new session from a workout day plan.
  void startSession(WorkoutDay day, {String? planId}) {
    final exercises = day.exercises.map((ep) {
      final repsInt = int.tryParse(ep.reps) ?? 10;
      return ExerciseLog(
        exerciseId: ep.exerciseId ?? '',
        exerciseName: ep.exerciseName,
        exerciseType: ep.exerciseType,
        restSeconds: ep.restSeconds,
        sets: List.generate(
          ep.sets,
          (i) => SetLog(setNumber: i + 1, plannedReps: repsInt),
        ),
      );
    }).toList();

    final session = WorkoutSession(
      id: _repo.generateSessionId(),
      planId: planId,
      dayName: day.name,
      startedAt: DateTime.now(),
      exercises: exercises,
    );

    state = ActiveSessionState(session: session);
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

    final lastSet = sets.last;
    sets.add(SetLog(
      setNumber: sets.length + 1,
      plannedReps: lastSet.plannedReps,
      weight: lastSet.weight,
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

    final exercises = List<ExerciseLog>.from(s.session.exercises);
    exercises.add(ExerciseLog(
      exerciseId: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      exerciseName: name,
      exerciseType: exerciseType,
      sets: List.generate(
          sets, (i) => SetLog(setNumber: i + 1, plannedReps: reps)),
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

    final duration = DateTime.now().difference(s.session.startedAt).inSeconds;
    state = s.copyWith(
      session: s.session.copyWith(
        completedAt: DateTime.now(),
        durationSeconds: duration,
      ),
      isCompleted: true,
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
