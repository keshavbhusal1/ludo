import '../core/coordinates/board_path_registry.dart';
import '../models/board_position.dart';
import '../models/game_config.dart';
import '../models/game_rules.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/player.dart';
import '../models/player_color.dart';

/// Pure, deterministic Ludo rules engine.
///
/// Holds no state and no randomness: every operation takes a [GameState] and
/// returns the next one. Callers own the state and supply dice values.
///
/// FSM: waitingForRoll -> waitingForSelection -> (executeMove) -> waitingForRoll ... -> gameOver
/// - 3-consecutive-sixes forfeiture (limit configurable)
/// - Extra rolls for rolling 6, capturing an opponent, or reaching Home
/// - Optional mandatory kill before entering the home column
/// - Safe tile coexistence on [1, 9, 14, 22, 27, 35, 40, 48]
/// - Exact roll required to reach Home
/// - Turn passes automatically when there are 0 legal moves
/// - Turn-timeout strikes, with a bot taking over the seat at the limit
///
/// The engine never plays a move by itself, even when only one is legal:
/// choosing (and animating) moves is the caller's job.
class LudoEngine {
  const LudoEngine();

  /// Creates a new match for 2 to 4 players. [config] takes precedence over [rules].
  GameState newGame({
    required List<PlayerColor> colors,
    Map<PlayerColor, bool>? aiConfig,
    GameConfig? config,
    GameRules rules = const GameRules(),
    String? gameId,
  }) {
    return GameState.initial(
      colors: colors,
      aiConfig: aiConfig,
      config: config,
      rules: rules,
      gameId: gameId,
    );
  }

  /// Applies dice [roll] (1..6) for the active player.
  ///
  /// Returns [state] unchanged if it isn't waiting for a roll.
  GameState rollDice(GameState state, int roll) {
    if (state.fsmState != LudoFsmState.waitingForRoll || state.isGameOver) {
      return state;
    }
    if (roll < 1 || roll > 6) {
      throw ArgumentError.value(roll, 'roll', 'Dice roll must be between 1 and 6');
    }

    final isSix = roll == 6;
    final newConsecutiveSixes = isSix ? state.consecutiveSixesCount + 1 : 0;

    // RULE: hitting the consecutive-sixes limit forfeits the turn immediately
    if (newConsecutiveSixes >= state.config.consecutiveSixesLimit) {
      return state.copyWith(
        lastDiceRoll: roll,
        consecutiveSixesCount: 0,
        validMoves: const [],
        activePlayerIndex: _findNextActivePlayerIndex(state, state.players),
        fsmState: LudoFsmState.waitingForRoll,
      );
    }

    final validMoves = calculateValidMoves(
      state: state,
      player: state.activePlayer,
      diceRoll: roll,
    );

    // RULE: 0 legal moves -> turn passes, and the sixes streak ends with it
    if (validMoves.isEmpty) {
      return state.copyWith(
        lastDiceRoll: roll,
        consecutiveSixesCount: 0,
        validMoves: const [],
        activePlayerIndex: _findNextActivePlayerIndex(state, state.players),
        fsmState: LudoFsmState.waitingForRoll,
      );
    }

    return state.copyWith(
      lastDiceRoll: roll,
      consecutiveSixesCount: newConsecutiveSixes,
      validMoves: validMoves,
      fsmState: LudoFsmState.waitingForSelection,
    );
  }

