/// Exercise name -> muscle group (IT). Generated from the user's GymTracker
/// export so volume-by-group works even when stored muscle_group is empty.
library;

const Map<String, String> kExerciseMuscleGroup = {
  'Alzate laterali al cavo singolo': 'Spalle',
  'Alzate laterali con manubri': 'Spalle',
  'Calf Raise seduto': 'Polpacci',
  'Chest press alla macchina': 'Petto',
  'Croci ai cavi dal basso': 'Petto',
  'Croci su panca inclinata 30°': 'Petto',
  'Crunch alla corda cavo alto': 'Core',
  'Crunch bicicletta': 'Core',
  'Crunch su panca declinata': 'Core',
  'Curl al cavo basso con corda': 'Bicipiti',
  'Curl bilanciere EZ': 'Bicipiti',
  'Curl bilanciere in piedi': 'Bicipiti',
  'Curl concentrato con manubrio': 'Bicipiti',
  'Curl manubri su panca inclinata 45°': 'Bicipiti',
  'Dip su macchina assistita': 'Tricipiti',
  'Distensioni panca inclinata 30°': 'Petto',
  'Distensioni panca piana': 'Petto',
  'Estensioni sopra la testa al cavo': 'Tricipiti',
  'Face pull': 'Spalle',
  'Flessioni ginocchia appeso': 'Core',
  'French press con manubrio': 'Tricipiti',
  'Hip Thrust alla macchina': 'Glutei',
  'Lat pulldown presa stretta inversa': 'Dorso',
  'Leg Curl prono': 'Gambe',
  'Leg Curl prono leggero': 'Gambe',
  'Leg Extension': 'Gambe',
  'Leg Extension leggero': 'Gambe',
  'Leg Press': 'Gambe',
  'Lento avanti con manubri seduto': 'Spalle',
  'Plank': 'Core',
  'Pull-down braccio singolo al cavo': 'Dorso',
  'Pulley basso presa stretta triangolo': 'Dorso',
  'Push down al cavo barra dritta': 'Tricipiti',
  'Push down al cavo con corda': 'Tricipiti',
  'Rear delt fly alla macchina': 'Spalle',
  'Rematore con bilanciere busto flesso': 'Dorso',
  'Shrug con manubri': 'Trapezi',
  'Squat al Multipower': 'Gambe',
  'Stacco rumeno': 'Gambe',
  'Trazioni Lat Machine presa larga': 'Dorso',
  'Vacuum addominale': 'Core',
};

const Map<String, String> _itGroup = {
  'back': 'Dorso', 'chest': 'Petto', 'legs': 'Gambe', 'biceps': 'Bicipiti',
  'triceps': 'Tricipiti', 'shoulders': 'Spalle', 'core': 'Core',
  'traps': 'Trapezi', 'glutes': 'Glutei', 'calves': 'Polpacci',
  'abs': 'Core', 'cardio': 'Cardio',
};

/// Resolve the muscle group for an exercise: explicit map, then a stored
/// value, then keyword heuristics, then 'Altro'.
String muscleGroupForExercise(String name, [String stored = '']) {
  final exact = kExerciseMuscleGroup[name.trim()];
  if (exact != null) return exact;
  if (stored.isNotEmpty) return _itGroup[stored.toLowerCase()] ?? stored;
  final n = name.toLowerCase();
  bool has(List<String> ks) => ks.any(n.contains);
  if (has(['curl'])) return 'Bicipiti';
  if (has(['push down', 'pushdown', 'french', 'tricip', 'dip', 'estensioni'])) return 'Tricipiti';
  if (has(['panca', 'distensioni', 'croci', 'chest', 'pettoral'])) return 'Petto';
  if (has(['trazioni', 'lat ', 'lat machine', 'pulley', 'pulldown', 'pull-down', 'pull down', 'rematore', 'row'])) return 'Dorso';
  if (has(['shrug', 'scrollate', 'trapez'])) return 'Trapezi';
  if (has(['hip thrust', 'glute', 'ponte'])) return 'Glutei';
  if (has(['calf', 'polpacc'])) return 'Polpacci';
  if (has(['alzate', 'spalle', 'lento', 'shoulder', 'delt', 'military', 'face pull', 'arnold'])) return 'Spalle';
  if (has(['squat', 'leg ', 'pressa', 'leg press', 'affond', 'stacco', 'lunge', 'gambe'])) return 'Gambe';
  if (has(['crunch', 'plank', 'addomin', 'core', 'vacuum', 'bicicletta', 'appeso', 'sit up', 'sit-up'])) return 'Core';
  return 'Altro';
}
