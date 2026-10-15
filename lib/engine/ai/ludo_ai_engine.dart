import 'dart:math';

import '../../core/coordinates/board_path_registry.dart';
import '../../models/game_rules.dart';
import '../../models/game_state.dart';
import '../../models/move.dart';
import '../../models/board_position.dart';

/// Heuristic evaluation and autonomous decision service for offline AI bots.
/// Supports 3 difficulty tiers: Easy, Medium, and Grandmaster (Hard).
class LudoAiEngine {
  final Random _random;

  LudoAiEngine({Random? random}) : _random = random ?? Random();

  /// Realistic bot thinking time, scaled by [gameSpeed].
  Duration thinkingDelay({
    int minMs = 550,
    int maxMs = 900,
    double gameSpeed = 1.0,
  }) {
    final rawDelay = minMs + _random.nextInt(maxMs - minMs + 1);
    final adjustedMs = (rawDelay / gameSpeed).clamp(150, 1000).toInt();
    return Duration(milliseconds: adjustedMs);
  }

  /// Selects the best move among [validMoves] using difficulty-adjusted heuristics.
  Move selectBestMove({
    required GameState state,
    required List<Move> validMoves,
  }) {
    assert(validMoves.isNotEmpty, 'Cannot select a move from empty validMoves');
    if (validMoves.length == 1) return validMoves.first;

    final difficulty = state.rules.aiDifficulty;

    // Easy mode: 40% chance to pick a completely random move
    if (difficulty == AiDifficulty.easy && _random.nextDouble() < 0.40) {
      return validMoves[_random.nextInt(validMoves.length)];
    }

    Move bestMove = validMoves.first;
    double highestScore = -double.infinity;

    for (final move in validMoves) {
      final score = evaluateMove(
        state: state,
        move: move,
        difficulty: difficulty,
      );
      if (score > highestScore) {
        highestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  /// Evaluates an individual move using difficulty-specific weights.
  double evaluateMove({
    required GameState state,
    required Move move,
    AiDifficulty difficulty = AiDifficulty.medium,
  }) {
    double score = 0.0;

    switch (difficulty) {
      case AiDifficulty.easy:
        // Basic weights with heavy noise
        if (move.isCapture) score += 60.0;
        if (move.isReachingHome) score += 40.0;
        if (move.isYardExit) score += 20.0;
        score += _random.nextDouble() * 50.0; // High random variance
        break;

      case AiDifficulty.medium:
        // Standard balanced heuristics
        if (move.isCapture) score += 100.0;
        if (move.toPosition is BoardPositionTrack) {
          final dest = (move.toPosition as BoardPositionTrack).trackIndex;
          if (BoardPathRegistry.isSafeTrackIndex(dest)) score += 60.0;
        }
        if (move.isReachingHome) score += 50.0;
        if (_isEscapingThreat(state, move)) score += 40.0;
        if (move.isYardExit) score += 20.0;
        if (move.fromRelativeStep >= 0) {
          score += (move.fromRelativeStep / BoardPathRegistry.totalPathSteps) * 5.0;
        }
        score += _random.nextDouble() * 0.2;
        break;

      case AiDifficulty.hard:
        // Grandmaster tactical heuristics
        if (move.isCapture) score += 160.0;
        if (move.toPosition is BoardPositionTrack) {
          final dest = (move.toPosition as BoardPositionTrack).trackIndex;
          if (BoardPathRegistry.isSafeTrackIndex(dest)) {
            score += 90.0; // Camping on safe squares is highly valued
          } else {
            // Penalty for walking into an opponent's capture range!
            if (_isTileThreatenedByOpponent(
              state: state,
              myColor: move.playerColor,
              trackIndex: dest,
            )) {
              score -= 65.0; // Danger penalty!
            }
          }
        }
        if (move.isReachingHome) score += 75.0;
        if (_isEscapingThreat(state, move)) score += 85.0;
        if (move.isYardExit) score += 30.0;
        if (move.fromRelativeStep >= 0) {
          score += (move.fromRelativeStep / BoardPathRegistry.totalPathSteps) * 15.0;
        }
        score += _random.nextDouble() * 0.05; // Minimal jitter
        break;
    }

    return score;
  }

  bool _isEscapingThreat(GameState state, Move move) {
    if (move.fromPosition is BoardPositionTrack) {
      final fromTrackIndex = (move.fromPosition as BoardPositionTrack).trackIndex;
      if (!BoardPathRegistry.isSafeTrackIndex(fromTrackIndex)) {
        return _isTileThreatenedByOpponent(
          state: state,
          myColor: move.playerColor,
          trackIndex: fromTrackIndex,
        );
      }
    }
    return false;
  }

  bool _isTileThreatenedByOpponent({
    required GameState state,
    required dynamic myColor,
    required int trackIndex,
  }) {
    for (final player in state.players) {
      if (player.color == myColor) continue;
      for (final pawn in player.tokens) {
        if (pawn.isOnTrack) {
          final oppTrack = (pawn.position as BoardPositionTrack).trackIndex;
          final distanceBehind =
              (trackIndex - oppTrack + BoardPathRegistry.totalCommonTiles) %
                  BoardPathRegistry.totalCommonTiles;

          if (distanceBehind >= 1 && distanceBehind <= 6) {
            return true;
          }
        }
      }
    }
    return false;
  }
}