  /// Generates all legal moves for [player] given [diceRoll].
  List<Move> calculateValidMoves({
    required GameState state,
    required Player player,
    required int diceRoll,
  }) {
    final requiredTokens = state.config.mode.tokensToWin;
    if (player.finishedTokenCount >= requiredTokens) return const [];

    final moves = <Move>[];

    for (final token in player.tokens) {
      if (token.isGoal) continue;

      // --- Case 1: Token is in Base/Yard ---
      if (token.isInBase) {
        final canUnlock = diceRoll == state.config.mode.unlockRoll ||
            (state.config.unlockYardOnOneOrSix && (diceRoll == 1 || diceRoll == 6));

        if (canUnlock) {
          final yardSlotPos =
              BoardPathRegistry.yardSlots[player.color]![token.index];
          final startCoord =
              BoardPathRegistry.commonTrack[player.color.startTrackIndex];

          moves.add(Move(
            pawnId: token.id,
            playerColor: player.color,
            diceRoll: diceRoll,
            fromPosition: token.position,
            toPosition: BoardPosition.track(
              trackIndex: player.color.startTrackIndex,
              relativeStep: 0,
            ),
            fromRelativeStep: -1,
            toRelativeStep: 0,
            isYardExit: true,
            grantsExtraTurn: diceRoll == 6,
            trajectory: [yardSlotPos, startCoord],
          ));
        }
        continue;
      }

      // --- Case 2: Token is on Track or Home Column ---
      final currentStep = token.relativeStep;
      final targetStep = currentStep + diceRoll;

      // RULE: Enforce exact dice roll to reach the final Home index (relativeStep 56)
      if (targetStep > BoardPathRegistry.totalPathSteps) {
        continue;
      }

      // RULE: Check hasKilledOpponent boolean flag before permitting entry into the Home column
      if (state.config.mustCaptureBeforeHome &&
          !player.hasKilledOpponent &&
          targetStep > 50) {
        continue;
      }

      // Determine destination position & capture resolution
      late final BoardPosition targetPosition;
      bool isReachingHome = false;
      bool isCapture = false;
      String? capturedPawnId;

      if (targetStep <= 50) {
        // Still on common track
        final targetTrackIndex =
            (player.color.startTrackIndex + targetStep) % BoardPathRegistry.totalCommonTiles;

        targetPosition = BoardPosition.track(
          trackIndex: targetTrackIndex,
          relativeStep: targetStep,
        );

        // RULE: Safe squares allow safe coexistence (no capture).
        // Landing on a non-safe square with an opponent token sends it back to Base.
        if (!BoardPathRegistry.isSafeTrackIndex(targetTrackIndex)) {
          for (final otherPlayer in state.players) {
            if (otherPlayer.color == player.color) continue;
            for (final opponentToken in otherPlayer.tokens) {
              if (opponentToken.isOnTrack) {
                final pos = opponentToken.position as BoardPositionTrack;
                if (pos.trackIndex == targetTrackIndex) {
                  isCapture = true;
                  capturedPawnId = opponentToken.id;
                  break;
                }
              }
            }
            if (isCapture) break;
          }
        }
      } else if (targetStep <= 55) {
        // In colored 5-tile home column (indices 0 to 4)
        targetPosition = BoardPosition.homeColumn(
          columnStep: targetStep - 51,
        );
      } else {
        // Final Goal / Home Tile (index 5 / step 56)
        targetPosition = const BoardPosition.goal();
        isReachingHome = true;
      }

      final trajectory = BoardPathRegistry.getTrajectoryCoordinates(
        player.color,
        currentStep,
        targetStep,
      );

      // RULE: A roll of 6, a token capture, or a token reaching Home grants an extra roll
      final grantsExtraTurn = diceRoll == 6 || isCapture || isReachingHome;

      moves.add(Move(
        pawnId: token.id,
        playerColor: player.color,
        diceRoll: diceRoll,
        fromPosition: token.position,
        toPosition: targetPosition,
        fromRelativeStep: currentStep,
        toRelativeStep: targetStep,
        isCapture: isCapture,
        capturedPawnId: capturedPawnId,
        isReachingHome: isReachingHome,
        grantsExtraTurn: grantsExtraTurn,
        trajectory: trajectory,
      ));
    }

    return moves;
  }

