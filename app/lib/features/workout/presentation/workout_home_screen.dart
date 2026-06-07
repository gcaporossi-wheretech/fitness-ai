import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/workout/domain/workout_plan.dart';
import 'package:fitness_ai/features/workout/presentation/active_plan_provider.dart';
import 'package:fitness_ai/features/workout/presentation/active_session_notifier.dart';
import 'package:fitness_ai/features/workout/presentation/active_workout_screen.dart';
import 'package:fitness_ai/features/workout/presentation/create_plan_screen.dart';
import 'package:fitness_ai/features/ai/presentation/coach_onboarding_screen.dart';
import 'package:fitness_ai/features/ai/presentation/vision_scan_screen.dart';
import 'package:fitness_ai/features/nutrition/presentation/nutrition_screen.dart';

/// Main workout screen: shows the active plan's days and starts a session.
/// This is the default tab and the entry point of the app.
class WorkoutHomeScreen extends ConsumerWidget {
  const WorkoutHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(activePlanProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              const GradientText(
                'FitnessAI',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('Oggi', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              const _QuickActions(),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: planAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _EmptyState(onReload: () => _reload(ref), onCreate: () => _create(context, ref)),
                  data: (plan) => plan == null
                      ? _EmptyState(onReload: () => _reload(ref), onCreate: () => _create(context, ref))
                      : _PlanView(plan: plan),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reload(WidgetRef ref) => ref.invalidate(activePlanProvider);

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const CreatePlanScreen()),
    );
    ref.invalidate(activePlanProvider);
  }
}

/// Shows the active plan and its days; tapping a day starts the workout.
class _PlanView extends ConsumerWidget {
  const _PlanView({required this.plan});

  final WorkoutPlan plan;

  void _start(BuildContext context, WidgetRef ref, WorkoutDay day) {
    ref.read(activeSessionProvider.notifier).startSession(day, planId: plan.id);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(plan.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            if (plan.description != null && plan.description!.trim().isNotEmpty)
              IconButton(
                icon: const Icon(Icons.info_outline, color: AppColors.primary),
                tooltip: 'Info scheda',
                onPressed: () =>
                    _showPlanInfo(context, plan.description!.trim()),
              ),
          ],
        ),
        Text(
          "Scegli l'allenamento di oggi",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: ListView.separated(
            itemCount: plan.days.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final day = plan.days[i];
              return GestureDetector(
                onTap: () => _start(context, ref, day),
                child: GlassmorphismCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center,
                          color: AppColors.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day.name,
                              style:
                                  Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${day.exercises.length} esercizi',
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_circle_fill,
                          size: 36, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Shown when there is no active plan (offline with empty cache, or none yet).
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReload, required this.onCreate});

  final VoidCallback onReload;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassmorphismCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center,
                size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: AppSpacing.md),
            Text('Nessuna scheda attiva',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Controlla la connessione e ricarica,\noppure crea una scheda.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            GlowButton(
              label: 'Crea scheda',
              onPressed: onCreate,
              icon: Icons.add,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Ricarica'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact quick-actions row: Coach AI, Scansiona, Nutrizione.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.auto_awesome,
            label: 'Coach AI',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const CoachOnboardingScreen()),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickAction(
            icon: Icons.camera_alt,
            label: 'Scansiona',
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const VisionScanScreen()),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _QuickAction(
            icon: Icons.restaurant_menu,
            label: 'Nutrizione',
            color: AppColors.success,
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const NutritionScreen()),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassmorphismCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
      borderColor: color.withValues(alpha: 0.25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Show the plan description / AI coach explanation in a dialog.
void _showPlanInfo(BuildContext context, String text) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgSecondary,
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          SizedBox(width: AppSpacing.sm),
          Text('Info scheda'),
        ],
      ),
      content: SingleChildScrollView(child: Text(text)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Chiudi'),
        ),
      ],
    ),
  );
}
