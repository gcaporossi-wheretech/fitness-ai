import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

void main() {
  group('WorkoutSession formattedDuration', () {
    test('formats hours and minutes', () {
      final session = WorkoutSession(
        id: '1',
        startedAt: DateTime(2026, 4, 7, 10, 0),
        completedAt: DateTime(2026, 4, 7, 12, 15),
        durationSeconds: 8100, // 2h 15m
        exercises: [],
      );
      expect(session.formattedDuration, '2h 15m');
    });

    test('formats minutes only for short sessions', () {
      final session = WorkoutSession(
        id: '2',
        startedAt: DateTime(2026, 4, 7, 10, 0),
        durationSeconds: 2700, // 45m
        exercises: [],
      );
      expect(session.formattedDuration, '45m');
    });

    test('formats zero duration', () {
      final session = WorkoutSession(
        id: '3',
        startedAt: DateTime(2026, 4, 7, 10, 0),
        durationSeconds: 0,
        exercises: [],
      );
      expect(session.formattedDuration, '0m');
    });

    test('formats exactly one hour', () {
      final session = WorkoutSession(
        id: '4',
        startedAt: DateTime(2026, 4, 7, 10, 0),
        durationSeconds: 3600,
        exercises: [],
      );
      expect(session.formattedDuration, '1h 0m');
    });

    test('uses completedAt when durationSeconds is null', () {
      final session = WorkoutSession(
        id: '5',
        startedAt: DateTime(2026, 4, 7, 10, 0),
        completedAt: DateTime(2026, 4, 7, 10, 30),
        exercises: [],
      );
      expect(session.formattedDuration, '30m');
    });

    test('returns 0m when no completedAt and no durationSeconds', () {
      final session = WorkoutSession(
        id: '6',
        startedAt: DateTime(2026, 4, 7, 10, 0),
        exercises: [],
      );
      expect(session.formattedDuration, '0m');
    });
  });
}