  /// Applies [move]: updates tokens, resolves captures, checks victory, and
  /// advances the turn.
  ///
  /// Returns [state] unchanged if it isn't awaiting a selection or [move] isn't
  /// one of its legal moves.
  GameState executeMove(GameState state, Move move) {
    if (state.fsmState != LudoFsmState.waitingForSelection &&
        state.fsmState != LudoFsmState.movingToken) {
      return state;
    }
    if (!state.validMoves.contains(move)) return state;

    final activePlayer = state.activePlayer;

    // 1. Update the moving token
    final updatedTokens = activePlayer.tokens.map((t) {
      if (t.id == move.pawnId) {
        return t.copyWith(position: move.toPosition);
      }
      return t;
    }).toList();

    // 2. Resolve captures across opponent players
    final updatedPlayers = <Player>[];
    for (final player in state.players) {
      if (player.color == activePlayer.color) {
        updatedPlayers.add(player.copyWith(
          tokens: updatedTokens,
          hasKilledOpponent: player.hasKilledOpponent || move.isCapture,
        ));
      } else {
        // If an opponent token was captured, reset it to base
        final opponentTokens = player.tokens.map((oppToken) {
          if (move.isCapture && oppToken.id == move.capturedPawnId) {
            return oppToken.copyWith(
              position: BoardPosition.base(oppToken.index),
            );
          }
          return oppToken;
        }).toList();

        updatedPlayers.add(player.copyWith(tokens: opponentTokens));
      }
    }

    // 3. Check rankings & victory condition against tokensToWin
    final requiredTokens = state.config.mode.tokensToWin;
    final updatedRankings = List<PlayerColor>.from(state.rankings);
    final currentActiveUpdated =
        updatedPlayers.firstWhere((p) => p.color == activePlayer.color);

    final hasPlayerWon = currentActiveUpdated.finishedTokenCount >= requiredTokens;
    if (hasPlayerWon && !updatedRankings.contains(currentActiveUpdated.color)) {
      updatedRankings.add(currentActiveUpdated.color);
    }

    // Check if match is concluded
    final unfinishedPlayers = updatedPlayers
        .where((p) => p.finishedTokenCount < requiredTokens)
        .toList();
    if (unfinishedPlayers.length <= 1) {
      for (final p in unfinishedPlayers) {
        if (!updatedRankings.contains(p.color)) {
          updatedRankings.add(p.color);
        }
      }

      return state.copyWith(
        players: updatedPlayers,
        rankings: updatedRankings,
        fsmState: LudoFsmState.gameOver,
        validMoves: const [],
        clearDiceRoll: true,
        clearAnimatingMove: true,
      );
    }

    // 4. Determine turn continuation
    final getsExtraTurn = move.grantsExtraTurn && !hasPlayerWon;

    return state.copyWith(
      players: updatedPlayers,
      rankings: updatedRankings,
      activePlayerIndex: getsExtraTurn
          ? state.activePlayerIndex
          : _findNextActivePlayerIndex(state, updatedPlayers),
      fsmState: LudoFsmState.waitingForRoll,
      consecutiveSixesCount:
          getsExtraTurn && move.diceRoll == 6 ? state.consecutiveSixesCount : 0,
      validMoves: const [],
      clearDiceRoll: true,
      clearAnimatingMove: true,
    );
  }

  /// Records an expired turn timer against the active player: one strike,
  /// and at the configured maximum the seat is marked disconnected (from then
  /// on [Player.isBotControlled]). A maximum of 0 never takes the seat.
  ///
  /// The turn itself is unchanged: the caller plays it automatically.
  GameState handleTurnTimeout(GameState state) {
    if (state.isGameOver) return state;

    final active = state.activePlayer;
    final updatedStrikes = active.strikes + 1;
    final maxStrikes = state.config.timerConfig.maxStrikes;
    final isDisconnected = active.isDisconnected ||
        (maxStrikes > 0 && updatedStrikes >= maxStrikes);

    return state.copyWith(
      players: [
        for (final p in state.players)
          p.color == active.color
              ? p.copyWith(strikes: updatedStrikes, isDisconnected: isDisconnected)
              : p,
      ],
    );
  }

  /// Hands a seat a bot took over (after timeouts) back to its human, with
  /// strikes reset so one more timeout doesn't immediately re-take it.
  ///
  /// Returns [state] unchanged for seats that weren't taken over, including
  /// seats that were bots from the start.
  GameState reclaimSeat(GameState state, PlayerColor color) {
    final player = state.getPlayer(color);
    if (player == null || player.isAi || !player.isDisconnected || state.isGameOver) {
      return state;
    }
    return state.copyWith(
      players: [
        for (final p in state.players)
          p.color == color ? p.copyWith(isDisconnected: false, strikes: 0) : p,
      ],
    );
  }

  /// Next player clockwise from the active one, skipping players who have finished.
  int _findNextActivePlayerIndex(GameState state, List<Player> players) {
    final requiredTokens = state.config.mode.tokensToWin;
    int next = (state.activePlayerIndex + 1) % players.length;
    int searchCount = 0;

    while (players[next].finishedTokenCount >= requiredTokens &&
        searchCount < players.length) {
      next = (next + 1) % players.length;
      searchCount++;
    }

    return next;
  }
}
