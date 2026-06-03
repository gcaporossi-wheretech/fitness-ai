import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';
import 'package:fitness_ai/features/workout/domain/workout_plan.dart';

void main() {
  group('Hive-style deserialization (Map<dynamic,dynamic>)', () {
    // After a page reload, Hive returns nested maps as Map<dynamic,dynamic>
    // (not Map<String,dynamic>). Parsing must not throw on these, otherwise
    // the History/Stats screens and session start crash (blank screens).

    test('WorkoutSession.fromJson handles nested Map<dynamic,dynamic>', () {
      final Map<dynamic, dynamic> hive = <dynamic, dynamic>{
        'id': 's1',
        'started_at': '2026-06-01T10:00:00.000',
        'completed_at': '2026-06-01T11:00:00.000',
        'exercises': <dynamic>[
          <dynamic, dynamic>{
            'exercise_name': 'Panca',
            'sets': <dynamic>[
              <dynamic, dynamic>{
                'set_number': 1,
                'weight': 60,
                'actual_reps': 10,
                'completed': true,
              },
            ],
          },
        ],
        'rating': 4,
      };

      final s = WorkoutSession.fromJson(Map<String, dynamic>.from(hive));
      expect(s.exercises.length, 1);
      expect(s.exercises.first.sets.first.weight, 60);
      expect(s.exercises.first.sets.first.actualReps, 10);
      expect(s.totalCompletedSets, 1);
      expect(s.overallRating, 4); // legacy 'rating' maps to overall
    });

    test('WorkoutPlan.fromJson handles nested Map<dynamic,dynamic>', () {
      final Map<dynamic, dynamic> hive = <dynamic, dynamic>{
        'id': 'p1',
        'name': 'Scheda',
        'days': <dynamic>[
          <dynamic, dynamic>{
            'name': 'Push',
            'warmup': <dynamic>['5 min cardio'],
            'exercises': <dynamic>[
              <dynamic, dynamic>{
                'exercise_name': 'Panca',
                'sets': 4,
                'reps': '8',
                'rest_seconds': 120,
              },
            ],
          },
        ],
      };

      final p = WorkoutPlan.fromJson(Map<String, dynamic>.from(hive));
      expect(p.days.length, 1);
      expect(p.days.first.exercises.first.exerciseName, 'Panca');
      expect(p.days.first.exercises.first.sets, 4);
      expect(p.days.first.warmup, ['5 min cardio']);
    });
  });
}
