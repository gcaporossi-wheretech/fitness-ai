import 'package:fitness_ai/features/workout/domain/workout_plan.dart';

/// Result from the AI Coach generation endpoint.
class CoachResult {
  const CoachResult({
    required this.planName,
    required this.description,
    required this.days,
    this.notes,
  });

  final String planName;
  final String description;
  final List<WorkoutDay> days;
  final String? notes;

  factory CoachResult.fromJson(Map<String, dynamic> json) {
    return CoachResult(
      planName: (json['plan_name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      days: ((json['days'] ?? []) as List)
          .map((d) => WorkoutDay.fromJson(d as Map<String, dynamic>))
          .toList(),
      notes: (json['notes'] ?? json['progression_notes']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'plan_name': planName,
        'description': description,
        'days': days.map((d) => d.toJson()).toList(),
        'notes': notes,
      };
}
