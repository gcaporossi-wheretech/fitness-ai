import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/ai/domain/coach_result.dart';

void main() {
  group('CoachResult', () {
    test('fromJson creates result with days', () {
      final json = {
        'plan_name': 'Push Pull Legs',
        'description': 'A balanced 4-day split',
        'days': [
          {
            'name': 'Push Day',
            'exercises': [
              {'exercise_name': 'Bench Press', 'sets': 4, 'reps': '8'},
              {'exercise_name': 'OHP', 'sets': 3, 'reps': '10'},
            ],
          },
          {
            'name': 'Pull Day',
            'exercises': [
              {'exercise_name': 'Deadlift', 'sets': 3, 'reps': '5'},
            ],
          },
        ],
        'notes': 'Increase weight weekly',
      };
      final result = CoachResult.fromJson(json);
      expect(result.planName, 'Push Pull Legs');
      expect(result.description, 'A balanced 4-day split');
      expect(result.days.length, 2);
      expect(result.days[0].name, 'Push Day');
      expect(result.days[0].exercises.length, 2);
      expect(result.notes, 'Increase weight weekly');
    });

    test('toJson roundtrip preserves data', () {
      final json = {
        'plan_name': 'Full Body',
        'description': '3x week',
        'days': [
          {
            'name': 'Day A',
            'exercises': [
              {'exercise_name': 'Squat', 'sets': 3, 'reps': '5'},
            ],
          },
        ],
      };
      final result = CoachResult.fromJson(json);
      final output = result.toJson();
      final restored = CoachResult.fromJson(output);
      expect(restored.planName, result.planName);
      expect(restored.days.length, 1);
    });

    test('handles missing optional fields', () {
      final json = {
        'plan_name': 'Basic Plan',
        'description': 'Simple',
        'days': [],
      };
      final result = CoachResult.fromJson(json);
      expect(result.notes, isNull);
      expect(result.days, isEmpty);
    });
  });
}
