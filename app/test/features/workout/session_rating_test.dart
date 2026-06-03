import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/workout/domain/exercise_log.dart';
import 'package:fitness_ai/features/workout/domain/set_log.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

void main() {
  group('WorkoutSession ratings', () {
    test('default ratings are 0', () {
      final session = WorkoutSession(
        id: '1',
        startedAt: DateTime.now(),
        exercises: [],
      );
      expect(session.overallRating, 0);
      expect(session.fatigueRating, 0);
      expect(session.pumpRating, 0);
    });

    test('copyWith updates the three ratings', () {
      final session = WorkoutSession(
        id: '1',
        startedAt: DateTime.now(),
        exercises: [],
      );
      final rated =
          session.copyWith(overallRating: 4, fatigueRating: 3, pumpRating: 5);
      expect(rated.overallRating, 4);
      expect(rated.fatigueRating, 3);
      expect(rated.pumpRating, 5);
      expect(rated.id, '1'); // other fields preserved
    });

    test('fromJson reads the three ratings', () {
      final json = {
        'id': '1',
        'started_at': '2026-04-07T10:00:00.000',
        'exercises': <dynamic>[],
        'overall_rating': 5,
        'fatigue_rating': 2,
        'pump_rating': 4,
      };
      final session = WorkoutSession.fromJson(json);
      expect(session.overallRating, 5);
      expect(session.fatigueRating, 2);
      expect(session.pumpRating, 4);
    });

    test('fromJson reads legacy rating as overall fallback', () {
      final json = {
        'id': '1',
        'started_at': '2026-04-07T10:00:00.000',
        'exercises': <dynamic>[],
        'rating': 3,
      };
      final session = WorkoutSession.fromJson(json);
      expect(session.overallRating, 3);
      expect(session.fatigueRating, 0);
      expect(session.pumpRating, 0);
    });

    test('fromJson defaults to 0 when ratings missing', () {
      final json = {
        'id': '1',
        'started_at': '2026-04-07T10:00:00.000',
        'exercises': <dynamic>[],
      };
      final session = WorkoutSession.fromJson(json);
      expect(session.overallRating, 0);
      expect(session.fatigueRating, 0);
      expect(session.pumpRating, 0);
    });

    test('toJson includes the three ratings', () {
      final session = WorkoutSession(
        id: '1',
        startedAt: DateTime(2026, 4, 7, 10),
        exercises: [],
        overallRating: 4,
        fatigueRating: 3,
        pumpRating: 2,
      );
      final json = session.toJson();
      expect(json['overall_rating'], 4);
      expect(json['fatigue_rating'], 3);
      expect(json['pump_rating'], 2);
    });

    test('roundtrip preserves ratings', () {
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
        overallRating: 5,
        fatigueRating: 4,
        pumpRating: 3,
      );
      final json = session.toJson();
      final restored = WorkoutSession.fromJson(json);
      expect(restored.overallRating, 5);
      expect(restored.fatigueRating, 4);
      expect(restored.pumpRating, 3);
      expect(restored.totalVolume, session.totalVolume);
    });
  });
}
