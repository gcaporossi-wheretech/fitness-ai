import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/nutrition/domain/nutrition.dart';

/// Nutrition screen: shows personalized calorie + macro targets, a sample
/// Italian meal plan for body recomposition, and practical rules. The user can
/// edit weight/activity/goal to recompute; inputs persist locally.
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late NutritionInputs _inputs;
  late MacroTargets _targets;

  @override
  void initState() {
    super.initState();
    _inputs = NutritionInputs.load();
    _targets = computeTargets(_inputs);
  }

  void _recompute(NutritionInputs i) {
    i.save();
    setState(() {
      _inputs = i;
      _targets = computeTargets(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Nutrizione'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Modifica dati',
            onPressed: _showEditSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            _TargetsCard(inputs: _inputs, targets: _targets),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle('Come distribuirle'),
            const _InfoCard(
              text:
                  'Ti alleni presto (6-8). Allenati pure leggero/a digiuno '
                  '(caffè + eventuale banana), poi fai della COLAZIONE '
                  'post-allenamento il pasto piu ricco di proteine e '
                  'carboidrati. Metti i carboidrati soprattutto a colazione, '
                  'post-workout e pranzo; cena piu proteica e con verdure.',
            ),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle('Menu esempio (giornata tipo)'),
            ..._meals.map((m) => _MealCard(meal: m)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Adatta le porzioni per avvicinarti ai target qui sopra. '
              'I valori dei cibi sono indicativi.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            const _SectionTitle("Regole d'oro"),
            ..._rules.map((r) => _RuleRow(text: r)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Indicazioni a scopo informativo, non una dieta medica. '
              'Per patologie, farmaci o esami specifici consulta un '
              'medico/nutrizionista.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textDisabled,
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditSheet() async {
    final weightCtrl =
        TextEditingController(text: _inputs.weightKg.toStringAsFixed(0));
    final heightCtrl =
        TextEditingController(text: _inputs.heightCm.toStringAsFixed(0));
    final ageCtrl = TextEditingController(text: _inputs.age.toString());
    String activity = _inputs.activity;
    String goal = _inputs.goal;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('I tuoi dati',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: weightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Altezza (cm)'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Eta'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: activity,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Attivita'),
                items: kActivityLabels.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value,
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setSheet(() => activity = v ?? activity),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                value: goal,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Obiettivo'),
                items: kGoalLabels.entries
                    .map((e) => DropdownMenuItem(
                        value: e.key,
                        child:
                            Text(e.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setSheet(() => goal = v ?? goal),
              ),
              const SizedBox(height: AppSpacing.lg),
              GlowButton(
                label: 'Ricalcola',
                icon: Icons.check,
                onPressed: () {
                  final w = double.tryParse(weightCtrl.text.replaceAll(',', '.'));
                  final h = double.tryParse(heightCtrl.text.replaceAll(',', '.'));
                  final a = int.tryParse(ageCtrl.text);
                  _recompute(_inputs.copyWith(
                    weightKg: (w != null && w > 0) ? w : _inputs.weightKg,
                    heightCm: (h != null && h > 0) ? h : _inputs.heightCm,
                    age: (a != null && a > 0) ? a : _inputs.age,
                    activity: activity,
                    goal: goal,
                  ));
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetsCard extends StatelessWidget {
  const _TargetsCard({required this.inputs, required this.targets});
  final NutritionInputs inputs;
  final MacroTargets targets;

  @override
  Widget build(BuildContext context) {
    return GlassmorphismCard(
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kGoalLabels[inputs.goal] ?? inputs.goal,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GradientText(
                '${targets.kcal}',
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('kcal / giorno',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
          Text('Mantenimento stimato: ~${targets.maintenanceKcal} kcal',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _MacroChip(
                  label: 'Proteine',
                  grams: targets.protein,
                  color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              _MacroChip(
                  label: 'Carbo',
                  grams: targets.carbs,
                  color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              _MacroChip(
                  label: 'Grassi',
                  grams: targets.fat,
                  color: AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip(
      {required this.label, required this.grams, required this.color});
  final String label;
  final int grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text('${grams}g',
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return GlassmorphismCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _Meal {
  const _Meal(this.emoji, this.title, this.time, this.items);
  final String emoji;
  final String title;
  final String time;
  final String items;
}

const List<_Meal> _meals = [
  _Meal('☕', 'Pre-workout (facoltativo)', '~5:45',
      'Caffè + 1 banana piccola (oppure allenati a digiuno).'),
  _Meal('🍳', 'Colazione post-allenamento', '~8:15',
      '200g yogurt greco + 60g avena + 1 frutto + 15g miele + 15g mandorle '
          '(aggiungi 30g di proteine in polvere se le usi).'),
  _Meal('🥪', 'Spuntino', '~11:00',
      '150g ricotta o 2-3 fette di bresaola/fesa + 1 frutto.'),
  _Meal('🍝', 'Pranzo', '~13:30',
      '130-150g pollo/tacchino/pesce + 70-80g (secco) pasta o riso integrale '
          '(o 250g patate) + verdure a volontà + 1 cucchiaio olio evo.'),
  _Meal('🥛', 'Spuntino', '~17:00',
      '150g yogurt greco o frullato proteico + 30g frutta secca.'),
  _Meal('🐟', 'Cena', '~20:30',
      '180-200g pesce bianco/salmone o carne magra o uova/legumi + verdure '
          'abbondanti + 50g pane integrale (o 200g patate) + 1 cucchiaio olio evo.'),
];

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});
  final _Meal meal;
  @override
  Widget build(BuildContext context) {
    return GlassmorphismCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(meal.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(meal.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              Text(meal.time,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(meal.items, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

const List<String> _rules = [
  'Proteine ad OGNI pasto (~30-40g): fondamentale a 57 anni per mantenere e costruire muscolo.',
  'Verdura a pranzo e cena: sazietà e micronutrienti, poche calorie.',
  'Carboidrati intorno all\'allenamento (colazione/pranzo): energia per le sessioni delle 6.',
  '2-3 litri di acqua al giorno; il caffè pre-workout va benissimo.',
  'Limita: zuccheri e dolci, alcol, fritti, bibite zuccherate.',
  '1 pasto libero a settimana è concesso: aiuta a essere costante.',
  'Pesati 1 volta a settimana a digiuno: se cali troppo in fretta (>0,5 kg/sett) o sei stanco, aggiungi ~200 kcal di carboidrati.',
];

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle,
              color: AppColors.success, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
