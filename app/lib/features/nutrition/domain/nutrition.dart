import 'package:fitness_ai/core/storage/hive_storage.dart';

/// Activity multipliers (Harris/Mifflin TDEE) and goal calorie adjustments.
const Map<String, double> kActivityFactors = {
  'sedentario': 1.2,
  'leggero': 1.375,
  'moderato': 1.55,
  'attivo': 1.725,
};

const Map<String, double> kGoalFactors = {
  'dimagrimento': 0.80,
  'ricomposizione': 0.90,
  'mantenimento': 1.0,
  'massa': 1.10,
};

const Map<String, String> kActivityLabels = {
  'sedentario': 'Sedentario',
  'leggero': 'Leggero',
  'moderato': 'Moderato (lavoro sedentario + 4-5 allenamenti)',
  'attivo': 'Molto attivo',
};

const Map<String, String> kGoalLabels = {
  'dimagrimento': 'Dimagrimento',
  'ricomposizione': 'Ricomposizione (muscolo + meno grasso)',
  'mantenimento': 'Mantenimento',
  'massa': 'Aumento massa',
};

/// User inputs that drive the nutrition targets. Persisted locally (Hive).
class NutritionInputs {
  const NutritionInputs({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    this.male = true,
    this.activity = 'moderato',
    this.goal = 'ricomposizione',
  });

  final double weightKg;
  final double heightCm;
  final int age;
  final bool male;
  final String activity;
  final String goal;

  /// Sensible default (the owner's stats) so the screen is useful on first open.
  static const NutritionInputs fallback = NutritionInputs(
    weightKg: 74,
    heightCm: 175,
    age: 57,
  );

  static const String _key = 'nutrition_profile';

  NutritionInputs copyWith({
    double? weightKg,
    double? heightCm,
    int? age,
    bool? male,
    String? activity,
    String? goal,
  }) {
    return NutritionInputs(
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      male: male ?? this.male,
      activity: activity ?? this.activity,
      goal: goal ?? this.goal,
    );
  }

  Map<String, dynamic> toJson() => {
        'weight': weightKg,
        'height': heightCm,
        'age': age,
        'male': male,
        'activity': activity,
        'goal': goal,
      };

  factory NutritionInputs.fromJson(Map<String, dynamic> j) => NutritionInputs(
        weightKg: (j['weight'] ?? 74).toDouble(),
        heightCm: (j['height'] ?? 175).toDouble(),
        age: (j['age'] ?? 57) as int,
        male: (j['male'] ?? true) as bool,
        activity: (j['activity'] ?? 'moderato') as String,
        goal: (j['goal'] ?? 'ricomposizione') as String,
      );

  /// Load persisted inputs, or the default stats on first use.
  static NutritionInputs load() {
    final data = HiveStorage.user.get(_key);
    if (data == null) return fallback;
    return NutritionInputs.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> save() => HiveStorage.user.put(_key, toJson());
}

/// Daily calorie + macro targets.
class MacroTargets {
  const MacroTargets({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.maintenanceKcal,
  });

  final int kcal;
  final int protein; // grams
  final int carbs; // grams
  final int fat; // grams
  final int maintenanceKcal;
}

/// Compute targets via Mifflin-St Jeor BMR → TDEE → goal adjustment.
/// Protein is set per kg of bodyweight (higher when cutting/recomposing to
/// protect muscle, important past 50). Fat ~0.9 g/kg, carbs fill the rest.
MacroTargets computeTargets(NutritionInputs i) {
  final bmr =
      10 * i.weightKg + 6.25 * i.heightCm - 5 * i.age + (i.male ? 5 : -161);
  final maintenance = bmr * (kActivityFactors[i.activity] ?? 1.55);
  final kcal = maintenance * (kGoalFactors[i.goal] ?? 0.90);

  final proteinPerKg = i.goal == 'massa' ? 1.8 : 2.0;
  final protein = i.weightKg * proteinPerKg;
  final fat = i.weightKg * 0.9;
  final remaining = kcal - protein * 4 - fat * 9;
  final carbs = (remaining > 0 ? remaining : 0) / 4;

  return MacroTargets(
    kcal: kcal.round(),
    protein: protein.round(),
    carbs: carbs.round(),
    fat: fat.round(),
    maintenanceKcal: maintenance.round(),
  );
}
