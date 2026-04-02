/// A single set logged during a workout exercise.
class SetLog {
  const SetLog({
    required this.setNumber,
    required this.plannedReps,
    this.actualReps = 0,
    this.weight = 0,
    this.rpe = 0,
    this.durationSeconds = 0,
    this.completed = false,
    this.notes = '',
  });

  final int setNumber;
  final int plannedReps;
  final int actualReps;
  final double weight;
  final double rpe;
  final int durationSeconds;
  final bool completed;
  final String notes;

  SetLog copyWith({
    int? setNumber,
    int? plannedReps,
    int? actualReps,
    double? weight,
    double? rpe,
    int? durationSeconds,
    bool? completed,
    String? notes,
  }) {
    return SetLog(
      setNumber: setNumber ?? this.setNumber,
      plannedReps: plannedReps ?? this.plannedReps,
      actualReps: actualReps ?? this.actualReps,
      weight: weight ?? this.weight,
      rpe: rpe ?? this.rpe,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
    );
  }

  factory SetLog.fromJson(Map<String, dynamic> json) {
    return SetLog(
      setNumber: (json['set_number'] ?? json['setNumber'] ?? 1) as int,
      plannedReps: (json['planned_reps'] ?? json['plannedReps'] ?? 0) as int,
      actualReps: (json['actual_reps'] ?? json['actualReps'] ?? 0) as int,
      weight: (json['weight'] ?? json['weight_kg'] ?? 0).toDouble(),
      rpe: (json['rpe'] ?? 0).toDouble(),
      durationSeconds:
          (json['duration_seconds'] ?? json['durationSeconds'] ?? 0) as int,
      completed: (json['completed'] ?? false) as bool,
      notes: (json['notes'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'set_number': setNumber,
        'planned_reps': plannedReps,
        'actual_reps': actualReps,
        'weight': weight,
        'rpe': rpe,
        'duration_seconds': durationSeconds,
        'completed': completed,
        'notes': notes,
      };

  /// API format for creating sessions.
  Map<String, dynamic> toApiJson() => {
        'set_number': setNumber,
        'weight_kg': weight > 0 ? weight : null,
        'reps': actualReps > 0 ? actualReps : null,
        'duration_seconds': durationSeconds > 0 ? durationSeconds : null,
        'rpe': rpe > 0 ? rpe : null,
      };
}
