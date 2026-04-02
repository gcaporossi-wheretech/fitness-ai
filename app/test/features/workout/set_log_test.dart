import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/workout/domain/set_log.dart';

void main() {
  group('SetLog', () {
    test('default values are correct', () {
      const set = SetLog(setNumber: 1, plannedReps: 10);
      expect(set.actualReps, 0);
      expect(set.weight, 0);
      expect(set.completed, false);
      expect(set.durationSeconds, 0);
    });

    test('copyWith updates specified fields', () {
      const set = SetLog(setNumber: 1, plannedReps: 10);
      final updated = set.copyWith(weight: 80, actualReps: 10, completed: true);
      expect(updated.weight, 80);
      expect(updated.actualReps, 10);
      expect(updated.completed, true);
      expect(updated.plannedReps, 10); // unchanged
    });

    test('fromJson creates correct set', () {
      final json = {
        'set_number': 2,
        'planned_reps': 8,
        'actual_reps': 8,
        'weight': 100.0,
        'completed': true,
      };
      final set = SetLog.fromJson(json);
      expect(set.setNumber, 2);
      expect(set.plannedReps, 8);
      expect(set.actualReps, 8);
      expect(set.weight, 100);
      expect(set.completed, true);
    });

    test('toJson roundtrip preserves data', () {
      const set = SetLog(
        setNumber: 1,
        plannedReps: 10,
        actualReps: 10,
        weight: 80,
        completed: true,
      );
      final json = set.toJson();
      final restored = SetLog.fromJson(json);
      expect(restored.setNumber, set.setNumber);
      expect(restored.weight, set.weight);
      expect(restored.completed, set.completed);
    });

    test('toApiJson uses weight_kg format', () {
      const set = SetLog(
        setNumber: 1,
        plannedReps: 10,
        actualReps: 8,
        weight: 60,
      );
      final api = set.toApiJson();
      expect(api['weight_kg'], 60);
      expect(api['reps'], 8);
      expect(api['set_number'], 1);
    });
  });
}
