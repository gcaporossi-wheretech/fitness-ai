import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';

/// Large readable number for gym use. Used for weights (kg),
/// reps, timer. Minimum 28px as per design system.
class BigNumber extends StatelessWidget {
  const BigNumber(
    this.value, {
    super.key,
    this.unit,
    this.color,
    this.fontSize = 36,
  });

  final String value;
  final String? unit;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: color ?? AppColors.textPrimary,
                fontSize: fontSize,
              ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 4),
          Text(
            unit!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: fontSize * 0.4,
                ),
          ),
        ],
      ],
    );
  }
}
