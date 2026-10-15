import 'package:flutter/material.dart';
import '../../../models/player.dart';
import '../dice/animated_dice_widget.dart';

/// Clean, human-centric Player Station anchored adjacent to the player's yard corner.
/// Houses player identity, home progress, and the embedded dice.
class PlayerStationWidget extends StatelessWidget {
  final Player player;
  final bool isActive;
  final int? currentDiceRoll;
  final bool isRolling;
  final bool isDiceEnabled;
  final VoidCallback? onRollPressed;
  final int tokensRequired;

  const PlayerStationWidget({
    super.key,
    required this.player,
    required this.isActive,
    required this.currentDiceRoll,
    this.isRolling = false,
    this.isDiceEnabled = false,
    this.onRollPressed,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? primaryColor.withValues(alpha: 0.18)
            : const Color(0xFF1E293B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? primaryColor : Colors.white.withValues(alpha: 0.12),
          width: isActive ? 2.2 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Player Avatar & Meta
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    player.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                      color: isActive ? Colors.white : const Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    player.isAi ? Icons.smart_toy : Icons.person,
                    size: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasWon
                        ? '🏆 Won'
                        : '${player.finishedPawnCount}/$tokensRequired Home',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: hasWon ? FontWeight.bold : FontWeight.w500,
                      color: hasWon ? const Color(0xFFFBBF24) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Embedded Corner Dice
          AnimatedDiceWidget(
            value: isActive ? currentDiceRoll : null,
            playerColor: color,
            isEnabled: isDiceEnabled,
            isRolling: isRolling && isActive,
            onRollPressed: onRollPressed,
            size: 46,
          ),
        ],
      ),
    );
  }
}
