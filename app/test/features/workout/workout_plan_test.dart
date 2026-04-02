import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/workout/domain/workout_plan.dart';

void main() {
  group('WorkoutPlan', () {
    test('fromJson creates plan with days', () {
      final json = {
        'id': 'plan-1',
        'name': 'Push Pull Legs',
        'description': 'A PPL split',
        'is_active': true,
        'source': 'manual',
        'days': [
          {
            'name': 'Push Day',
            'exercises': [
              {
                'exercise_name': 'Bench Press',
                'sets': 4,
                'reps': '8',
                'rest_seconds': 120,
              },
            ],
          },
        ],
      };
      final plan = WorkoutPlan.fromJson(json);
      expect(plan.name, 'Push Pull Legs');
      expect(plan.days.length, 1);
      expect(plan.days[0].name, 'Push Day');
      expect(plan.days[0].exercises.length, 1);
      expect(plan.days[0].exercises[0].exerciseName, 'Bench Press');
      expect(plan.days[0].exercises[0].sets, 4);
    });

    test('toJson roundtrip preserves data', () {
      const plan = WorkoutPlan(
        id: 'plan-1',
        name: 'Full Body',
        days: [
          WorkoutDay(
            name: 'Day A',
            exercises: [
              PlannedExercise(exerciseName: 'Squat', sets: 3, reps: '5'),
            ],
          ),
        ],
      );
      final json = plan.toJson();
      final restored = WorkoutPlan.fromJson(json);
      expect(restored.name, plan.name);
      expect(restored.days[0].exercises[0].exerciseName, 'Squat');
    });
  });

  group('PlannedExercise', () {
    test('default values are correct', () {
      const ex = PlannedExercise(exerciseName: 'Test');
      expect(ex.sets, 3);
      expect(ex.reps, '10');
      expect(ex.restSeconds, 90);
      expect(ex.exerciseType, 'weighted');
    });

    test('fromJson handles all fields', () {
      final json = {
        'exercise_id': 'ex-123',
        'exercise_name': 'Curl',
        'sets': 4,
        'reps': '12',
        'rest_seconds': 60,
        'exercise_type': 'weighted',
        'notes': 'Slow eccentric',
      };
      final ex = PlannedExercise.fromJson(json);
      expect(ex.exerciseId, 'ex-123');
      expect(ex.exerciseName, 'Curl');
      expect(ex.sets, 4);
      expect(ex.notes, 'Slow eccentric');
    });
  });
}
