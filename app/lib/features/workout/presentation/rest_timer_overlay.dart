import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:fitness_ai/core/services/rest_timer_service.dart';
import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';

/// Full-screen rest timer overlay with animated progress ring.
/// Shows countdown between sets with skip and +30s controls.
class RestTimerOverlay extends StatelessWidget {
  const RestTimerOverlay({
    super.key,
    required this.timer,
    required this.onSkip,
    required this.onAddThirty,
    required this.onDismiss,
    this.exerciseName,
    this.currentSet,
    this.totalSets,
  });

  final RestTimerService timer;
  final VoidCallback onSkip;
  final VoidCallback onAddThirty;
  final VoidCallback onDismiss;
  final String? exerciseName;
  final int? currentSet;
  final int? totalSets;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: timer,
      builder: (context, _) {
        if (!timer.isRunning && timer.remainingSeconds == 0) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onDismiss,
          child: Container(
            color: AppColors.bgPrimary.withValues(alpha: 0.95),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'RECUPERO',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 2,
                        ),
                  ),
                  if (exerciseName != null && currentSet != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Serie $currentSet/$totalSets - $exerciseName',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  // Progress ring with countdown
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(200, 200),
                          painter: _TimerRingPainter(
                            progress: timer.progress,
                            backgroundColor: AppColors.bgElevated,
                            progressColor: timer.remainingSeconds <= 5
                                ? AppColors.warning
                                : AppColors.primary,
                          ),
                        ),
                        Text(
                          timer.formattedTime,
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: timer.remainingSeconds <= 5
                                ? AppColors.warning
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TimerButton(
                        label: 'Salta',
                        icon: Icons.skip_next,
                        color: AppColors.textSecondary,
                        onPressed: onSkip,
                      ),
                      const SizedBox(width: AppSpacing.xl),
                      _TimerButton(
                        label: '+30s',
                        icon: Icons.add,
                        color: AppColors.primary,
                        onPressed: onAddThirty,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimerButton extends StatelessWidget {
  const _TimerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the timer progress ring.
class _TimerRingPainter extends CustomPainter {
  _TimerRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 6.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}
