/// Result from the AI Vision scan endpoint.
/// Contains identified equipment and suggested exercises.
class VisionResult {
  const VisionResult({
    required this.equipmentName,
    this.brand,
    this.exercises = const [],
    this.confidence = 0,
    this.cached = false,
  });

  final String equipmentName;
  final String? brand;
  final List<VisionExercise> exercises;
  final double confidence;
  final bool cached;

  factory VisionResult.fromJson(Map<String, dynamic> json) {
    return VisionResult(
      equipmentName: (json['equipment_name'] ?? '') as String,
      brand: json['brand'] as String?,
      exercises: ((json['exercises'] ?? []) as List)
          .map((e) => VisionExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      confidence: (json['confidence'] ?? 0).toDouble(),
      cached: (json['cached'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'equipment_name': equipmentName,
        'brand': brand,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'confidence': confidence,
        'cached': cached,
      };

  /// Confidence as a percentage string.
  String get confidencePercent => '${(confidence * 100).round()}%';
}

/// A suggested exercise from vision scan.
class VisionExercise {
  const VisionExercise({
    required this.name,
    this.muscleGroup,
    this.sets = 3,
    this.reps = '10',
    this.description,
  });

  final String name;
  final String? muscleGroup;
  final int sets;
  final String reps;
  final String? description;

  factory VisionExercise.fromJson(Map<String, dynamic> json) {
    return VisionExercise(
      name: (json['name'] ?? json['exercise_name'] ?? '') as String,
      muscleGroup: json['muscle_group'] as String?,
      sets: (json['sets'] ?? 3) as int,
      reps: (json['reps'] ?? '10').toString(),
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'muscle_group': muscleGroup,
        'sets': sets,
        'reps': reps,
        'description': description,
      };
}
