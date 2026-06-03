import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/workout/data/workout_repository.dart';
import 'package:fitness_ai/features/workout/domain/workout_plan.dart';
import 'package:fitness_ai/features/workout/presentation/active_plan_provider.dart';

class _ExDraft {
  final name = TextEditingController();
  final sets = TextEditingController(text: '3');
  final reps = TextEditingController(text: '10');
  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
  }
}

class _DayDraft {
  _DayDraft(String initialName) : name = TextEditingController(text: initialName);
  final TextEditingController name;
  final TextEditingController warmup = TextEditingController();
  final List<_ExDraft> exercises = [_ExDraft()];
  void dispose() {
    name.dispose();
    warmup.dispose();
    for (final e in exercises) {
      e.dispose();
    }
  }
}

/// Manual workout-plan builder: name + days + exercises (sets/reps), saved
/// to the server. Used when the user has no plan yet (no AI coach needed).
class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  final _planName = TextEditingController(text: 'La mia scheda');
  final List<_DayDraft> _days = [_DayDraft('Giorno 1')];
  bool _saving = false;

  @override
  void dispose() {
    _planName.dispose();
    for (final d in _days) {
      d.dispose();
    }
    super.dispose();
  }

  void _addDay() =>
      setState(() => _days.add(_DayDraft('Giorno ${_days.length + 1}')));
  void _removeDay(int i) => setState(() {
        _days[i].dispose();
        _days.removeAt(i);
      });
  void _addEx(int dayIdx) =>
      setState(() => _days[dayIdx].exercises.add(_ExDraft()));
  void _removeEx(int dayIdx, int exIdx) => setState(() {
        _days[dayIdx].exercises[exIdx].dispose();
        _days[dayIdx].exercises.removeAt(exIdx);
      });

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _planName.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Dai un nome alla scheda')));
      return;
    }
    final days = <WorkoutDay>[];
    for (final d in _days) {
      final exs = <PlannedExercise>[];
      for (final e in d.exercises) {
        final exName = e.name.text.trim();
        if (exName.isEmpty) continue;
        exs.add(PlannedExercise(
          exerciseName: exName,
          sets: int.tryParse(e.sets.text.trim()) ?? 3,
          reps: e.reps.text.trim().isEmpty ? '10' : e.reps.text.trim(),
        ));
      }
      if (exs.isNotEmpty) {
        final dayName = d.name.text.trim();
        final warmup = d.warmup.text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        days.add(WorkoutDay(
            name: dayName.isEmpty ? 'Giorno' : dayName,
            exercises: exs,
            warmup: warmup));
      }
    }
    if (days.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Aggiungi almeno un esercizio')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(workoutRepositoryProvider)
          .createPlan(name: name, days: days);
      ref.invalidate(activePlanProvider);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Scheda creata!'),
          backgroundColor: AppColors.success,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(title: const Text('Crea scheda')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _planName,
            decoration: const InputDecoration(labelText: 'Nome scheda'),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._days.asMap().entries.map((e) => _dayCard(e.key, e.value)),
          OutlinedButton.icon(
            onPressed: _addDay,
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi giorno'),
          ),
          const SizedBox(height: AppSpacing.lg),
          GlowButton(
            label: _saving ? 'Salvataggio...' : 'Salva scheda',
            onPressed: _save,
            enabled: !_saving,
            icon: Icons.check,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _dayCard(int dayIdx, _DayDraft day) {
    return GlassmorphismCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: day.name,
                  decoration: const InputDecoration(labelText: 'Nome giorno'),
                ),
              ),
              if (_days.length > 1)
                IconButton(
                  onPressed: () => _removeDay(dayIdx),
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.error),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: day.warmup,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Riscaldamento (una voce per riga, opzionale)',
              hintText: '5 min cardio\nMobilità spalle',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...day.exercises.asMap().entries.map((e) => _exRow(dayIdx, e.key, e.value)),
          TextButton.icon(
            onPressed: () => _addEx(dayIdx),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Aggiungi esercizio'),
          ),
        ],
      ),
    );
  }

  Widget _exRow(int dayIdx, int exIdx, _ExDraft ex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: ex.name,
              decoration: const InputDecoration(hintText: 'Esercizio'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: ex.sets,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Serie'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: TextField(
              controller: ex.reps,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
            ),
          ),
          SizedBox(
            width: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => _removeEx(dayIdx, exIdx),
              icon: const Icon(Icons.close,
                  size: 16, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
