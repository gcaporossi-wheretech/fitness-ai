import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/workout/domain/exercise_log.dart';
import 'package:fitness_ai/features/workout/domain/set_log.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

void main() {
  group('WorkoutSession rating', () {
    test('default rating is 0', () {
      final session = WorkoutSession(
        id: '1',
        startedAt: DateTime.now(),
        exercises: [],
      );
      expect(session.rating, 0);
    });

    test('copyWith updates rating', () {
      final session = WorkoutSession(
        id: '1',
        startedAt: DateTime.now(),
        exercises: [],
      );
      final rated = session.copyWith(rating: 4);
      expect(rated.rating, 4);
      expect(rated.id, '1'); // other fields preserved
    });

    test('fromJson reads rating', () {
      final json = {
        'id': '1',
        'started_at': '2026-04-07T10:00:00.000',
        'exercises': <dynamic>[],
        'rating': 5,
      };
      final session = WorkoutSession.fromJson(json);
      expect(session.rating, 5);
    });

    test('fromJson reads session_rating as fallback', () {
      final json = {
        'id': '1',
        'started_at': '2026-04-07T10:00:00.000',
        'exercises': <dynamic>[],
        'session_rating': 3,
      };
      final session = WorkoutSession.fromJson(json);
      expect(session.rating, 3);
    });

    test('fromJson defaults to 0 when rating missing', () {
      final json = {
        'id': '1',
        'started_at': '2026-04-07T10:00:00.000',
        'exercises': <dynamic>[],
      };
      final session = WorkoutSession.fromJson(json);
      expect(session.rating, 0);
    });

    test('toJson includes rating', () {
      final session = WorkoutSession(
        id: '1',
        startedAt: DateTime(2026, 4, 7, 10),
        exercises: [],
        rating: 4,
      );
      final json = session.toJson();
      expect(json['rating'], 4);
    });

    test('roundtrip preserves rating', () {
      final session = WorkoutSession(
        id: '1',
        startedAt: DateTime(2026, 4, 7, 10),
        exercises: [
          ExerciseLog(
            exerciseId: 'ex1',
            exerciseName: 'Bench Press',
            sets: [
              const SetLog(
                  setNumber: 1,
                  plannedReps: 10,
                  weight: 80,
                  actualReps: 10,
                  completed: true),
            ],
          ),
        ],
        rating: 5,
      );
      final json = session.toJson();
      final restored = WorkoutSession.fromJson(json);
      expect(restored.rating, 5);
      expect(restored.totalVolume, session.totalVolume);
    });
  });
}
