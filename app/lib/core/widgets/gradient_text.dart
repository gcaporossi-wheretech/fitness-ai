import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';

/// Text with hero gradient (blue -> green). Used for app titles
/// and premium headings.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient,
  });

  final String text;
  final TextStyle? style;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? Theme.of(context).textTheme.headlineMedium;

    return ShaderMask(
      shaderCallback: (bounds) =>
          (gradient ?? AppColors.heroGradient).createShader(bounds),
      child: Text(
        text,
        style: textStyle?.copyWith(color: Colors.white),
      ),
    );
  }
}
