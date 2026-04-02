import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

/// Bar chart showing total volume (kg) per muscle group.
class VolumeChart extends StatelessWidget {
  const VolumeChart({super.key, required this.sessions});
  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    // Aggregate volume per muscle group across all sessions
    final volumeByGroup = <String, double>{};
    for (final session in sessions) {
      for (final ex in session.exercises) {
        if (ex.skipped) continue;
        final group = ex.muscleGroup.isNotEmpty ? ex.muscleGroup : 'other';
        final volume = ex.sets
            .where((s) => s.completed)
            .fold<double>(0, (sum, s) => sum + (s.weight * s.actualReps));
        volumeByGroup[group] = (volumeByGroup[group] ?? 0) + volume;
      }
    }

    if (volumeByGroup.isEmpty) {
      return const GlassmorphismCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Completa qualche allenamento\nper vedere il volume per gruppo',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    // Sort by volume descending
    final sorted = volumeByGroup.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final barColors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      const Color(0xFFFF6B6B),
      const Color(0xFF9B59B6),
      AppColors.textSecondary,
    ];

    return GlassmorphismCard(
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: sorted.first.value * 1.15,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.bgElevated,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${sorted[groupIndex].key}\n${rod.toY.toStringAsFixed(0)} kg',
                    const TextStyle(
                        color: AppColors.textPrimary, fontSize: 12),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index >= sorted.length) return const SizedBox.shrink();
                    final label = sorted[index].key;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label.length > 6
                            ? '${label.substring(0, 6)}.'
                            : label,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: sorted.asMap().entries.map((entry) {
              final color =
                  barColors[entry.key % barColors.length];
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.value,
                    color: color,
                    width: 28,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: sorted.first.value * 1.15,
                      color: AppColors.bgElevated,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
