import 'dart:math';
import 'package:flutter/material.dart';

/// Lightweight custom canvas particle confetti celebration overlay.
class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool isPlaying;

  const ConfettiOverlay({
    super.key,
    required this.child,
    required this.isPlaying,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    if (widget.isPlaying) {
      _startBurst();
    }
  }

  void _startBurst() {
    _particles.clear();
    const colors = [
      Color(0xFFEF4444),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
    ];

    for (int i = 0; i < 90; i++) {
      _particles.add(_ConfettiParticle(
        color: colors[_random.nextInt(colors.length)],
        x: _random.nextDouble(),
        y: -0.1 - (_random.nextDouble() * 0.3),
        vx: (_random.nextDouble() - 0.5) * 0.008,
        vy: 0.006 + (_random.nextDouble() * 0.012),
        size: 5.0 + (_random.nextDouble() * 7.0),
        angle: _random.nextDouble() * 2 * pi,
        vAngle: (_random.nextDouble() - 0.5) * 0.15,
      ));
    }

    _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _startBurst();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller.stop();
      _particles.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.isPlaying && _particles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiParticle {
  final Color color;
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double angle;
  double vAngle;

  _ConfettiParticle({
    required this.color,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.angle,
    required this.vAngle,
  });

  void update() {
    x += vx;
    y += vy;
    angle += vAngle;
    if (y > 1.2) {
      y = -0.1;
      x = Random().nextDouble();
    }
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      p.update();
      final paint = Paint()..color = p.color;
      final px = p.x * size.width;
      final py = p.y * size.height;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.angle);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
