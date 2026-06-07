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
import 'package:fitness_ai/features/workout/data/workout_repository.dart';
import 'package:fitness_ai/features/workout/presentation/active_session_notifier.dart';
import 'package:fitness_ai/features/workout/presentation/exercise_name_field.dart';
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
      // Rebuild so the persistent timer bar picks up the new set labels;
      // it keeps itself updated afterwards via the timer's notifications.
      setState(() {});
    }
  }

  Future<void> _finishWorkout() async {
    // Confirm first: finishing is final (can't be resumed), so guard against
    // an accidental tap on FINE.
    final state = ref.read(activeSessionProvider);
    final done = state?.completedExercises ?? 0;
    final total = state?.totalExercises ?? 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: const Text('Terminare l\'allenamento?'),
        content: Text(
            'Hai completato $done/$total esercizi. Una volta terminato non '
            'potrai riprenderlo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continua'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Termina',
                style: TextStyle(
                    color: AppColors.success, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    ref.read(activeSessionProvider.notifier).completeSession();
    // Show rating dialog first, then completion screen
    _showRatingDialog();
  }

  /// Ask for end-of-workout feedback: overall, fatigue and pump (each 1-5).
  void _showRatingDialog() {
    int overall = 0;
    int fatigue = 0;
    int pump = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.bgSecondary,
          title: const GradientText(
            "Com'è andato l'allenamento?",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          contentPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RatingSection(
                  label: 'Complessivamente',
                  value: overall,
                  onChanged: (v) => setDialogState(() => overall = v),
                ),
                _RatingSection(
                  label: 'Sensazione di fatica',
                  value: fatigue,
                  onChanged: (v) => setDialogState(() => fatigue = v),
                ),
                _RatingSection(
                  label: 'Sensazione di pump',
                  value: pump,
                  onChanged: (v) => setDialogState(() => pump = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showCompletionScreen();
              },
              child: const Text(
                'Salta',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            GlowButton(
              label: 'Conferma',
              onPressed: () {
                ref.read(activeSessionProvider.notifier).setRatings(
                      overall: overall,
                      fatigue: fatigue,
                      pump: pump,
                    );
                Navigator.of(ctx).pop();
                _showCompletionScreen();
              },
              enabled: overall > 0 || fatigue > 0 || pump > 0,
              color: AppColors.success,
              height: 40,
            ),
          ],
        ),
      ),
    );
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
    // For a resumed session show the original (saved) duration; otherwise the
    // live elapsed time. Recomputing now - startedAt for a resumed past session
    // would show an absurd value (the workout was hours/days ago).
    final elapsedMin = sessionState.resumed
        ? ((session.durationSeconds ?? 0) ~/ 60)
        : DateTime.now().difference(session.startedAt).inMinutes;

    final hasWarmup = sessionState.warmup.isNotEmpty;
    final warmupOffset = hasWarmup ? 1 : 0;

    // Group consecutive exercises sharing a superset id so they render together.
    final groups = <List<int>>[];
    String? lastGroup;
    for (var i = 0; i < session.exercises.length; i++) {
      final g = session.exercises[i].supersetGroup;
      final gid = (g != null && g.trim().isNotEmpty) ? g.trim() : null;
      if (gid != null && gid == lastGroup && groups.isNotEmpty) {
        groups.last.add(i);
      } else {
        groups.add([i]);
      }
      lastGroup = gid;
    }

    return Scaffold(
      body: SafeArea(
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
            // Persistent rest timer bar — stays visible at the top while
            // resting and auto-hides when the countdown ends or is skipped.
            RestTimerBar(
              timer: _restTimer,
              exerciseName: _lastExerciseName,
              currentSet: _lastSetNumber,
              totalSets: _lastTotalSets,
              onSkip: () {
                _restTimer.skip();
                setState(() {});
              },
              onAddThirty: () => _restTimer.addThirtySeconds(),
            ),
            // Warm-up checklist (top) + exercises + add button
            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: groups.length + 1 + warmupOffset,
                itemBuilder: (context, index) {
                  if (hasWarmup && index == 0) {
                    return const _WarmupChecklist();
                  }
                  final gIndex = index - warmupOffset;
                  if (gIndex == groups.length) {
                    return _AddExerciseButton(
                      onAdd: _addExercise,
                    );
                  }
                  final group = groups[gIndex];
                  if (group.length == 1) {
                    final exIndex = group.first;
                    return _ExerciseCard(
                      exercise: session.exercises[exIndex],
                      exerciseIndex: exIndex,
                      onSetCompleted: (setIndex) => _onSetCompleted(
                        session.exercises[exIndex],
                        exIndex,
                        setIndex,
                      ),
                    );
                  }
                  return _SupersetCard(
                    exercises: [for (final i in group) session.exercises[i]],
                    indices: group,
                    onSetCompleted: (exIndex, setIndex) => _onSetCompleted(
                      session.exercises[exIndex],
                      exIndex,
                      setIndex,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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

  Future<void> _addExercise() async {
    // Pick from existing exercises (consistent names) or create a new one
    // explicitly — avoids typing a slightly different name by mistake.
    final known = ref.read(knownExerciseNamesProvider);
    final name = await showExercisePicker(context, known);
    if (name == null || name.trim().isEmpty) return;
    ref.read(activeSessionProvider.notifier).addCustomExercise(
          name: name.trim(),
          sets: 3,
          reps: 10,
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
                if (session.overallRating > 0)
                  _SummaryRow(
                    label: 'Complessivamente',
                    value: _stars(session.overallRating),
                  ),
                if (session.fatigueRating > 0)
                  _SummaryRow(
                    label: 'Fatica',
                    value: _stars(session.fatigueRating),
                  ),
                if (session.pumpRating > 0)
                  _SummaryRow(
                    label: 'Pump',
                    value: _stars(session.pumpRating),
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

/// The inner content of one exercise (header + set rows + controls).
/// Reused standalone (in [_ExerciseCard]) and grouped (in [_SupersetCard]).
class _ExerciseBody extends ConsumerWidget {
  const _ExerciseBody({
    required this.exercise,
    required this.exerciseIndex,
    required this.onSetCompleted,
  });

  final ExerciseLog exercise;
  final int exerciseIndex;
  final void Function(int setIndex) onSetCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exercise header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.exerciseName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: exercise.skipped
                                  ? AppColors.textDisabled
                                  : null,
                              decoration: exercise.skipped
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      if (exercise.notes.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            exercise.notes,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                    ],
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
                    if (exercise.exerciseType == 'cardio') ...[
                      const Expanded(child: SizedBox()),
                    ] else if (exercise.exerciseType == 'weighted') ...[
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
                    label: const Text('Aggiungi serie'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  if (exercise.sets.length > 1)
                    TextButton.icon(
                      onPressed: () => ref
                          .read(activeSessionProvider.notifier)
                          .removeSet(
                            exerciseIndex: exerciseIndex,
                            setIndex: exercise.sets.length - 1,
                          ),
                      icon: const Icon(Icons.remove, size: 16),
                      label: const Text('Rimuovi'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
  }
}

/// Card for a single exercise showing all its sets inline.
class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.exerciseIndex,
    required this.onSetCompleted,
  });

  final ExerciseLog exercise;
  final int exerciseIndex;
  final void Function(int setIndex) onSetCompleted;

  @override
  Widget build(BuildContext context) {
    return StaggeredListItem(
      index: exerciseIndex,
      child: GlassmorphismCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        borderColor: exercise.isComplete
            ? AppColors.success.withValues(alpha: 0.3)
            : exercise.skipped
                ? AppColors.textDisabled.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.1),
        child: _ExerciseBody(
          exercise: exercise,
          exerciseIndex: exerciseIndex,
          onSetCompleted: onSetCompleted,
        ),
      ),
    );
  }
}

/// Card grouping a superset: two or more exercises performed back-to-back.
class _SupersetCard extends StatelessWidget {
  const _SupersetCard({
    required this.exercises,
    required this.indices,
    required this.onSetCompleted,
  });

  final List<ExerciseLog> exercises;
  final List<int> indices;
  final void Function(int exerciseIndex, int setIndex) onSetCompleted;

  @override
  Widget build(BuildContext context) {
    final allDone = exercises.every((e) => e.isComplete || e.skipped);
    return StaggeredListItem(
      index: indices.first,
      child: GlassmorphismCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        borderColor: allDone
            ? AppColors.success.withValues(alpha: 0.3)
            : AppColors.warning.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: AppColors.warning, size: 18),
                const SizedBox(width: AppSpacing.xs),
                const Text(
                  'SUPERSET',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'esegui di fila, recupero alla fine del giro',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            for (int j = 0; j < exercises.length; j++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(
                  color: AppColors.textDisabled.withValues(alpha: 0.2),
                  height: 1,
                ),
              ),
              _ExerciseBody(
                exercise: exercises[j],
                exerciseIndex: indices[j],
                onSetCompleted: (setIndex) =>
                    onSetCompleted(indices[j], setIndex),
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

/// Render an integer score as filled/empty stars for summaries.
String _stars(int n) => '★' * n + '☆' * (5 - n);

/// Collapsible warm-up checklist shown at the top of the active workout.
class _WarmupChecklist extends ConsumerStatefulWidget {
  const _WarmupChecklist();

  @override
  ConsumerState<_WarmupChecklist> createState() => _WarmupChecklistState();
}

class _WarmupChecklistState extends ConsumerState<_WarmupChecklist> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeSessionProvider);
    if (state == null || state.warmup.isEmpty) return const SizedBox.shrink();

    final allDone = state.warmupAllDone;
    final accent = allDone ? AppColors.success : AppColors.warning;

    return GlassmorphismCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      borderColor: accent.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(allDone ? Icons.check_circle : Icons.whatshot,
                    color: accent, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Riscaldamento (${state.warmupDoneCount}/${state.warmup.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: AppSpacing.xs),
            ...state.warmup.asMap().entries.map((entry) {
              final i = entry.key;
              final checked =
                  i < state.warmupChecked.length && state.warmupChecked[i];
              return InkWell(
                onTap: () =>
                    ref.read(activeSessionProvider.notifier).toggleWarmup(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        checked
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: checked
                            ? AppColors.success
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            color: checked
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            decoration: checked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// One labelled 1-5 rating row in the end-of-workout feedback dialog.
class _RatingSection extends StatelessWidget {
  const _RatingSection({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _StarRating(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Five tappable stars that never overflow (scaled down to fit if needed),
/// so the 5th star is always reachable on narrow dialogs.
class _StarRating extends StatelessWidget {
  const _StarRating({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final starIndex = i + 1;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(starIndex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                starIndex <= value ? Icons.star : Icons.star_border,
                color: starIndex <= value
                    ? AppColors.warning
                    : AppColors.textSecondary,
                size: 36,
              ),
            ),
          );
        }),
      ),
    );
  }
}
