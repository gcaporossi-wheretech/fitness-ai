import 'dart:convert';

import 'package:fitness_ai/core/network/api_client.dart';

/// Service for exporting user data in JSON and CSV formats.
/// Aggregates data from multiple API endpoints into a single export.
class ExportService {
  final ApiClient _api;

  ExportService(this._api);

  /// Export all user data as a structured JSON string.
  ///
  /// Fetches profile, workout plans, sessions, and AI credits,
  /// then serializes them into a single JSON document.
  Future<String> exportAsJson() async {
    final profile = await _api.get('/auth/me');
    final plans = await _api.get('/workouts/plans?per_page=100');
    final sessions = await _api.get('/workouts/sessions?per_page=500');

    final exportData = {
      'export_version': '1.0',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'profile': profile.data,
      'workout_plans': plans.data['items'] ?? [],
      'workout_sessions': sessions.data['items'] ?? [],
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(exportData);
  }

  /// Export workout sessions as CSV string.
  ///
  /// Columns: date, day_name, duration_minutes, exercise_count,
  /// total_sets, total_reps, total_volume_kg, notes
  Future<String> exportSessionsCsv() async {
    final sessions = await _api.get('/workouts/sessions?per_page=500');
    final items = sessions.data['items'] as List? ?? [];

    final buffer = StringBuffer();
    buffer.writeln(
      'date,day_name,duration_minutes,exercise_count,'
      'total_sets,total_reps,total_volume_kg,notes',
    );

    for (final session in items) {
      final startedAt = session['started_at'] ?? '';
      final dayName = _escapeCsv(session['day_name'] ?? '');
      final durationSec = session['duration_seconds'] ?? 0;
      final durationMin = (durationSec / 60).round();
      final exercises = session['exercises'] as List? ?? [];
      final exerciseCount = exercises.length;

      int totalSets = 0;
      int totalReps = 0;
      double totalVolume = 0;

      for (final ex in exercises) {
        final sets = ex['sets'] as List? ?? [];
        totalSets += sets.length;
        for (final s in sets) {
          final reps = (s['reps'] ?? 0) as num;
          final weight = (s['weight_kg'] ?? 0) as num;
          totalReps += reps.toInt();
          totalVolume += reps * weight;
        }
      }

      final notes = _escapeCsv(session['notes'] ?? '');
      buffer.writeln(
        '$startedAt,$dayName,$durationMin,$exerciseCount,'
        '$totalSets,$totalReps,${totalVolume.toStringAsFixed(1)},$notes',
      );
    }

    return buffer.toString();
  }

  /// Escape a CSV field value (wrap in quotes if contains comma/newline/quote).
  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('\n') || value.contains('"')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
