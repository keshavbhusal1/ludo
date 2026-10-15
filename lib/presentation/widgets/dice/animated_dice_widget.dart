import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/player_color.dart';

/// 3D rounded animated dice with pip dots and physics-based roll animations.
class AnimatedDiceWidget extends StatefulWidget {
  final int? value;
  final PlayerColor playerColor;
  final bool isEnabled;
  final bool isRolling;
  final VoidCallback? onRollPressed;
  final VoidCallback? onDisabledTap;
  final double size;

  const AnimatedDiceWidget({
    super.key,
    required this.value,
    required this.playerColor,
    this.isEnabled = true,
    this.isRolling = false,
    this.onRollPressed,
    this.onDisabledTap,
    this.size = 64.0,
  });

  @override
  State<AnimatedDiceWidget> createState() => _AnimatedDiceWidgetState();
}

class _AnimatedDiceWidgetState extends State<AnimatedDiceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _scaleAnimation;
  int _displayedValue = 1;

  @override
  void initState() {
    super.initState();
    _displayedValue = widget.value ?? 1;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 0.95), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 1.0), weight: 20),
    ]).animate(_controller);

    _controller.addListener(() {
      if (_controller.isAnimating && _controller.value < 0.8) {
        setState(() {
          _displayedValue = (Random().nextInt(6) + 1);
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedDiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRolling && !oldWidget.isRolling) {
      _controller.forward(from: 0.0).then((_) {
        setState(() {
          _displayedValue = widget.value ?? 1;
        });
      });
    } else if (widget.value != null && widget.value != oldWidget.value && !_controller.isAnimating) {
      setState(() {
        _displayedValue = widget.value!;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(widget.playerColor.primaryColorValue);

    return GestureDetector(
      onTap: () {
        if (widget.isRolling) return;
        if (widget.isEnabled) {
          widget.onRollPressed?.call();
        } else {
          widget.onDisabledTap?.call();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(widget.size * 0.24),
                  border: Border.all(
                    color: widget.isEnabled ? primaryColor : const Color(0xFFCBD5E1),
                    width: widget.isEnabled ? 3.0 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isEnabled
                          ? primaryColor.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.15),
                      blurRadius: widget.isEnabled ? 12 : 6,
                      spreadRadius: widget.isEnabled ? 2 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey.shade100,
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.size * 0.16),
                  child: CustomPaint(
                    painter: _DicePipPainter(
                      value: _displayedValue,
                      pipColor: primaryColor,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DicePipPainter extends CustomPainter {
  final int value;
  final Color pipColor;

  _DicePipPainter({required this.value, required this.pipColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = pipColor
      ..style = PaintingStyle.fill;

    final double pipRadius = size.width * 0.12;
    final double left = pipRadius * 1.2;
    final double mid = size.width / 2;
    final double right = size.width - pipRadius * 1.2;

    final double top = pipRadius * 1.2;
    final double center = size.height / 2;
    final double bottom = size.height - pipRadius * 1.2;

    void draw(double x, double y) {
      canvas.drawCircle(Offset(x, y), pipRadius, paint);
      // Small 3D specular highlight on dot
      canvas.drawCircle(
        Offset(x - pipRadius * 0.25, y - pipRadius * 0.25),
        pipRadius * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
    }

    switch (value) {
      case 1:
        draw(mid, center);
        break;
      case 2:
        draw(left, top);
        draw(right, bottom);
        break;
      case 3:
        draw(left, top);
        draw(mid, center);
        draw(right, bottom);
        break;
      case 4:
        draw(left, top);
        draw(right, top);
        draw(left, bottom);
        draw(right, bottom);
        break;
      case 5:
        draw(left, top);
        draw(right, top);
        draw(mid, center);
        draw(left, bottom);
        draw(right, bottom);
        break;
      case 6:
        draw(left, top);
        draw(right, top);
        draw(left, center);
        draw(right, center);
        draw(left, bottom);
        draw(right, bottom);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DicePipPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.pipColor != pipColor;
}
