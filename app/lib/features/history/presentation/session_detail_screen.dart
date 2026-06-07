import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';
import 'package:fitness_ai/features/workout/presentation/active_session_notifier.dart';
import 'package:fitness_ai/features/workout/presentation/active_workout_screen.dart';

/// Detail screen for a completed workout session.
/// Shows all exercises with their sets, weights, and reps.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.session});
  final WorkoutSession session;

  void _resume(BuildContext context, WidgetRef ref) {
    ref.read(activeSessionProvider.notifier).resumeSession(session);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('EEEE d MMMM yyyy, HH:mm', 'it');

    return Scaffold(
      appBar: AppBar(title: Text(session.dayName ?? 'Dettaglio Sessione')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Resume the workout (e.g. if it was finished by mistake).
            GlowButton(
              label: 'Riprendi allenamento',
              icon: Icons.play_arrow,
              onPressed: () => _resume(context, ref),
            ),
            const SizedBox(height: AppSpacing.md),
            // Session summary card
            GlassmorphismCard(
              borderColor: AppColors.success.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormat.format(session.startedAt),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryItem(
                        label: 'Durata',
                        value: session.formattedDuration,
                        icon: Icons.timer,
                      ),
                      _SummaryItem(
                        label: 'Serie',
                        value: '${session.totalCompletedSets}',
                        icon: Icons.repeat,
                      ),
                      _SummaryItem(
                        label: 'Volume',
                        value: '${session.totalVolume.toStringAsFixed(0)}kg',
                        icon: Icons.fitness_center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Esercizi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Exercise list
            ...session.exercises.asMap().entries.map((entry) {
              final exercise = entry.value;
              return StaggeredListItem(
                index: entry.key,
                child: GlassmorphismCard(
                  borderColor: exercise.skipped
                      ? AppColors.textDisabled.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exercise.exerciseName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    decoration: exercise.skipped
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: exercise.skipped
                                        ? AppColors.textDisabled
                                        : null,
                                  ),
                            ),
                          ),
                          if (exercise.skipped)
                            const Text('Saltato',
                                style: TextStyle(
                                    color: AppColors.textDisabled,
                                    fontSize: 12)),
                        ],
                      ),
                      if (!exercise.skipped) ...[
                        const SizedBox(height: AppSpacing.sm),
                        // Set header
                        const Row(
                          children: [
                            SizedBox(
                                width: 40,
                                child: Text('SET',
                                    style: _headerStyle)),
                            Expanded(
                                child: Text('KG',
                                    style: _headerStyle,
                                    textAlign: TextAlign.center)),
                            Expanded(
                                child: Text('REPS',
                                    style: _headerStyle,
                                    textAlign: TextAlign.center)),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ...exercise.sets.map((set) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 2),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${set.setNumber}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: set.completed
                                          ? AppColors.success
                                          : AppColors.textDisabled,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    set.weight > 0
                                        ? '${set.weight}'
                                        : '-',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    set.actualReps > 0
                                        ? '${set.actualReps}'
                                        : set.durationSeconds > 0
                                            ? '${set.durationSeconds}s'
                                            : '-',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

const _headerStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
);

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(height: AppSpacing.xs),
        BigNumber(value, fontSize: 20, color: AppColors.textPrimary),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
