import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';

/// Text field for an exercise name with autocomplete from known names
/// (history + catalog), so the same exercise always gets the same name.
/// Uses the caller's [controller]/[focusNode] so the entered value is read
/// the usual way (no special wiring needed).
class ExerciseNameField extends StatelessWidget {
  const ExerciseNameField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.known,
    this.hintText = 'Esercizio',
    this.labelText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> known;
  final String hintText;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.length < 2) return const Iterable<String>.empty();
        // Prefix matches first, then contains.
        final starts = <String>[];
        final contains = <String>[];
        for (final n in known) {
          final l = n.toLowerCase();
          if (l == q) continue; // already exactly typed
          if (l.startsWith(q)) {
            starts.add(n);
          } else if (l.contains(q)) {
            contains.add(n);
          }
        }
        return [...starts, ...contains].take(8);
      },
      fieldViewBuilder: (context, ctrl, fn, onFieldSubmitted) {
        return TextField(
          controller: ctrl,
          focusNode: fn,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => onFieldSubmitted(),
          decoration: InputDecoration(
            hintText: hintText,
            labelText: labelText,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: AppColors.bgSecondary,
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final opt = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(opt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Text(opt,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14)),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Bottom-sheet picker to choose an exercise by name. Shows the known
/// exercises (history + catalog) filtered by search so the SAME name is always
/// reused; creating a brand-new name is an explicit action shown only when the
/// typed text doesn't already match a known exercise. Returns the chosen name
/// (existing or new) or null if cancelled.
Future<String?> showExercisePicker(
    BuildContext context, List<String> known) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ExercisePicker(known: known),
  );
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({required this.known});
  final List<String> known;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final matches = q.isEmpty
        ? widget.known
        : widget.known.where((n) => n.toLowerCase().contains(q)).toList();
    final exact = widget.known.any((n) => n.toLowerCase() == q);
    final typed = _ctrl.text.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Cerca un esercizio',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _q = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  if (typed.isNotEmpty && !exact)
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline,
                          color: AppColors.primary),
                      title: Text('Crea nuovo: «$typed»',
                          style: const TextStyle(color: AppColors.primary)),
                      subtitle: const Text(
                          'Solo se non è già nell\'elenco qui sotto'),
                      onTap: () => Navigator.pop(context, typed),
                    ),
                  ...matches.map((n) => ListTile(
                        leading: const Icon(Icons.fitness_center,
                            size: 20, color: AppColors.textSecondary),
                        title: Text(n),
                        onTap: () => Navigator.pop(context, n),
                      )),
                  if (matches.isEmpty && typed.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: Text('Inizia a scrivere per cercare',
                            style: TextStyle(color: AppColors.textSecondary)),
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
