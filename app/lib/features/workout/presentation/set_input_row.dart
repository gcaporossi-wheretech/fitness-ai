import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/workout/domain/set_log.dart';
import 'package:fitness_ai/features/workout/presentation/active_session_notifier.dart';

/// Inline set input row (Strong-style).
/// Shows set number, weight/reps inputs, and completion checkbox.
/// Supports weighted, timed, and bodyweight exercise types.
class SetInputRow extends ConsumerStatefulWidget {
  const SetInputRow({
    super.key,
    required this.setLog,
    required this.exerciseType,
    required this.exerciseIndex,
    required this.setIndex,
    required this.onCompleted,
  });

  final SetLog setLog;
  final String exerciseType;
  final int exerciseIndex;
  final int setIndex;
  final VoidCallback onCompleted;

  @override
  ConsumerState<SetInputRow> createState() => _SetInputRowState();
}

class _SetInputRowState extends ConsumerState<SetInputRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  late TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.setLog.weight > 0
          ? _formatWeight(widget.setLog.weight)
          : '',
    );
    _repsController = TextEditingController(
      text: widget.setLog.actualReps > 0
          ? widget.setLog.actualReps.toString()
          : widget.setLog.plannedReps.toString(),
    );
    _durationController = TextEditingController(
      text: widget.setLog.durationSeconds > 0
          ? widget.setLog.durationSeconds.toString()
          : '30',
    );
  }

  @override
  void didUpdateWidget(SetInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers when weight changes externally (e.g., pre-fill)
    if (widget.setLog.weight != oldWidget.setLog.weight &&
        widget.setLog.weight > 0) {
      _weightController.text = _formatWeight(widget.setLog.weight);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  String _formatWeight(double w) {
    return w == w.roundToDouble() ? w.toInt().toString() : w.toString();
  }

  void _completeSet() {
    final notifier = ref.read(activeSessionProvider.notifier);

    switch (widget.exerciseType) {
      case 'weighted':
        final weight = double.tryParse(_weightController.text) ?? 0;
        final reps = int.tryParse(_repsController.text) ?? 0;
        notifier.logSet(
          exerciseIndex: widget.exerciseIndex,
          setIndex: widget.setIndex,
          weight: weight,
          reps: reps,
        );
        break;
      case 'timed':
        final duration = int.tryParse(_durationController.text) ?? 0;
        notifier.logTimedSet(
          exerciseIndex: widget.exerciseIndex,
          setIndex: widget.setIndex,
          durationSeconds: duration,
        );
        break;
      case 'bodyweight':
        final reps = int.tryParse(_repsController.text) ?? 0;
        notifier.logBodyweightSet(
          exerciseIndex: widget.exerciseIndex,
          setIndex: widget.setIndex,
          reps: reps,
        );
        break;
    }

    widget.onCompleted();
  }

  void _undoSet() {
    ref.read(activeSessionProvider.notifier).undoSet(
          exerciseIndex: widget.exerciseIndex,
          setIndex: widget.setIndex,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.setLog.completed;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.success.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          // Set number badge
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                widget.setLog.setNumber.toString(),
                style: TextStyle(
                  color: isCompleted
                      ? AppColors.success
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          // Input fields based on exercise type
          if (widget.exerciseType == 'weighted') ...[
            Expanded(
              child: _CompactInput(
                controller: _weightController,
                enabled: !isCompleted,
                suffix: 'kg',
              ),
            ),
            Expanded(
              child: _CompactInput(
                controller: _repsController,
                enabled: !isCompleted,
              ),
            ),
          ] else if (widget.exerciseType == 'timed') ...[
            Expanded(
              child: _CompactInput(
                controller: _durationController,
                enabled: !isCompleted,
                suffix: 's',
              ),
            ),
          ] else ...[
            // bodyweight
            Expanded(
              child: _CompactInput(
                controller: _repsController,
                enabled: !isCompleted,
              ),
            ),
          ],
          // Completion check
          SizedBox(
            width: 36,
            child: AnimatedCheck(
              isChecked: isCompleted,
              onTap: isCompleted ? _undoSet : _completeSet,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact number input for the set row.
/// Selects all existing text when focused/tapped so a value can be typed
/// over immediately (Strong-style).
class _CompactInput extends StatefulWidget {
  const _CompactInput({
    required this.controller,
    this.enabled = true,
    this.suffix,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? suffix;

  @override
  State<_CompactInput> createState() => _CompactInputState();
}

class _CompactInputState extends State<_CompactInput> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) _selectAll();
  }

  void _selectAll() {
    final text = widget.controller.text;
    if (text.isEmpty) return;
    widget.controller.selection =
        TextSelection(baseOffset: 0, extentOffset: text.length);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onTap: _selectAll,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: widget.enabled
              ? AppColors.textPrimary
              : AppColors.textSecondary,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          filled: true,
          fillColor: widget.enabled
              ? AppColors.bgElevated.withValues(alpha: 0.5)
              : Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            borderSide: BorderSide.none,
          ),
          suffixText: widget.suffix,
          suffixStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
