import 'package:hive_flutter/hive_flutter.dart';

/// Initialize Hive for offline-first local storage.
/// Hive boxes store workout sessions, plans, and cached exercises
/// so the app works fully without network.
class HiveStorage {
  HiveStorage._();

  static const String sessionsBox = 'sessions';
  static const String plansBox = 'plans';
  static const String exercisesBox = 'exercises';
  static const String syncQueueBox = 'sync_queue';
  static const String userBox = 'user';

  /// Initialize Hive and open all required boxes.
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(sessionsBox),
      Hive.openBox<Map>(plansBox),
      Hive.openBox<Map>(exercisesBox),
      Hive.openBox<Map>(syncQueueBox),
      Hive.openBox<dynamic>(userBox),
    ]);
  }

  /// Get a typed box for direct access.
  static Box<Map> get sessions => Hive.box<Map>(sessionsBox);
  static Box<Map> get plans => Hive.box<Map>(plansBox);
  static Box<Map> get exercises => Hive.box<Map>(exercisesBox);
  static Box<Map> get syncQueue => Hive.box<Map>(syncQueueBox);
  static Box<dynamic> get user => Hive.box<dynamic>(userBox);

  /// Clear all local data on logout.
  static Future<void> clearAll() async {
    await Future.wait([
      sessions.clear(),
      plans.clear(),
      exercises.clear(),
      syncQueue.clear(),
      user.clear(),
    ]);
  }
}
