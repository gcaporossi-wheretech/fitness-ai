import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/ai/domain/coach_result.dart';
import 'package:fitness_ai/features/workout/data/workout_repository.dart';
import 'package:fitness_ai/features/workout/presentation/active_plan_provider.dart';

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
                    if (result.assessment != null &&
                        result.assessment!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      GlassmorphismCard(
                        borderColor: AppColors.primary.withValues(alpha: 0.25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.assignment_ind,
                                    color: AppColors.primary, size: 18),
                                SizedBox(width: AppSpacing.sm),
                                Text('La tua situazione e obiettivo',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(result.assessment!,
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                    if (result.photoReviewWeeks != null &&
                        result.photoReviewWeeks! > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(Icons.photo_camera,
                              color: AppColors.warning, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Rifai le foto tra ${result.photoReviewWeeks} settimane per valutare i progressi e aggiornare la scheda.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      // Persist the AI explanation (situation/objective +
                      // overview + progression) on the plan so it can be read
                      // again later from the workout screen.
                      final desc = [
                        if (result.assessment != null &&
                            result.assessment!.trim().isNotEmpty)
                          result.assessment!.trim(),
                        if (result.description.trim().isNotEmpty)
                          result.description.trim(),
                        if (result.notes != null && result.notes!.trim().isNotEmpty)
                          'Progressione: ${result.notes!.trim()}',
                        if (result.photoReviewWeeks != null &&
                            result.photoReviewWeeks! > 0)
                          'Rifai le foto tra ${result.photoReviewWeeks} settimane.',
                      ].join('\n\n');
                      try {
                        await ref.read(workoutRepositoryProvider).createPlan(
                              name: result.planName,
                              days: result.days,
                              description: desc.isEmpty ? null : desc,
                            );
                        ref.invalidate(activePlanProvider);
                        messenger.showSnackBar(const SnackBar(
                          content: Text('Scheda salvata!'),
                          backgroundColor: AppColors.success,
                        ));
                        navigator.popUntil((r) => r.isFirst);
                      } catch (e) {
                        messenger.showSnackBar(SnackBar(
                          content: Text('Errore nel salvataggio: $e'),
                          backgroundColor: AppColors.error,
                        ));
                      }
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
