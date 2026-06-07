import 'package:flutter/material.dart';

import 'package:fitness_ai/core/services/rest_timer_service.dart';
import 'package:fitness_ai/core/theme/app_colors.dart';
import 'package:fitness_ai/core/theme/app_spacing.dart';

/// Slim, always-visible rest-timer bar shown at the top of the active workout
/// while a rest countdown runs. Unlike a blocking overlay it does NOT cover the
/// exercise list, so the user can keep reviewing/scrolling their sets while the
/// timer keeps running. Auto-hides when the timer finishes or is skipped.
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({
    super.key,
    required this.timer,
    required this.onSkip,
    required this.onAddThirty,
    this.exerciseName,
    this.currentSet,
    this.totalSets,
  });

  final RestTimerService timer;
  final VoidCallback onSkip;
  final VoidCallback onAddThirty;
  final String? exerciseName;
  final int? currentSet;
  final int? totalSets;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: timer,
      builder: (context, _) {
        // Hide when there is nothing to count down.
        if (!timer.isRunning && timer.remainingSeconds == 0) {
          return const SizedBox.shrink();
        }

        final danger = timer.remainingSeconds <= 5;
        final accent = danger ? AppColors.warning : AppColors.primary;
        final remainingFraction = timer.totalSeconds > 0
            ? (timer.remainingSeconds / timer.totalSeconds).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: accent, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  // Fixed-width countdown (mm:ss) so the row height never jumps.
                  Text(
                    timer.formattedTime,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color:
                          danger ? AppColors.warning : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Single, non-wrapping label (truncates instead of wrapping).
                  Expanded(
                    child: Text(
                      exerciseName != null && currentSet != null
                          ? 'Recupero · Serie $currentSet/$totalSets'
                          : 'Recupero',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MiniButton(
                      label: '+30s',
                      color: AppColors.primary,
                      onTap: onAddThirty),
                  const SizedBox(width: 6),
                  _MiniButton(
                      label: 'Salta',
                      color: AppColors.textSecondary,
                      onTap: onSkip),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: remainingFraction,
                  minHeight: 5,
                  backgroundColor: AppColors.bgElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact pill button used inside the rest-timer bar.
class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
