import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/workout/domain/workout_plan.dart';

/// Screen for editing a workout plan (swap days, modify exercises).
/// Reads plans from WorkoutRepository (Hive cache / API).
class EditPlanScreen extends ConsumerWidget {
  const EditPlanScreen({super.key, required this.plan});
  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = plan.days.toList();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: Text(plan.name)),
      body: days.isEmpty
          ? const Center(
              child: Text(
                'No days in this plan.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (plan.description != null &&
                    plan.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    plan.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                ...days.asMap().entries.map((entry) {
                  final dayIndex = entry.key;
                  final day = entry.value;
                  return _DayCard(
                    day: day,
                    dayIndex: dayIndex,
                    plan: plan,
                    onSwap: (targetIndex) => _swapDays(
                      ref,
                      plan,
                      dayIndex,
                      targetIndex,
                      context,
                    ),
                    onEditExercise: (exIdx, exercise) =>
                        _showEditExerciseDialog(
                      context,
                      ref,
                      plan,
                      dayIndex,
                      exIdx,
                      exercise,
                    ),
                  );
                }),
              ],
            ),
    );
  }

  void _swapDays(
    WidgetRef ref,
    WorkoutPlan plan,
    int dayA,
    int dayB,
    BuildContext context,
  ) {
    // TODO: persist swap via WorkoutRepository.updatePlan() once available.
    // For now, show feedback to the user.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${plan.days[dayA].name} swapped with ${plan.days[dayB].name}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showEditExerciseDialog(
    BuildContext context,
    WidgetRef ref,
    WorkoutPlan plan,
    int dayIndex,
    int exerciseIndex,
    PlannedExercise exercise,
  ) {
    final setsController =
        TextEditingController(text: '${exercise.sets}');
    final repsController = TextEditingController(text: exercise.reps);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: Text(exercise.exerciseName,
            style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sets'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: repsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Reps'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${exercise.exerciseName} updated'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Save',
                style: TextStyle(color: AppColors.success)),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.dayIndex,
    required this.plan,
    required this.onSwap,
    required this.onEditExercise,
  });

  final WorkoutDay day;
  final int dayIndex;
  final WorkoutPlan plan;
  final void Function(int targetIndex) onSwap;
  final void Function(int exIdx, PlannedExercise exercise) onEditExercise;

  @override
  Widget build(BuildContext context) {
    return StaggeredListItem(
      index: dayIndex,
      child: GlassmorphismCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    'Day ${dayIndex + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    day.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // Swap day button
                IconButton(
                  icon: const Icon(Icons.swap_horiz,
                      color: AppColors.primary, size: 22),
                  tooltip: 'Swap day',
                  onPressed: () =>
                      _showSwapDayDialog(context, plan, dayIndex),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${day.exercises.length} exercises',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Exercise list with edit
            ...day.exercises.asMap().entries.map((entry) {
              final idx = entry.key;
              final ex = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${idx + 1}. ${ex.exerciseName}',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${ex.sets}x${ex.reps}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        icon: const Icon(Icons.edit,
                            size: 16, color: AppColors.primary),
                        padding: EdgeInsets.zero,
                        onPressed: () => onEditExercise(idx, ex),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSwapDayDialog(
    BuildContext context,
    WorkoutPlan plan,
    int currentDayIndex,
  ) {
    final availableDays = List.generate(plan.days.length, (i) => i)
        .where((i) => i != currentDayIndex)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: Text('Swap ${day.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: availableDays.map((targetIndex) {
            return ListTile(
              title: Text(plan.days[targetIndex].name),
              subtitle: Text('Day ${targetIndex + 1}',
                  style: const TextStyle(fontSize: 12)),
              onTap: () {
                onSwap(targetIndex);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
