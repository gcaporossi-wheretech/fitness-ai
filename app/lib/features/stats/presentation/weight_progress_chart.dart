import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

/// Line chart showing max weight progression per exercise over time.
class WeightProgressChart extends StatelessWidget {
  const WeightProgressChart({super.key, required this.sessions});
  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    // Collect all exercise names with completed weighted sets
    final exerciseNames = <String>{};
    for (final session in sessions) {
      for (final ex in session.exercises) {
        if (!ex.skipped && ex.exerciseType == 'weighted') {
          final hasWeight = ex.sets.any((s) => s.completed && s.weight > 0);
          if (hasWeight) exerciseNames.add(ex.exerciseName);
        }
      }
    }

    if (exerciseNames.isEmpty) {
      return const GlassmorphismCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Completa qualche serie con pesi\nper vedere la progressione',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    // Build data points: for each exercise, max weight per session date
    final sortedSessions = sessions.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    // Just show top 3 exercises by frequency
    final exerciseCounts = <String, int>{};
    for (final name in exerciseNames) {
      exerciseCounts[name] = sortedSessions
          .where((s) =>
              s.exercises.any((e) => e.exerciseName == name && !e.skipped))
          .length;
    }
    final topExercises = (exerciseCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(6)
        .map((e) => e.key)
        .toList();

    final colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      const Color(0xFFFF6B6B),
      const Color(0xFF9B59B6),
      const Color(0xFF1ABC9C),
    ];

    final lineBarsData = <LineChartBarData>[];
    double maxY = 0;

    for (var i = 0; i < topExercises.length; i++) {
      final exName = topExercises[i];
      final spots = <FlSpot>[];

      for (var j = 0; j < sortedSessions.length; j++) {
        final session = sortedSessions[j];
        final matching = session.exercises
            .where((e) => e.exerciseName == exName && !e.skipped);
        if (matching.isNotEmpty) {
          final maxWeight = matching
              .expand((e) => e.sets)
              .where((s) => s.completed && s.weight > 0)
              .fold<double>(0, (max, s) => math.max(max, s.weight));
          if (maxWeight > 0) {
            spots.add(FlSpot(j.toDouble(), maxWeight));
            maxY = math.max(maxY, maxWeight);
          }
        }
      }

      if (spots.isNotEmpty) {
        lineBarsData.add(LineChartBarData(
          spots: spots,
          isCurved: true,
          color: colors[i],
          barWidth: 2,
          dotData: FlDotData(
            show: true,
            getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius: 3,
              color: colors[i],
              strokeColor: Colors.transparent,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            color: colors[i].withValues(alpha: 0.1),
          ),
        ));
      }
    }

    return GlassmorphismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Wrap(
            spacing: AppSpacing.md,
            children: topExercises.asMap().entries.map((entry) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors[entry.key],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    entry.value,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.bgElevated,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) => Text(
                        '${value.toInt()}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: const AxisTitles(),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: lineBarsData,
                minY: 0,
                maxY: maxY * 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
