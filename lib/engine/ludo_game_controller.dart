import 'dart:math';

import '../core/coordinates/board_path_registry.dart';
import '../models/board_position.dart';
import '../models/game_config.dart';
import '../models/game_rules.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/player.dart';
import '../models/player_color.dart';

/// Production-ready, deterministic Ludo Game Engine & Controller.
///
/// Implements a complete Finite State Machine (FSM):
/// - WAITING_FOR_ROLL -> EVALUATING_MOVES -> WAITING_FOR_SELECTION / MOVING_TOKEN -> TURN_RESOLVED -> GAME_OVER
/// - 3-consecutive-sixes forfeiture
/// - Extra rolls awarded for rolling 6, capturing opponent, or reaching Home
/// - Mandatory kill check before entering home column
/// - Safe tile coexistence on [1, 9, 14, 22, 27, 35, 40, 48]
/// - Exact home roll enforcement
/// - Auto-advance on 0 legal moves
/// - Auto-selection on exactly 1 legal move
/// - Turn timeout and 3-strike disconnect penalty
class LudoGameController {
  GameState _state;
  final Random _random;

  /// Whether exactly 1 legal move should be executed immediately.
  final bool autoExecuteSingleMove;

  LudoGameController({
    required GameState initialState,
    Random? random,
    this.autoExecuteSingleMove = true,
  })  : _state = initialState,
        _random = random ?? Random();

  GameState get state => _state;

  /// Creates a standard controller initialized with 2 to 4 players.
  factory LudoGameController.newGame({
    required List<PlayerColor> colors,
    Map<PlayerColor, bool>? aiConfig,
    GameConfig? config,
    GameRules rules = const GameRules(),
    Random? random,
    bool autoExecuteSingleMove = true,
  }) {
    return LudoGameController(
      initialState: GameState.initial(
        colors: colors,
        aiConfig: aiConfig,
        config: config,
        rules: rules,
      ),
      random: random,
      autoExecuteSingleMove: autoExecuteSingleMove,
    );
  }

  /// Re-initializes controller state for a new game.
  void startNewGame({
    required List<PlayerColor> colors,
    Map<PlayerColor, bool>? aiConfig,
    GameConfig? config,
    GameRules rules = const GameRules(),
  }) {
    _state = GameState.initial(
      colors: colors,
      aiConfig: aiConfig,
      config: config,
      rules: rules,
    );
  }

  /// Rolls the dice for the active player and drives FSM transitions.
  ///
  /// Supports optional [forcedValue] (1..6) for deterministic testing.
  GameState rollDice([int? forcedValue]) {
    if (_state.fsmState != LudoFsmState.waitingForRoll || _state.isGameOver) {
      return _state;
    }

    final roll = forcedValue ?? (_random.nextInt(6) + 1);
    assert(roll >= 1 && roll <= 6, 'Dice roll must be between 1 and 6');

    // 1. Transition: WAITING_FOR_ROLL -> EVALUATING_MOVES
    _state = _state.copyWith(
      lastDiceRoll: roll,
      fsmState: LudoFsmState.evaluatingMoves,
    );

    // 2. Track consecutive sixes
    final isSix = roll == 6;
    final newConsecutiveSixes = isSix ? _state.consecutiveSixesCount + 1 : 0;

    // RULE: If consecutiveSixes reaches 3, forfeit roll and transition to next player immediately
    if (newConsecutiveSixes >= _state.config.consecutiveSixesLimit) {
      final nextIndex = _findNextActivePlayerIndex(_state.activePlayerIndex);
      _state = _state.copyWith(
        lastDiceRoll: roll,
        consecutiveSixesCount: 0,
        validMoves: const [],
        activePlayerIndex: nextIndex,
        fsmState: LudoFsmState.waitingForRoll,
      );
      return _state;
    }

    // 3. Generate all legal moves for active player
    final validMoves = calculateValidMoves(
      state: _state,
      player: _state.activePlayer,
      diceRoll: roll,
    );

    // RULE: If 0 legal moves exist: automatically advance turn
    if (validMoves.isEmpty) {
      final nextIndex = _findNextActivePlayerIndex(_state.activePlayerIndex);
      _state = _state.copyWith(
        lastDiceRoll: roll,
        consecutiveSixesCount: 0,
        validMoves: const [],
        activePlayerIndex: nextIndex,
        fsmState: LudoFsmState.waitingForRoll,
      );
      return _state;
    }

    // RULE: If exactly 1 legal move exists: auto-select that token
    if (validMoves.length == 1 && autoExecuteSingleMove) {
      _state = _state.copyWith(
        lastDiceRoll: roll,
        consecutiveSixesCount: newConsecutiveSixes,
        validMoves: validMoves,
        fsmState: LudoFsmState.movingToken,
      );
      return executeMove(validMoves.first);
    }

    // Otherwise (> 1 legal moves or autoExecute disabled):
    // Transition to WAITING_FOR_SELECTION
    _state = _state.copyWith(
      lastDiceRoll: roll,
      consecutiveSixesCount: newConsecutiveSixes,
      validMoves: validMoves,
      fsmState: LudoFsmState.waitingForSelection,
    );

    return _state;
  }

