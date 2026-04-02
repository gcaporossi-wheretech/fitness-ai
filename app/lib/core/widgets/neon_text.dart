import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';

/// Text with neon glow effect. Used for personal records,
/// important numbers, premium titles.
class NeonText extends StatelessWidget {
  const NeonText(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.glowIntensity = 0.5,
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final double glowIntensity;

  @override
  Widget build(BuildContext context) {
    final neonColor = color ?? AppColors.success;
    final textStyle = style ?? Theme.of(context).textTheme.displayLarge;

    return Text(
      text,
      style: textStyle?.copyWith(
        color: neonColor,
        shadows: [
          Shadow(
            color: neonColor.withValues(alpha: glowIntensity),
            blurRadius: 10,
          ),
          Shadow(
            color: neonColor.withValues(alpha: glowIntensity * 0.6),
            blurRadius: 20,
          ),
        ],
      ),
    );
  }
}
