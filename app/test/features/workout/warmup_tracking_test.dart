import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/workout/domain/workout_plan.dart';
import 'package:fitness_ai/features/workout/presentation/active_session_notifier.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

void main() {
  group('WorkoutDay warmup', () {
    test('default warmup is empty list', () {
      const day = WorkoutDay(name: 'Push Day', exercises: []);
      expect(day.warmup, isEmpty);
    });

    test('warmup from JSON', () {
      final json = {
        'name': 'Push Day',
        'exercises': <dynamic>[],
        'warmup': ['5 min treadmill', 'Dynamic stretching'],
      };
      final day = WorkoutDay.fromJson(json);
      expect(day.warmup, hasLength(2));
      expect(day.warmup[0], '5 min treadmill');
    });

    test('warmup to JSON roundtrip', () {
      const day = WorkoutDay(
        name: 'Pull Day',
        exercises: [],
        warmup: ['Foam rolling', 'Band pull-aparts'],
      );
      final json = day.toJson();
      final restored = WorkoutDay.fromJson(json);
      expect(restored.warmup, hasLength(2));
      expect(restored.warmup[1], 'Band pull-aparts');
    });

    test('copyWith updates warmup', () {
      const day = WorkoutDay(
        name: 'Legs',
        exercises: [],
        warmup: ['Mobility'],
      );
      final updated = day.copyWith(warmup: ['Mobility', 'Light squats']);
      expect(updated.warmup, hasLength(2));
      expect(updated.name, 'Legs');
    });
  });

  group('ActiveSessionState warmup', () {
    test('warmupChecked defaults to empty', () {
      final state = ActiveSessionState(
        session: WorkoutSession(
          id: '1',
          startedAt: DateTime.now(),
          exercises: [],
        ),
      );
      expect(state.warmupChecked, isEmpty);
      expect(state.warmupAllDone, false);
      expect(state.warmupDoneCount, 0);
    });

    test('warmupAllDone when all checked', () {
      final state = ActiveSessionState(
        session: WorkoutSession(
          id: '1',
          startedAt: DateTime.now(),
          exercises: [],
        ),
        warmupChecked: [true, true, true],
      );
      expect(state.warmupAllDone, true);
      expect(state.warmupDoneCount, 3);
    });

    test('warmupAllDone false when partially checked', () {
      final state = ActiveSessionState(
        session: WorkoutSession(
          id: '1',
          startedAt: DateTime.now(),
          exercises: [],
        ),
        warmupChecked: [true, false, true],
      );
      expect(state.warmupAllDone, false);
      expect(state.warmupDoneCount, 2);
    });

    test('copyWith updates warmupChecked', () {
      final state = ActiveSessionState(
        session: WorkoutSession(
          id: '1',
          startedAt: DateTime.now(),
          exercises: [],
        ),
        warmupChecked: [false, false],
      );
      final updated = state.copyWith(warmupChecked: [true, false]);
      expect(updated.warmupChecked[0], true);
      expect(updated.warmupChecked[1], false);
    });
  });
}