  /// Evaluates and generates all legal moves for a player given a dice roll.
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

        // RULE: Safe squares [1, 9, 14, 22, 27, 35, 40, 48] allow safe coexistence (no capture)
        // If landing square is NOT safe and contains an opponent's token: reset opponent token to Base
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

  /// Selects a token by ID and executes its move.
  GameState selectToken(String tokenId) {
    final matchingMove = _state.validMoves.firstWhere(
      (m) => m.pawnId == tokenId || m.tokenId == tokenId,
      orElse: () => throw StateError('No legal move found for token $tokenId'),
    );
    return executeMove(matchingMove);
  }

  /// Executes a selected [Move], updates all token states, resolves captures,
  /// checks victory conditions, and transitions FSM states.
  GameState executeMove(Move move) {
    if (_state.fsmState != LudoFsmState.waitingForSelection &&
        _state.fsmState != LudoFsmState.movingToken) {
      return _state;
    }

    final activePlayer = _state.activePlayer;
    assert(activePlayer.color == move.playerColor, 'Move player mismatch');

    // Transition to MOVING_TOKEN if not already
    _state = _state.copyWith(
      fsmState: LudoFsmState.movingToken,
      currentAnimatingMove: move,
    );

    // 1. Update the moving token
    final updatedTokens = activePlayer.tokens.map((t) {
      if (t.id == move.pawnId) {
        return t.copyWith(position: move.toPosition);
      }
      return t;
    }).toList();

    // 2. Resolve captures across opponent players
    final updatedPlayers = <Player>[];
    for (final player in _state.players) {
      if (player.color == activePlayer.color) {
        final playerWithMovedToken = player.copyWith(
          tokens: updatedTokens,
          hasKilledOpponent: player.hasKilledOpponent || move.isCapture,
        );
        updatedPlayers.add(playerWithMovedToken);
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
    final requiredTokens = _state.config.mode.tokensToWin;
    final updatedRankings = List<PlayerColor>.from(_state.rankings);
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
    final isMatchOver = unfinishedPlayers.length <= 1;

    if (isMatchOver) {
      for (final p in unfinishedPlayers) {
        if (!updatedRankings.contains(p.color)) {
          updatedRankings.add(p.color);
        }
      }

      _state = _state.copyWith(
        players: updatedPlayers,
        rankings: updatedRankings,
        fsmState: LudoFsmState.gameOver,
        validMoves: const [],
        clearDiceRoll: true,
        clearAnimatingMove: true,
      );
      return _state;
    }

    // 4. Determine turn continuation
    // RULE: A roll of 6, a token capture, or a token reaching Home grants an extra roll
    final getsExtraTurn = move.grantsExtraTurn && !hasPlayerWon;

    final nextPlayerIndex = getsExtraTurn
        ? _state.activePlayerIndex
        : _findNextActivePlayerIndex(_state.activePlayerIndex, updatedPlayers);

    _state = _state.copyWith(
      players: updatedPlayers,
      rankings: updatedRankings,
      activePlayerIndex: nextPlayerIndex,
      fsmState: LudoFsmState.waitingForRoll,
      consecutiveSixesCount:
          getsExtraTurn && move.diceRoll == 6 ? _state.consecutiveSixesCount : 0,
      validMoves: const [],
      clearDiceRoll: true,
      clearAnimatingMove: true,
    );

    return _state;
  }

  /// Handles turn timeout (e.g. 12 seconds expired).
  ///
  /// Enforces a 3-strike disconnect penalty.
  GameState handleTurnTimeout() {
    if (_state.isGameOver) return _state;

    final active = _state.activePlayer;
    final updatedStrikes = active.strikes + 1;
    final isDisconnected =
        updatedStrikes >= _state.config.timerConfig.maxStrikes;

    final updatedPlayers = _state.players.map((p) {
      if (p.color == active.color) {
        return p.copyWith(
          strikes: updatedStrikes,
          isDisconnected: isDisconnected,
        );
      }
      return p;
    }).toList();

    final nextIndex =
        _findNextActivePlayerIndex(_state.activePlayerIndex, updatedPlayers);

    _state = _state.copyWith(
      players: updatedPlayers,
      activePlayerIndex: nextIndex,
      fsmState: LudoFsmState.waitingForRoll,
      validMoves: const [],
      clearDiceRoll: true,
      consecutiveSixesCount: 0,
    );

    return _state;
  }

  /// Finds the next active player index in clockwise order, skipping finished players.
  int _findNextActivePlayerIndex(int currentIndex, [List<Player>? playersOverride]) {
    final players = playersOverride ?? _state.players;
    final requiredTokens = _state.config.mode.tokensToWin;
    int next = (currentIndex + 1) % players.length;
    int searchCount = 0;

    while (players[next].finishedTokenCount >= requiredTokens &&
        searchCount < players.length) {
      next = (next + 1) % players.length;
      searchCount++;
    }

    return next;
  }

  /// Restores state directly (useful for persisted matches or testing).
  void restoreState(GameState restored) {
    _state = restored;
  }
}
