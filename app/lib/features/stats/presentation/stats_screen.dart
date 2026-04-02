import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/history/data/history_repository.dart';
import 'package:fitness_ai/features/stats/presentation/volume_chart.dart';
import 'package:fitness_ai/features/stats/presentation/weight_progress_chart.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

/// Screen showing workout statistics and charts.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyRepositoryProvider).getLocalSessions();

    return SafeArea(
      child: sessions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart,
                      size: 48,
                      color: AppColors.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: AppSpacing.md),
                  const GradientText('Statistiche',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'I grafici appariranno dopo\nle prime sessioni registrate.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const GradientText(
                  'Statistiche',
                  style:
                      TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Quick summary
                _QuickSummary(sessions: sessions),
                const SizedBox(height: AppSpacing.xl),
                // Weight progress chart
                _SectionTitle(
                    title: 'Progressione Carico',
                    icon: Icons.trending_up),
                const SizedBox(height: AppSpacing.sm),
                WeightProgressChart(sessions: sessions),
                const SizedBox(height: AppSpacing.xl),
                // Volume per muscle group
                _SectionTitle(
                    title: 'Volume per Gruppo',
                    icon: Icons.stacked_bar_chart),
                const SizedBox(height: AppSpacing.sm),
                VolumeChart(sessions: sessions),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _QuickSummary extends StatelessWidget {
  const _QuickSummary({required this.sessions});
  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    final totalSessions = sessions.length;
    final totalVolume = sessions.fold<double>(
        0, (sum, s) => sum + s.totalVolume);
    final totalSets = sessions.fold<int>(
        0, (sum, s) => sum + s.totalCompletedSets);

    return GlassmorphismCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: '$totalSessions',
            label: 'Sessioni',
            color: AppColors.primary,
          ),
          _StatItem(
            value: '${(totalVolume / 1000).toStringAsFixed(1)}t',
            label: 'Volume totale',
            color: AppColors.success,
          ),
          _StatItem(
            value: '$totalSets',
            label: 'Serie totali',
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        NeonText(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          color: color,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
