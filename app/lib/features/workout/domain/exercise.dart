/// Exercise reference data from the exercises catalog.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.nameEn,
    this.muscleGroups,
    this.equipment,
    this.exerciseType = 'weighted',
    this.description,
    this.descriptionEn,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String? nameEn;
  final List<String>? muscleGroups;
  final String? equipment;
  final String exerciseType; // weighted, timed, bodyweight
  final String? description;
  final String? descriptionEn;
  final bool isCustom;

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'].toString(),
      name: json['name'] as String,
      nameEn: json['name_en'] as String?,
      muscleGroups: (json['muscle_groups'] as List?)?.cast<String>(),
      equipment: json['equipment'] as String?,
      exerciseType: (json['exercise_type'] ?? 'weighted') as String,
      description: json['description'] as String?,
      descriptionEn: json['description_en'] as String?,
      isCustom: (json['is_custom'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'name_en': nameEn,
        'muscle_groups': muscleGroups,
        'equipment': equipment,
        'exercise_type': exerciseType,
        'description': description,
        'description_en': descriptionEn,
        'is_custom': isCustom,
      };
}
