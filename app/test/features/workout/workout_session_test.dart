import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/workout/domain/exercise_log.dart';
import 'package:fitness_ai/features/workout/domain/set_log.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

void main() {
  group('WorkoutSession', () {
    WorkoutSession createSession() {
      return WorkoutSession(
        id: 'session-1',
        startedAt: DateTime(2026, 4, 2, 10, 0),
        completedAt: DateTime(2026, 4, 2, 11, 15),
        durationSeconds: 4500,
        exercises: [
          ExerciseLog(
            exerciseId: 'ex1',
            exerciseName: 'Bench Press',
            sets: [
              const SetLog(setNumber: 1, plannedReps: 10, weight: 80, actualReps: 10, completed: true),
              const SetLog(setNumber: 2, plannedReps: 10, weight: 80, actualReps: 8, completed: true),
            ],
          ),
          ExerciseLog(
            exerciseId: 'ex2',
            exerciseName: 'Rows',
            sets: [
              const SetLog(setNumber: 1, plannedReps: 10, weight: 60, actualReps: 10, completed: true),
            ],
          ),
        ],
      );
    }

    test('totalVolume calculates correctly', () {
      final session = createSession();
      // (80*10) + (80*8) + (60*10) = 800 + 640 + 600 = 2040
      expect(session.totalVolume, 2040);
    });

    test('totalCompletedSets counts all completed sets', () {
      final session = createSession();
      expect(session.totalCompletedSets, 3);
    });

    test('completedExercises counts exercises with all sets done', () {
      final session = createSession();
      expect(session.completedExercises, 2);
    });

    test('formattedDuration formats correctly', () {
      final session = createSession();
      expect(session.formattedDuration, '1h 15m');
    });

    test('formattedDuration shows minutes only for short sessions', () {
      final session = WorkoutSession(
        id: 'session-2',
        startedAt: DateTime(2026, 4, 2, 10, 0),
        durationSeconds: 2400,
        exercises: [],
      );
      expect(session.formattedDuration, '40m');
    });

    test('isCompleted returns true when completedAt is set', () {
      final session = createSession();
      expect(session.isCompleted, true);
    });

    test('isCompleted returns false when completedAt is null', () {
      final session = WorkoutSession(
        id: 'session-3',
        startedAt: DateTime.now(),
        exercises: [],
      );
      expect(session.isCompleted, false);
    });

    test('fromJson roundtrip preserves data', () {
      final session = createSession();
      final json = session.toJson();
      final restored = WorkoutSession.fromJson(json);
      expect(restored.id, session.id);
      expect(restored.exercises.length, 2);
      expect(restored.exercises[0].exerciseName, 'Bench Press');
      expect(restored.totalVolume, session.totalVolume);
    });

    test('skipped exercises excluded from volume', () {
      final session = WorkoutSession(
        id: 'session-4',
        startedAt: DateTime.now(),
        exercises: [
          ExerciseLog(
            exerciseId: 'ex1',
            exerciseName: 'Bench Press',
            sets: [
              const SetLog(setNumber: 1, plannedReps: 10, weight: 80, actualReps: 10, completed: true),
            ],
          ),
          ExerciseLog(
            exerciseId: 'ex2',
            exerciseName: 'Rows',
            skipped: true,
            sets: [
              const SetLog(setNumber: 1, plannedReps: 10, weight: 60, actualReps: 10, completed: true),
            ],
          ),
        ],
      );
      expect(session.totalVolume, 800); // Only bench press
    });
  });
}
