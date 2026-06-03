import 'package:fitness_ai/features/workout/domain/exercise_log.dart';

/// A workout session in progress or completed.
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.exercises,
    this.planId,
    this.dayName,
    this.completedAt,
    this.durationSeconds,
    this.notes = '',
    this.synced = false,
    this.overallRating = 0,
    this.fatigueRating = 0,
    this.pumpRating = 0,
  });

  final String id;
  final String? planId;
  final String? dayName;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final List<ExerciseLog> exercises;
  final String notes;
  final bool synced;

  /// Overall workout quality, 1-5 (0 = not rated).
  final int overallRating;

  /// Perceived fatigue, 1-5 (0 = not rated).
  final int fatigueRating;

  /// Pump sensation, 1-5 (0 = not rated).
  final int pumpRating;

  bool get isCompleted => completedAt != null;

  /// Total volume (weight * reps) across all exercises.
  double get totalVolume => exercises
      .where((e) => !e.skipped)
      .expand((e) => e.sets)
      .where((s) => s.completed)
      .fold(0.0, (sum, s) => sum + (s.weight * s.actualReps));

  /// Total completed sets across all exercises.
  int get totalCompletedSets => exercises
      .where((e) => !e.skipped)
      .expand((e) => e.sets)
      .where((s) => s.completed)
      .length;

  /// Number of completed exercises (all sets done or skipped).
  int get completedExercises => exercises.where((e) => e.isComplete).length;

  /// Session duration formatted as "Xh Xm" or "Xm".
  String get formattedDuration {
    final seconds =
        durationSeconds ?? completedAt?.difference(startedAt).inSeconds ?? 0;
    final minutes = seconds ~/ 60;
    if (minutes >= 60) {
      return '${minutes ~/ 60}h ${minutes % 60}m';
    }
    return '${minutes}m';
  }

  WorkoutSession copyWith({
    String? id,
    String? planId,
    String? dayName,
    DateTime? startedAt,
    DateTime? completedAt,
    int? durationSeconds,
    List<ExerciseLog>? exercises,
    String? notes,
    bool? synced,
    int? overallRating,
    int? fatigueRating,
    int? pumpRating,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      dayName: dayName ?? this.dayName,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      exercises: exercises ?? this.exercises,
      notes: notes ?? this.notes,
      synced: synced ?? this.synced,
      overallRating: overallRating ?? this.overallRating,
      fatigueRating: fatigueRating ?? this.fatigueRating,
      pumpRating: pumpRating ?? this.pumpRating,
    );
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'].toString(),
      planId: json['plan_id']?.toString(),
      dayName: json['day_name'] as String?,
      startedAt: json['started_at'] is DateTime
          ? json['started_at'] as DateTime
          : DateTime.parse(json['started_at'].toString()),
      completedAt: json['completed_at'] != null
          ? (json['completed_at'] is DateTime
              ? json['completed_at'] as DateTime
              : DateTime.parse(json['completed_at'].toString()))
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      exercises: ((json['exercises'] ?? []) as List)
          .map((e) => ExerciseLog.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      notes: (json['notes'] ?? '') as String,
      synced: (json['synced'] ?? false) as bool,
      // Backward compatible: old sessions stored a single `rating` (overall).
      overallRating:
          (json['overall_rating'] ?? json['rating'] ?? 0) as int,
      fatigueRating: (json['fatigue_rating'] ?? 0) as int,
      pumpRating: (json['pump_rating'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'plan_id': planId,
        'day_name': dayName,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'duration_seconds': durationSeconds,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'notes': notes,
        'synced': synced,
        'overall_rating': overallRating,
        'fatigue_rating': fatigueRating,
        'pump_rating': pumpRating,
      };
}
