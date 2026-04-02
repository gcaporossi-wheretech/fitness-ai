/// A workout plan with days and exercises.
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.days,
    this.description,
    this.isActive = true,
    this.source = 'manual',
    this.phases,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final List<WorkoutDay> days;
  final bool isActive;
  final String source;
  final List<Map<String, dynamic>>? phases;
  final DateTime? createdAt;

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'].toString(),
      name: json['name'] as String,
      description: json['description'] as String?,
      days: ((json['days'] ?? []) as List)
          .map((d) => WorkoutDay.fromJson(d as Map<String, dynamic>))
          .toList(),
      isActive: (json['is_active'] ?? true) as bool,
      source: (json['source'] ?? 'manual') as String,
      phases: (json['phases'] as List?)
          ?.map((p) => p as Map<String, dynamic>)
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'days': days.map((d) => d.toJson()).toList(),
        'is_active': isActive,
        'source': source,
        'phases': phases,
        'created_at': createdAt?.toIso8601String(),
      };
}

/// A single day within a workout plan.
class WorkoutDay {
  const WorkoutDay({
    required this.name,
    required this.exercises,
  });

  final String name;
  final List<PlannedExercise> exercises;

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      name: json['name'] as String,
      exercises: ((json['exercises'] ?? []) as List)
          .map((e) => PlannedExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}

/// An exercise entry in a workout plan day.
class PlannedExercise {
  const PlannedExercise({
    required this.exerciseName,
    this.exerciseId,
    this.sets = 3,
    this.reps = '10',
    this.restSeconds = 90,
    this.exerciseType = 'weighted',
    this.notes,
  });

  final String? exerciseId;
  final String exerciseName;
  final int sets;
  final String reps;
  final int restSeconds;
  final String exerciseType;
  final String? notes;

  factory PlannedExercise.fromJson(Map<String, dynamic> json) {
    return PlannedExercise(
      exerciseId: json['exercise_id']?.toString(),
      exerciseName: (json['exercise_name'] ?? json['name'] ?? '') as String,
      sets: (json['sets'] ?? 3) as int,
      reps: (json['reps'] ?? '10').toString(),
      restSeconds: (json['rest_seconds'] ?? 90) as int,
      exerciseType: (json['exercise_type'] ?? 'weighted') as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'exercise_name': exerciseName,
        'sets': sets,
        'reps': reps,
        'rest_seconds': restSeconds,
        'exercise_type': exerciseType,
        'notes': notes,
      };
}
