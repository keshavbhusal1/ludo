import 'package:flutter/material.dart';
import '../../../models/pawn.dart';

/// Authentic physical-feel Ludo token with gentle bounce animation when movable.
class LudoPawnWidget extends StatefulWidget {
  final Pawn pawn;
  final double size;
  final bool isMovable;
  final VoidCallback? onTap;

  const LudoPawnWidget({
    super.key,
    required this.pawn,
    required this.size,
    this.isMovable = false,
    this.onTap,
  });

  @override
  State<LudoPawnWidget> createState() => _LudoPawnWidgetState();
}

class _LudoPawnWidgetState extends State<LudoPawnWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: -5.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    if (widget.isMovable) {
      _bounceController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant LudoPawnWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMovable && !oldWidget.isMovable) {
      _bounceController.repeat(reverse: true);
    } else if (!widget.isMovable && oldWidget.isMovable) {
      _bounceController.stop();
      _bounceController.reset();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.pawn.color;
    final primaryColor = Color(color.primaryColorValue);
    final darkColor = Color(color.darkColorValue);

    return GestureDetector(
      onTap: widget.isMovable ? widget.onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) {
          final dy = widget.isMovable ? _bounceAnimation.value : 0.0;
          return Transform.translate(
            offset: Offset(0, dy),
            child: child,
          );
        },
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle glowing halo when movable
              if (widget.isMovable)
                Container(
                  width: widget.size * 1.25,
                  height: widget.size * 1.25,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.55),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                      const BoxShadow(
                        color: Colors.white70,
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),

              // Authentic Pawn Token Body
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.35, -0.4),
                    radius: 0.9,
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      primaryColor,
                      darkColor,
                    ],
                    stops: const [0.08, 0.5, 1.0],
                  ),
                  border: Border.all(
                    color: widget.isMovable ? Colors.white : Colors.white.withValues(alpha: 0.9),
                    width: widget.isMovable ? 2.5 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.38),
                      blurRadius: 4,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  // Inner glossy star/pip core
                  child: Container(
                    width: widget.size * 0.44,
                    height: widget.size * 0.44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.95),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: widget.size * 0.22,
                        height: widget.size * 0.22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: darkColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
