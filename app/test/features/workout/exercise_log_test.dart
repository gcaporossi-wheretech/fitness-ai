import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/workout/domain/exercise_log.dart';
import 'package:fitness_ai/features/workout/domain/set_log.dart';

void main() {
  group('ExerciseLog', () {
    test('isComplete returns true when all sets completed', () {
      final exercise = ExerciseLog(
        exerciseId: 'ex1',
        exerciseName: 'Bench Press',
        sets: [
          const SetLog(setNumber: 1, plannedReps: 10, completed: true),
          const SetLog(setNumber: 2, plannedReps: 10, completed: true),
        ],
      );
      expect(exercise.isComplete, true);
    });

    test('isComplete returns false when sets incomplete', () {
      final exercise = ExerciseLog(
        exerciseId: 'ex1',
        exerciseName: 'Bench Press',
        sets: [
          const SetLog(setNumber: 1, plannedReps: 10, completed: true),
          const SetLog(setNumber: 2, plannedReps: 10, completed: false),
        ],
      );
      expect(exercise.isComplete, false);
    });

    test('isComplete returns true when skipped', () {
      final exercise = ExerciseLog(
        exerciseId: 'ex1',
        exerciseName: 'Bench Press',
        skipped: true,
        sets: [
          const SetLog(setNumber: 1, plannedReps: 10, completed: false),
        ],
      );
      expect(exercise.isComplete, true);
    });

    test('completedSetsCount counts only completed sets', () {
      final exercise = ExerciseLog(
        exerciseId: 'ex1',
        exerciseName: 'Squat',
        sets: [
          const SetLog(setNumber: 1, plannedReps: 10, completed: true),
          const SetLog(setNumber: 2, plannedReps: 10, completed: true),
          const SetLog(setNumber: 3, plannedReps: 10, completed: false),
        ],
      );
      expect(exercise.completedSetsCount, 2);
    });

    test('fromJson creates correct exercise', () {
      final json = {
        'exercise_id': 'ex1',
        'exercise_name': 'Deadlift',
        'exercise_type': 'weighted',
        'rest_seconds': 120,
        'sets': [
          {'set_number': 1, 'planned_reps': 5, 'weight': 140.0, 'completed': true},
        ],
      };
      final exercise = ExerciseLog.fromJson(json);
      expect(exercise.exerciseName, 'Deadlift');
      expect(exercise.restSeconds, 120);
      expect(exercise.sets.length, 1);
      expect(exercise.sets[0].weight, 140);
    });

    test('toApiJson excludes incomplete sets', () {
      final exercise = ExerciseLog(
        exerciseId: 'ex1',
        exerciseName: 'Row',
        sets: [
          const SetLog(setNumber: 1, plannedReps: 10, weight: 60, actualReps: 10, completed: true),
          const SetLog(setNumber: 2, plannedReps: 10, completed: false),
        ],
      );
      final api = exercise.toApiJson();
      final sets = api['sets'] as List;
      expect(sets.length, 1); // Only completed set
    });
  });
}
