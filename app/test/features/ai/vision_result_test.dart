import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/ai/domain/vision_result.dart';

void main() {
  group('VisionResult', () {
    test('fromJson creates result with exercises', () {
      final json = {
        'equipment_name': 'Leg Press',
        'brand': 'Technogym',
        'confidence': 0.95,
        'cached': false,
        'exercises': [
          {
            'name': 'Leg Press',
            'muscle_group': 'quadriceps',
            'sets': 4,
            'reps': '12',
          },
          {
            'name': 'Calf Raise on Leg Press',
            'muscle_group': 'calves',
            'sets': 3,
            'reps': '15',
          },
        ],
      };
      final result = VisionResult.fromJson(json);
      expect(result.equipmentName, 'Leg Press');
      expect(result.brand, 'Technogym');
      expect(result.confidence, 0.95);
      expect(result.confidencePercent, '95%');
      expect(result.exercises.length, 2);
      expect(result.exercises[0].name, 'Leg Press');
      expect(result.exercises[1].muscleGroup, 'calves');
    });

    test('handles missing optional fields', () {
      final json = {
        'equipment_name': 'Unknown Machine',
        'confidence': 0.3,
      };
      final result = VisionResult.fromJson(json);
      expect(result.brand, isNull);
      expect(result.exercises, isEmpty);
      expect(result.cached, false);
      expect(result.confidencePercent, '30%');
    });

    test('toJson roundtrip preserves data', () {
      const result = VisionResult(
        equipmentName: 'Cable Machine',
        brand: 'Life Fitness',
        confidence: 0.88,
        exercises: [
          VisionExercise(
            name: 'Cable Fly',
            muscleGroup: 'chest',
            sets: 3,
            reps: '12',
          ),
        ],
      );
      final json = result.toJson();
      final restored = VisionResult.fromJson(json);
      expect(restored.equipmentName, 'Cable Machine');
      expect(restored.exercises.length, 1);
      expect(restored.exercises[0].name, 'Cable Fly');
    });
  });

  group('VisionExercise', () {
    test('default values are correct', () {
      const ex = VisionExercise(name: 'Test Exercise');
      expect(ex.sets, 3);
      expect(ex.reps, '10');
      expect(ex.muscleGroup, isNull);
    });

    test('fromJson handles exercise_name alias', () {
      final json = {
        'exercise_name': 'Lat Pulldown',
        'muscle_group': 'back',
        'sets': 4,
        'reps': '10',
        'description': 'Wide grip pulldown',
      };
      final ex = VisionExercise.fromJson(json);
      expect(ex.name, 'Lat Pulldown');
      expect(ex.description, 'Wide grip pulldown');
    });
  });
}
