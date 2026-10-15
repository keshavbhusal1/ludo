import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/services/haptics_service.dart';
import '../../../models/player.dart';

/// Full-screen dramatic 3D dice rolling overlay.
///
/// Features:
/// - Translucent backdrop blur covering the screen.
/// - Large, high-impact 3D tumbling dice (~130dp) with multi-axis rotation.
/// - Rapid face cycling (1..6) and scale bounce on settling.
/// - Outcome banner announcing the roll result.
class FullScreenDiceRollOverlay extends StatefulWidget {
  final Player activePlayer;
  final int finalRoll;
  final VoidCallback onComplete;
  final double gameSpeed;

  const FullScreenDiceRollOverlay({
    super.key,
    required this.activePlayer,
    required this.finalRoll,
    required this.onComplete,
    this.gameSpeed = 1.0,
  });

  @override
  State<FullScreenDiceRollOverlay> createState() => _FullScreenDiceRollOverlayState();
}

class _FullScreenDiceRollOverlayState extends State<FullScreenDiceRollOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;
  late final Animation<double> _fadeAnimation;
  int _displayedValue = 1;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _displayedValue = _random.nextInt(6) + 1;

    final durationMs = (750 / widget.gameSpeed).clamp(350, 850).toInt();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 1.25).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 0.92).chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.92, end: 1.0).chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 30,
      ),
    ]).animate(_controller);

    _rotationAnimation = Tween<double>(begin: 0.0, end: 4 * pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
      ),
    );

    _controller.addListener(() {
      // Rapidly cycle face pips during active rolling
      if (_controller.value < 0.75) {
        if (_random.nextInt(3) == 0) {
          HapticsService.diceRoll();
          setState(() {
            _displayedValue = _random.nextInt(6) + 1;
          });
        }
      } else {
        // Settle on final roll
        if (_displayedValue != widget.finalRoll) {
          HapticsService.pawnHop();
          setState(() {
            _displayedValue = widget.finalRoll;
          });
        }
      }
    });

    _controller.forward().then((_) async {
      final settleMs = (250 / widget.gameSpeed).toInt();
      await Future.delayed(Duration(milliseconds: settleMs));
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(widget.activePlayer.color.primaryColorValue);
    final isSix = widget.finalRoll == 6;

    return Positioned.fill(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.black.withValues(alpha: 0.65),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Active player rolling announcement
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.activePlayer.isAi ? Icons.smart_toy : Icons.person,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${widget.activePlayer.name}'s Roll",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Large 3D Tumbling Dice
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final rot = _rotationAnimation.value;
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // 3D Perspective
                          ..rotateX(rot * 0.7)
                          ..rotateY(rot * 0.5)
                          ..rotateZ(rot * 0.3),
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: primaryColor,
                              width: 4.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 10),
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
                            padding: const EdgeInsets.all(22.0),
                            child: CustomPaint(
                              painter: _LargeDicePipPainter(
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

                const SizedBox(height: 32),

                // Result Banner
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _controller.value >= 0.75 ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSix ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSix ? Colors.white : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      isSix ? 'ROLLED A 6! EXTRA TURN 🎉' : 'ROLLED ${widget.finalRoll}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LargeDicePipPainter extends CustomPainter {
  final int value;
  final Color pipColor;

  _LargeDicePipPainter({required this.value, required this.pipColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = pipColor
      ..style = PaintingStyle.fill;

    final double pipRadius = size.width * 0.12;
    final double left = pipRadius * 1.3;
    final double mid = size.width / 2;
    final double right = size.width - (pipRadius * 1.3);

    final double top = pipRadius * 1.3;
    final double center = size.height / 2;
    final double bottom = size.height - (pipRadius * 1.3);

    void draw(double x, double y) {
      canvas.drawCircle(Offset(x, y), pipRadius, paint);
      // 3D Specular highlight
      canvas.drawCircle(
        Offset(x - pipRadius * 0.28, y - pipRadius * 0.28),
        pipRadius * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
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
  bool shouldRepaint(covariant _LargeDicePipPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.pipColor != pipColor;
}
