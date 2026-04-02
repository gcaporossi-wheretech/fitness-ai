import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';

/// Card with glassmorphism effect: background blur, luminous border,
/// transparency. Used for exercise cards, stat cards, etc.
class GlassmorphismCard extends StatelessWidget {
  const GlassmorphismCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderColor,
    this.borderRadius,
    this.blurAmount = 10,
    this.opacity = 0.7,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final double? borderRadius;
  final double blurAmount;
  final double opacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppSpacing.radiusMd;
    final border = borderColor ?? AppColors.primary.withValues(alpha: 0.15);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                padding: padding ?? const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: border),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
