import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';

/// Animated checkbox for set completion.
/// Pulse + color shift from gray to green.
class AnimatedCheck extends StatefulWidget {
  const AnimatedCheck({
    super.key,
    required this.isChecked,
    required this.onTap,
    this.size = 28,
  });

  final bool isChecked;
  final VoidCallback onTap;
  final double size;

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(AnimatedCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChecked && !oldWidget.isChecked) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(
          widget.isChecked ? Icons.check_circle : Icons.check_circle_outline,
          color: widget.isChecked ? AppColors.success : AppColors.textSecondary,
          size: widget.size,
        ),
      ),
    );
  }
}
