import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';

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
