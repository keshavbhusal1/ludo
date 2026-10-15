import 'package:flutter/material.dart';
import '../../../models/player.dart';

/// Compact, elegant player badge anchored at quadrant corners.
/// Displays player identity, home progress, and active turn glow.
class PlayerBadgeWidget extends StatelessWidget {
  final Player player;
  final bool isActive;
  final int tokensRequired;

  const PlayerBadgeWidget({
    super.key,
    required this.player,
    required this.isActive,
    this.tokensRequired = 4,
  });

  @override
  Widget build(BuildContext context) {
    final color = player.color;
    final primaryColor = Color(color.primaryColorValue);
    final hasWon = player.finishedPawnCount >= tokensRequired;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? primaryColor.withValues(alpha: 0.22)
            : const Color(0xFF1E293B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? primaryColor : Colors.white.withValues(alpha: 0.12),
          width: isActive ? 2.0 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player Color Pip / Avatar
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: primaryColor,
                        blurRadius: 5,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 7),

          // Name
          Text(
            player.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
              color: isActive ? Colors.white : const Color(0xFFCBD5E1),
            ),
          ),

          const SizedBox(width: 8),

          // Progress Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: hasWon
                  ? const Color(0xFFF59E0B)
                  : Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              hasWon ? '🏆 Won' : '${player.finishedPawnCount}/$tokensRequired',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: hasWon ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
