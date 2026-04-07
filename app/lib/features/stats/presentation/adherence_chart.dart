import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';
import 'package:fitness_ai/core/widgets/widgets.dart';
import 'package:fitness_ai/features/workout/domain/workout_session.dart';

/// Radial chart showing workout adherence (completed vs planned sessions).
/// Ring color: green (>=80%), yellow (>=60%), red (<60%).
class AdherenceChart extends StatelessWidget {
  const AdherenceChart({
    super.key,
    required this.sessions,
    this.sessionsPerWeek = 5,
  });

  final List<WorkoutSession> sessions;

  /// Expected sessions per week for adherence calculation.
  final int sessionsPerWeek;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final completedCount = sessions.where((s) => s.isCompleted).length;

    if (sessions.isEmpty) {
      return const GlassmorphismCard(
        child: Text(
          'No adherence data available.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final earliest =
        sessions.map((s) => s.startedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final daysSinceStart = now.difference(earliest).inDays + 1;
    final weeksSinceStart = (daysSinceStart / 7).ceil();
    final plannedSessions = weeksSinceStart * sessionsPerWeek;
    final adherence = plannedSessions > 0
        ? (completedCount / plannedSessions).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (adherence * 100).round();

    final ringColor = adherence >= 0.8
        ? AppColors.success
        : adherence >= 0.6
            ? AppColors.warning
            : AppColors.error;

    return GlassmorphismCard(
      child: Row(
        children: [
          // Ring chart
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _AdherenceRingPainter(
                progress: adherence,
                color: ringColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: ringColor,
                      ),
                    ),
                    const Text(
                      'adherence',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatRow(
                  label: 'Completed',
                  value: '$completedCount',
                  color: AppColors.success,
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatRow(
                  label: 'Planned',
                  value: '$plannedSessions',
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.sm),
                _StatRow(
                  label: 'Active weeks',
                  value: '$weeksSinceStart',
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AdherenceRingPainter extends CustomPainter {
  _AdherenceRingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 8.0;

    // Background ring
    final bgPaint = Paint()
      ..color = AppColors.bgElevated
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
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
  bool shouldRepaint(covariant _AdherenceRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
