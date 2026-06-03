import 'package:fitness_ai/features/workout/domain/workout_plan.dart';

/// Result from the AI Coach generation endpoint.
class CoachResult {
  const CoachResult({
    required this.planName,
    required this.description,
    required this.days,
    this.notes,
    this.assessment,
    this.photoReviewWeeks,
  });

  final String planName;
  final String description;
  final List<WorkoutDay> days;
  final String? notes;

  /// AI assessment of the current situation/objective from the body photos.
  final String? assessment;

  /// Suggested number of weeks before re-taking progress photos.
  final int? photoReviewWeeks;

  factory CoachResult.fromJson(Map<String, dynamic> json) {
    return CoachResult(
      planName: (json['plan_name'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      days: ((json['days'] ?? []) as List)
          .map((d) => WorkoutDay.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
      notes: (json['notes'] ?? json['progression_notes']) as String?,
      assessment: (json['assessment'] ?? json['current_situation']) as String?,
      photoReviewWeeks: (json['photo_review_weeks'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'plan_name': planName,
        'description': description,
        'days': days.map((d) => d.toJson()).toList(),
        'notes': notes,
      };
}
