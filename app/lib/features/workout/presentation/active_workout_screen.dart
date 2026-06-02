import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/services/rest_timer_service.dart';
import 'package:fitness_ai/core/services/timer_notification.dart'
    if (dart.library.js_interop)
    'package:fitness_ai/core/services/timer_notification_web.dart';
import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/workout/domain/exercise_log.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';
import 'package:fitness_ai/features/workout/presentation/active_session_notifier.dart';
import 'package:fitness_ai/features/workout/presentation/rest_timer_overlay.dart';
import 'package:fitness_ai/features/workout/presentation/set_input_row.dart';

/// Active workout screen with inline set tracker (Strong-style).
/// Shows all exercises with expandable set rows, rest timer, and
/// session controls. Includes session rating and celebration overlay
/// on completion.
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  final _restTimer = RestTimerService();
  bool _showTimer = false;
  String? _lastExerciseName;
  int? _lastSetNumber;
  int? _lastTotalSets;

  @override
  void initState() {
    super.initState();
    // Unlock audio on first user gesture context (required by browsers/mobile)
    TimerNotification.unlockAudio();
  }

  @override
  void dispose() {
    _restTimer.dispose();
    super.dispose();
  }

  void _onSetCompleted(ExerciseLog exercise, int exerciseIndex, int setIndex) {
    _lastExerciseName = exercise.exerciseName;
    _lastSetNumber = setIndex + 1;
    _lastTotalSets = exercise.sets.length;
    if (exercise.restSeconds > 0) {
      _restTimer.start(exercise.restSeconds);
      setState(() => _showTimer = true);
    }
  }

  void _finishWorkout() {
    final notifier = ref.read(activeSessionProvider.notifier);
    notifier.completeSession();

    // Show rating dialog first, then completion screen
    _showRatingDialog();
  }

  /// Show a dialog to rate the session 1-5 stars before the celebration.
  void _showRatingDialog() {
    int selectedRating = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgSecondary,
          title: const GradientText(
            'How was the workout?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedRating = starIndex),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        starIndex <= selectedRating
                            ? Icons.star
                            : Icons.star_border,
                        color: starIndex <= selectedRating
                            ? AppColors.warning
                            : AppColors.textSecondary,
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                selectedRating > 0
                    ? _ratingLabel(selectedRating)
                    : 'Tap a star to rate',
                style: TextStyle(
                  color: selectedRating > 0
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showCompletionScreen();
              },
              child: const Text(
                'Skip',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            GlowButton(
              label: 'Confirm',
              onPressed: () {
                if (selectedRating > 0) {
                  ref
                      .read(activeSessionProvider.notifier)
                      .setRating(selectedRating);
                  Navigator.of(ctx).pop();
                  _showCompletionScreen();
                }
              },
              enabled: selectedRating > 0,
              color: AppColors.success,
              height: 40,
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Terrible';
      case 2:
        return 'Poor';
      case 3:
        return 'Okay';
      case 4:
        return 'Good';
      case 5:
        return 'Amazing!';
      default:
        return '';
    }
  }

  /// Show completion dialog with celebration overlay.
  void _showCompletionScreen() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final session = ref.read(activeSessionProvider)?.session;
        return _CompletionDialog(
          session: session,
          onClose: () {
            ref.read(activeSessionProvider.notifier).closeSession();
            Navigator.of(ctx).pop();
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(activeSessionProvider);
    if (sessionState == null) {
      return const Scaffold(
        body: Center(child: Text('Nessuna sessione attiva')),
      );
    }

    final session = sessionState.session;
    final elapsed = DateTime.now().difference(session.startedAt);
    final elapsedMin = elapsed.inMinutes;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => _showCancelDialog(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              session.dayName ?? 'Workout',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${elapsedMin}min - ${sessionState.completedExercises}/${sessionState.totalExercises} esercizi',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _finishWorkout,
                        child: const Text(
                          'FINE',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Exercise list
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: session.exercises.length + 1, // +1 for add button
                    itemBuilder: (context, index) {
                      if (index == session.exercises.length) {
                        return _AddExerciseButton(
                          onAdd: () => _showAddExerciseDialog(),
                        );
                      }
                      return _ExerciseCard(
                        exercise: session.exercises[index],
                        exerciseIndex: index,
                        onSetCompleted: (setIndex) => _onSetCompleted(
                          session.exercises[index],
                          index,
                          setIndex,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Rest timer overlay
          if (_showTimer)
            RestTimerOverlay(
              timer: _restTimer,
              exerciseName: _lastExerciseName,
              currentSet: _lastSetNumber,
              totalSets: _lastTotalSets,
              onSkip: () {
                _restTimer.skip();
                setState(() => _showTimer = false);
              },
              onAddThirty: () => _restTimer.addThirtySeconds(),
              onDismiss: () => setState(() => _showTimer = false),
            ),
        ],
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Annullare il workout?'),
        content: const Text('I dati della sessione verranno persi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continua'),
          ),
          TextButton(
            onPressed: () {
              ref.read(activeSessionProvider.notifier).closeSession();
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Annulla workout',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddExerciseDialog() {
    final nameController = TextEditingController();
    final setsController = TextEditingController(text: '3');
    final repsController = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Aggiungi esercizio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Nome esercizio'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: setsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Serie'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: repsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Reps'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(activeSessionProvider.notifier).addCustomExercise(
                      name: nameController.text,
                      sets: int.tryParse(setsController.text) ?? 3,
                      reps: int.tryParse(repsController.text) ?? 10,
                    );
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Aggiungi',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

/// Completion dialog with celebration overlay and session summary.
class _CompletionDialog extends StatefulWidget {
  const _CompletionDialog({
    required this.session,
    required this.onClose,
  });

  final WorkoutSession? session;
  final VoidCallback onClose;

  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  bool _showCelebration = true;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;

    return Stack(
      children: [
        AlertDialog(
          backgroundColor: AppColors.bgSecondary,
          title: const GradientText(
            'Allenamento completato!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (session != null) ...[
                _SummaryRow(
                    label: 'Durata', value: session.formattedDuration),
                _SummaryRow(
                    label: 'Serie completate',
                    value: '${session.totalCompletedSets}'),
                _SummaryRow(
                    label: 'Volume totale',
                    value: '${session.totalVolume.toStringAsFixed(0)} kg'),
                if (session.rating > 0)
                  _SummaryRow(
                    label: 'Valutazione',
                    value: List.filled(session.rating, '\u2605').join(),
                  ),
              ],
            ],
          ),
          actions: [
            GlowButton(
              label: 'Chiudi',
              onPressed: widget.onClose,
              color: AppColors.success,
              height: 48,
            ),
          ],
        ),
        if (_showCelebration)
          Positioned.fill(
            child: CelebrationOverlay(
              onComplete: () => setState(() => _showCelebration = false),
            ),
          ),
      ],
    );
  }
}

/// Card for a single exercise showing all its sets inline.
class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.exerciseIndex,
    required this.onSetCompleted,
  });

  final ExerciseLog exercise;
  final int exerciseIndex;
  final void Function(int setIndex) onSetCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StaggeredListItem(
      index: exerciseIndex,
      child: GlassmorphismCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        borderColor: exercise.isComplete
            ? AppColors.success.withValues(alpha: 0.3)
            : exercise.skipped
                ? AppColors.textDisabled.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise header
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.exerciseName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: exercise.skipped
                              ? AppColors.textDisabled
                              : null,
                          decoration:
                              exercise.skipped ? TextDecoration.lineThrough : null,
                        ),
                  ),
                ),
                // Skip / Unskip
                IconButton(
                  icon: Icon(
                    exercise.skipped ? Icons.undo : Icons.skip_next,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () {
                    if (exercise.skipped) {
                      ref
                          .read(activeSessionProvider.notifier)
                          .unskipExercise(exerciseIndex);
                    } else {
                      ref
                          .read(activeSessionProvider.notifier)
                          .skipExercise(exerciseIndex);
                    }
                  },
                ),
              ],
            ),
            if (!exercise.skipped) ...[
              const SizedBox(height: AppSpacing.sm),
              // Set header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  children: [
                    const SizedBox(width: 32, child: Text('SET', style: _headerStyle)),
                    if (exercise.exerciseType == 'weighted') ...[
                      const Expanded(child: Text('KG', style: _headerStyle, textAlign: TextAlign.center)),
                      const Expanded(child: Text('REPS', style: _headerStyle, textAlign: TextAlign.center)),
                    ] else if (exercise.exerciseType == 'timed') ...[
                      const Expanded(child: Text('SEC', style: _headerStyle, textAlign: TextAlign.center)),
                    ] else ...[
                      const Expanded(child: Text('REPS', style: _headerStyle, textAlign: TextAlign.center)),
                    ],
                    const SizedBox(width: 36),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Set rows
              ...exercise.sets.asMap().entries.map((entry) {
                return SetInputRow(
                  setLog: entry.value,
                  exerciseType: exercise.exerciseType,
                  exerciseIndex: exerciseIndex,
                  setIndex: entry.key,
                  onCompleted: () => onSetCompleted(entry.key),
                );
              }),
              // Add/remove set controls
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => ref
                        .read(activeSessionProvider.notifier)
                        .addSet(exerciseIndex: exerciseIndex),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Serie'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
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

/// Summary row in the completion dialog.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

/// Button to add a custom exercise during workout.
class _AddExerciseButton extends StatelessWidget {
  const _AddExerciseButton({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: GlassmorphismCard(
        onTap: onAdd,
        borderColor: AppColors.primary.withValues(alpha: 0.1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Aggiungi esercizio',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
