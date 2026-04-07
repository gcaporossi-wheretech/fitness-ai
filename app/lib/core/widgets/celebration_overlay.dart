import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:fitness_ai/core/theme/app_colors.dart';

/// Overlay with colored particle animation for workout completion.
/// Shows a burst of confetti-like particles that fade out over 2.5 seconds.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key, required this.onComplete});

  /// Called when the celebration animation finishes.
  final VoidCallback onComplete;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(
      50,
      (_) => _Particle(
        x: _random.nextDouble(),
        y: -_random.nextDouble() * 0.3,
        speedX: (_random.nextDouble() - 0.5) * 0.02,
        speedY: _random.nextDouble() * 0.01 + 0.005,
        size: _random.nextDouble() * 6 + 4,
        color: [
          AppColors.primary,
          AppColors.success,
          AppColors.warning,
          const Color(0xFFFF6B6B),
          const Color(0xFF9B59B6),
        ][_random.nextInt(5)],
      ),
    );

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete();
        }
      });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AnimBuilder(
      listenable: _controller,
      builder: (context, _) {
        return IgnorePointer(
          child: CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ParticlePainter(
              particles: _particles,
              progress: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class _AnimBuilder extends AnimatedWidget {
  const _AnimBuilder({
    required super.listenable,
    required this.builder,
  });

  final Widget Function(BuildContext context, Widget? child) builder;

  @override
  Widget build(BuildContext context) => builder(context, null);
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.size,
    required this.color,
  });

  double x;
  double y;
  final double speedX;
  final double speedY;
  final double size;
  final Color color;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = progress < 0.7 ? 1.0 : (1.0 - progress) / 0.3;

    for (final p in particles) {
      final x = (p.x + p.speedX * progress * 60) * size.width;
      final y = (p.y + p.speedY * progress * 60) * size.height;

      if (y > size.height || x < 0 || x > size.width) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), p.size * (1 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
