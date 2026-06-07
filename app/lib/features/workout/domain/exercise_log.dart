import 'package:fitness_ai/features/workout/domain/set_log.dart';

/// A logged exercise within a workout session.
class ExerciseLog {
  const ExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    this.exerciseType = 'weighted',
    this.muscleGroup = '',
    this.restSeconds = 90,
    this.skipped = false,
    this.notes = '',
    this.supersetGroup,
  });

  final String exerciseId;
  final String exerciseName;
  final String exerciseType;
  final String muscleGroup;
  final int restSeconds;
  final List<SetLog> sets;
  final bool skipped;
  final String notes;

  /// Superset group id: consecutive exercises sharing a non-null value are
  /// performed back-to-back and shown grouped together.
  final String? supersetGroup;

  ExerciseLog copyWith({
    String? exerciseId,
    String? exerciseName,
    String? exerciseType,
    String? muscleGroup,
    int? restSeconds,
    List<SetLog>? sets,
    bool? skipped,
    String? notes,
    String? supersetGroup,
  }) {
    return ExerciseLog(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      exerciseType: exerciseType ?? this.exerciseType,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      restSeconds: restSeconds ?? this.restSeconds,
      sets: sets ?? this.sets,
      skipped: skipped ?? this.skipped,
      notes: notes ?? this.notes,
      supersetGroup: supersetGroup ?? this.supersetGroup,
    );
  }

  /// All sets completed (or exercise skipped).
  bool get isComplete =>
      skipped || (sets.isNotEmpty && sets.every((s) => s.completed));

  /// Number of completed sets.
  int get completedSetsCount => sets.where((s) => s.completed).length;

  factory ExerciseLog.fromJson(Map<String, dynamic> json) {
    return ExerciseLog(
      exerciseId: (json['exercise_id'] ?? json['exerciseId'] ?? '').toString(),
      exerciseName:
          (json['exercise_name'] ?? json['exerciseName'] ?? '') as String,
      exerciseType:
          (json['exercise_type'] ?? json['exerciseType'] ?? 'weighted')
              as String,
      muscleGroup:
          (json['muscle_group'] ?? json['muscleGroup'] ?? '') as String,
      restSeconds:
          (json['rest_seconds'] ?? json['restSeconds'] ?? 90) as int,
      sets: ((json['sets'] ?? []) as List)
          .map((s) => SetLog.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      skipped: (json['skipped'] ?? false) as bool,
      notes: (json['notes'] ?? '') as String,
      supersetGroup:
          (json['superset_group'] ?? json['supersetGroup']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'exercise_type': exerciseType,
        'muscle_group': muscleGroup,
        'rest_seconds': restSeconds,
        'sets': sets.map((s) => s.toJson()).toList(),
        'skipped': skipped,
        'notes': notes,
        'superset_group': supersetGroup,
      };

  /// API format for creating sessions.
  Map<String, dynamic> toApiJson() => {
        'exercise_id': exerciseId.isNotEmpty ? exerciseId : null,
        'exercise_name': exerciseName,
        'sets': sets
            .where((s) => s.completed)
            .map((s) => s.toApiJson())
            .toList(),
        'notes': notes.isNotEmpty ? notes : null,
      };
}
