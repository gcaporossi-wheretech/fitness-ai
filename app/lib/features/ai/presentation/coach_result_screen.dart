import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/ai/domain/coach_result.dart';

/// Screen showing the AI-generated workout plan.
/// Allows the user to review, save, or modify the plan.
class CoachResultScreen extends ConsumerWidget {
  const CoachResultScreen({super.key, required this.result});
  final CoachResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scheda Generata'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const NeonText(
                      'Coach AI',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      color: AppColors.success,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    GradientText(
                      result.planName,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      result.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (result.notes != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      GlassmorphismCard(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        borderColor: AppColors.warning.withValues(alpha: 0.2),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppColors.warning, size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                result.notes!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    // Days
                    ...result.days.asMap().entries.map((entry) {
                      final day = entry.value;
                      return _DayCard(
                        dayNumber: entry.key + 1,
                        day: day,
                      );
                    }),
                  ],
                ),
              ),
            ),
            // Bottom actions
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  GlowButton(
                    label: 'Salva Scheda',
                    onPressed: () {
                      // TODO: Save plan via API and navigate back
                      Navigator.of(context).pop();
                    },
                    icon: Icons.save,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Scarta e torna indietro',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card showing one day of the generated plan.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.dayNumber, required this.day});
  final int dayNumber;
  final dynamic day; // WorkoutDay

  @override
  Widget build(BuildContext context) {
    final dayName = day.name as String;
    final exercises = day.exercises as List;

    return GlassmorphismCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$dayNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                dayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...exercises.map((ex) {
            final name = (ex.exerciseName ?? ex.name ?? '') as String;
            final sets = ex.sets as int;
            final reps = ex.reps.toString();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  Text(
                    '${sets}x$reps',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
