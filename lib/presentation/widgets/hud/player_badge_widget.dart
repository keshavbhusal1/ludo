import 'package:flutter/material.dart';

import '../../../models/player.dart';
import '../../../models/player_color.dart';

/// Compact, elegant player badge anchored at quadrant corners.
/// Displays player identity, home progress, and active turn glow, and marks
/// seats played by a bot: a robot icon for bot seats, and an AUTO tag for a
/// human seat a bot took over after too many turn timeouts. Tapping a
/// taken-over badge calls [onReclaim].
class PlayerBadgeWidget extends StatelessWidget {
  final Player player;
  final bool isActive;
  final int tokensRequired;

  /// Called when a taken-over seat's badge is tapped; null disables it.
  final VoidCallback? onReclaim;

  const PlayerBadgeWidget({
    super.key,
    required this.player,
    required this.isActive,
    this.tokensRequired = 4,
    this.onReclaim,
  });

  @override
  Widget build(BuildContext context) {
    final color = player.color;
    final primaryColor = Color(color.primaryColorValue);
    final hasWon = player.finishedPawnCount >= tokensRequired;
    final isTakenOver = player.isBotControlled && !player.isAi;
    final canReclaim = isTakenOver && onReclaim != null;

    final seat = isTakenOver
        ? '${player.name}, played by a bot after timing out'
        : (player.isAi ? '${player.name}, bot' : player.name);
    final progress = hasWon
        ? 'won'
        : '${player.finishedPawnCount} of $tokensRequired tokens home';

    return Semantics(
      label: '$seat, $progress',
      // The label above says everything the visible text does
      excludeSemantics: true,
      button: canReclaim,
      onTap: canReclaim ? onReclaim : null,
      onTapHint: canReclaim ? 'take back the seat' : null,
      child: GestureDetector(
        onTap: canReclaim ? onReclaim : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? primaryColor.withValues(alpha: 0.22)
                : const Color(0xFF1E293B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? primaryColor
                  : Colors.white.withValues(alpha: 0.12),
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
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 7),

              // Name: the only part that shortens when space is tight; the
              // color pip and markers always stay visible.
              Flexible(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
                    color: isActive ? Colors.white : const Color(0xFFCBD5E1),
                  ),
                ),
              ),

              // Bot marker: a robot for bot seats; the AUTO tag (below) for a
              // human seat a bot took over.
              if (player.isAi) ...[
                const SizedBox(width: 4),
                const Icon(Icons.smart_toy, size: 13, color: Color(0xFF94A3B8)),
              ],
              if (isTakenOver) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: canReclaim
                      ? 'A bot is playing this seat after timeouts — tap to take it back'
                      : 'Timed out too many times — a bot is playing this seat',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: primaryColor, width: 1),
                    ),
                    child: Text(
                      'AUTO',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ),
              ],

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
                  hasWon
                      ? '🏆 Won'
                      : '${player.finishedPawnCount}/$tokensRequired',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: hasWon ? Colors.white : const Color(0xFF94A3B8),
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

/// Two badges at opposite corners of a row (absent seats leave a gap). When
/// space is tight each badge may shrink, shortening its name instead of
/// overflowing.
class PlayerBadgeRow extends StatelessWidget {
  final Player? left;
  final Player? right;
  final PlayerColor activeColor;
  final int tokensRequired;

  /// Called with a taken-over seat's color when its badge is tapped.
  final ValueChanged<PlayerColor>? onReclaim;

  const PlayerBadgeRow({
    super.key,
    required this.left,
    required this.right,
    required this.activeColor,
    this.tokensRequired = 4,
    this.onReclaim,
  });

  @override
  Widget build(BuildContext context) {
    Widget badge(Player? p) => p == null
        ? const SizedBox.shrink()
        : PlayerBadgeWidget(
            player: p,
            isActive: p.color == activeColor,
            tokensRequired: tokensRequired,
            onReclaim: onReclaim == null ? null : () => onReclaim!(p.color),
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: badge(left)),
        const SizedBox(width: 8),
        Flexible(child: badge(right)),
      ],
    );
  }
}
