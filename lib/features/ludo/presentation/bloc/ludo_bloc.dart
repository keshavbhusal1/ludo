import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../engine/ai/ludo_ai_engine.dart';
import '../../../../engine/ludo_game_engine.dart';
import '../../../../models/game_state.dart';
import '../../../../models/history_entry.dart';
import '../../../../models/move.dart';
import '../../../../models/saved_match.dart';
import '../../domain/usecases/clear_saved_game_use_case.dart';
import '../../domain/usecases/execute_move_use_case.dart';
import '../../domain/usecases/get_saved_game_use_case.dart';
import '../../domain/usecases/roll_dice_use_case.dart';
import '../../domain/usecases/save_game_use_case.dart';
import 'ludo_event.dart';
import 'ludo_state.dart';

/// BLoC orchestrating match lifecycle, use cases, AI heuristics, and state emissions.
///
/// Owns the match: [LudoActiveState.gameState] is the only copy of the game,
/// and every change goes through the pure [LudoEngine] via the use cases.
class LudoBloc extends Bloc<LudoEvent, LudoState> {
  final LudoEngine engine;
  final RollDiceUseCase rollDiceUseCase;
  final ExecuteMoveUseCase executeMoveUseCase;
  final GetSavedGameUseCase getSavedGameUseCase;
  final SaveGameUseCase saveGameUseCase;
  final ClearSavedGameUseCase clearSavedGameUseCase;
  final LudoAiEngine aiEngine;

  LudoBloc({
    this.engine = const LudoEngine(),
    required this.rollDiceUseCase,
    required this.executeMoveUseCase,
    required this.getSavedGameUseCase,
    required this.saveGameUseCase,
    required this.clearSavedGameUseCase,
    required this.aiEngine,
  }) : super(const LudoInitial()) {
    // One handler for every event type: bloc gives each on<E> its own queue, so
    // only a single registration makes events process strictly one at a time.
    // Handlers read `state` across awaits and must not interleave. Waits (bot
    // thinking, dice settling) are timers, never awaited here, so the queue
    // doesn't stall behind them.
    on<LudoEvent>(_dispatch, transformer: (events, mapper) => events.asyncExpand(mapper));
  }

  Future<void> _dispatch(LudoEvent event, Emitter<LudoState> emit) async {
    switch (event) {
      case LudoStarted():
        await _onLudoStarted(event, emit);
      case LudoDiceRollRequested():
        await _onLudoDiceRollRequested(event, emit);
      case LudoDiceRollOverlayCompleted():
        await _onLudoDiceRollOverlayCompleted(event, emit);
      case LudoMoveSelected():
        _onLudoMoveSelected(event, emit);
      case LudoMoveAnimationCompleted():
        await _onLudoMoveAnimationCompleted(event, emit);
      case LudoSavedMatchResumed():
        await _onLudoSavedMatchResumed(event, emit);
      case LudoSavedMatchBannerDismissed():
        await _onLudoSavedMatchBannerDismissed(event, emit);
      case LudoAiTurnTriggered():
        _onLudoAiTurnTriggered(event, emit);
      case LudoThemeChanged():
        _onLudoThemeChanged(event, emit);
      case LudoMatchRestarted():
        _onLudoMatchRestarted(event, emit);
      case LudoUndoRequested():
        await _onLudoUndoRequested(event, emit);
      case LudoTurnTimedOut():
        await _onLudoTurnTimedOut(event, emit);
      case LudoAppLifecycleChanged():
        _isForeground = event.isForeground;
      case LudoSeatReclaimed():
        await _onLudoSeatReclaimed(event, emit);
    }
    // Every event can start, end, or change a human's timed turn.
    _syncTurnTimer(emit);
  }

  /// Timer for the current human decision, if the match uses the turn timer.
  Timer? _turnTimer;

  /// The game state [_turnTimer] was started for (a turn = one state object).
  GameState? _turnTimerFor;

  bool _isForeground = true;

  /// Whether a human is due to act now: roll, or pick a token.
  static bool _humanDecisionPending(LudoActiveState s) {
    final game = s.gameState;
    return !game.isGameOver &&
        !game.activePlayer.isBotControlled &&
        s.pendingRoll == null &&
        s.animatingMove == null &&
        (game.turnPhase == TurnPhase.awaitingRoll ||
            game.turnPhase == TurnPhase.awaitingPawnSelection);
  }

  /// Starts, keeps, or stops the turn timer to match the current state, and
  /// publishes the deadline for the countdown UI.
  void _syncTurnTimer(Emitter<LudoState> emit) {
    final s = state;
    if (s is! LudoActiveState) return;

    final shouldRun = _isForeground &&
        s.gameState.config.timerConfig.enabled &&
        _humanDecisionPending(s);

    if (!shouldRun) {
      _stopTurnTimer();
      if (s.turnDeadline != null) emit(s.copyWith(clearTurnDeadline: true));
      return;
    }
    if (_turnTimer != null && identical(_turnTimerFor, s.gameState)) return;

    _stopTurnTimer();
    final forState = s.gameState;
    final limit = forState.config.timerConfig.turnTimeout;
    _turnTimerFor = forState;
    _turnTimer = Timer(limit, () {
      if (!isClosed) add(LudoTurnTimedOut(forState));
    });
    emit(s.copyWith(turnDeadline: DateTime.now().add(limit)));
  }

  void _stopTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    _turnTimerFor = null;
  }

  /// Gives a taken-over seat back to its human. If it's that seat's turn,
  /// the bot's pending step is cancelled and the human continues from the
  /// same point (same roll, if one was made); a move already animating
  /// finishes first.
  Future<void> _onLudoSeatReclaimed(
    LudoSeatReclaimed event,
    Emitter<LudoState> emit,
  ) async {
    final s = state;
    if (s is! LudoActiveState) return;
    final game = engine.reclaimSeat(s.gameState, event.color);
    if (identical(game, s.gameState)) return;

    if (game.activePlayerColor == event.color) {
      // Only this seat's bot step; other bots keep their pending turns
      _botTimer?.cancel();
      _botTimer = null;
    }

    final name = game.getPlayer(event.color)!.name;
    emit(s.copyWith(
      gameState: game,
      sideEffect: LudoSnackbarEffect(
        '$name is back in control',
        icon: Icons.person,
        iconColor: Color(event.color.primaryColorValue),
      ),
    ));
    await _autosave();
  }

  /// A human ran out of time: record a strike (a bot takes the seat at the
  /// limit) and let the bot play this turn for them — roll if needed, then
  /// the best move — so the roll isn't wasted.
  Future<void> _onLudoTurnTimedOut(
    LudoTurnTimedOut event,
    Emitter<LudoState> emit,
  ) async {
    final s = state;
    if (s is! LudoActiveState) return;
    // Stale: the player acted, or the match changed, before the timer fired.
    if (!identical(s.gameState, event.forState) || !_humanDecisionPending(s)) return;
    _stopTurnTimer();

    final before = s.gameState;
    final player = before.activePlayer;
    var game = engine.handleTurnTimeout(before);
    final struck = game.activePlayer;
    final maxStrikes = game.config.timerConfig.maxStrikes;
    var history = s.history;

    if (game.turnPhase == TurnPhase.awaitingRoll) {
      final rolled = rollDiceUseCase(game).getOrElse((failure) {
        debugPrint('Auto-roll failed: $failure');
        return game;
      });
      history = _withRollOutcome(history, game, rolled);
      game = rolled;
    }

    emit(s.copyWith(
      gameState: game,
      history: history,
      clearTurnDeadline: true,
      sideEffect: LudoSnackbarEffect(
        struck.isDisconnected && !player.isDisconnected
            ? "${player.name} timed out $maxStrikes times — a bot takes over"
            : "${player.name} ran out of time (strike ${struck.strikes}/$maxStrikes) — auto-playing",
        icon: Icons.timer_off,
        iconColor: const Color(0xFFF87171),
      ),
    ));

    if (game.turnPhase == TurnPhase.awaitingPawnSelection &&
        game.activePlayerColor == player.color) {
      final best = aiEngine.selectBestMove(state: game, validMoves: game.validMoves);
      _onLudoMoveSelected(LudoMoveSelected(best), emit);
    } else if (game.activePlayer.isBotControlled) {
      // No legal move: the turn passed straight on to a bot
      _scheduleBotStep(_scaled(700), const LudoAiTurnTriggered());
    }
    await _autosave();
  }

  /// Pending delayed events. All are cancelled when a different match takes over.
  final Set<Timer> _timers = {};

  /// The single pending bot step; scheduling a new one replaces it, so duplicate
  /// triggers can't make a bot act twice.
  Timer? _botTimer;

  String? get _currentGameId {
    final s = state;
    return s is LudoActiveState ? s.gameState.id : null;
  }

  double get _gameSpeed {
    final s = state;
    return s is LudoActiveState ? s.gameState.rules.gameSpeed : 1.0;
  }

  Duration _scaled(int ms) => Duration(milliseconds: (ms / _gameSpeed).round());

  /// Dispatches [event] after [delay] unless the match has changed by then.
  Timer _schedule(Duration delay, LudoEvent event) {
    final gameId = _currentGameId;
    late final Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      if (!isClosed && _currentGameId == gameId) add(event);
    });
    _timers.add(timer);
    return timer;
  }

  void _scheduleBotStep(Duration delay, LudoEvent event) {
    _botTimer?.cancel();
    _botTimer = _schedule(delay, event);
  }

  void _cancelScheduled() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _botTimer = null;
    _stopTurnTimer();
  }

  @override
  Future<void> close() {
    _cancelScheduled();
    return super.close();
  }

  Future<void> _onLudoStarted(LudoStarted event, Emitter<LudoState> emit) async {
    // Check if an existing unfinished match exists
    final savedResult = await getSavedGameUseCase();
    final resumable = savedResult.fold(
      (failure) {
        debugPrint('Could not load saved match: $failure');
        return null;
      },
      (match) => match != null && !match.game.isGameOver ? match : null,
    );

    _cancelScheduled();
    final game = engine.newGame(
      colors: event.colors,
      aiConfig: event.aiConfig,
      rules: event.rules,
    );

    emit(LudoActiveState(
      gameState: game,
      resumableGame: resumable,
      themeType: event.themeType,
    ));

    if (game.activePlayer.isBotControlled) {
      add(const LudoAiTurnTriggered());
    }
  }

  Future<void> _onLudoDiceRollRequested(
    LudoDiceRollRequested event,
    Emitter<LudoState> emit,
  ) async {
    if (state is! LudoActiveState) return;
    final currentState = state as LudoActiveState;
    final gameState = currentState.gameState;

    if (gameState.turnPhase != TurnPhase.awaitingRoll ||
        currentState.isShowingRollOverlay ||
        gameState.isGameOver) {
      return;
    }

    final rollingPlayer = gameState.activePlayer;
    final rollResult = rollDiceUseCase(gameState);

    rollResult.fold(
      (failure) => debugPrint('Dice roll failed: $failure'),
      (newState) {
        if (!rollingPlayer.isBotControlled) {
          // Human player: launch dramatic 3D tumbling overlay; the result is
          // revealed (applied to gameState) when the overlay finishes.
          emit(currentState.copyWith(
            rollerPlayer: rollingPlayer,
            pendingRoll: newState,
            clearSideEffect: true,
          ));
        } else {
          // AI player: smooth inline roll without taking over screen
          emit(currentState.copyWith(
            gameState: newState,
            clearSideEffect: true,
            history: _withRollOutcome(currentState.history, gameState, newState),
          ));
          _autosave();
          // Let the rolled value show; linger longer when the turn is passing on.
          final settleMs =
              newState.turnPhase == TurnPhase.awaitingPawnSelection ? 380 : 700;
          _scheduleBotStep(_scaled(settleMs), const LudoAiTurnTriggered());
        }
      },
    );
  }

  Future<void> _onLudoDiceRollOverlayCompleted(
    LudoDiceRollOverlayCompleted event,
    Emitter<LudoState> emit,
  ) async {
    if (state is! LudoActiveState) return;
    final currentState = state as LudoActiveState;
    // Stale overlay (e.g. match restarted while the dice were tumbling).
    final gameState = currentState.pendingRoll;
    if (gameState == null) return;

    final stateBeforeRoll = currentState.gameState;
    final rolled = gameState.lastDiceRoll ?? 1;
    final roller = currentState.rollerPlayer ?? gameState.activePlayer;
    final rollerName = roller.name.isNotEmpty ? roller.name : roller.color.displayName;

    LudoSideEffect? sideEffect;
    if (_hitSixesLimit(stateBeforeRoll, rolled)) {
      sideEffect = LudoSnackbarEffect(
        'Three 6s penalty! Turn passes to ${gameState.activePlayer.name}',
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFF87171),
      );
    } else if (gameState.validMoves.isEmpty) {
      if (!roller.isBotControlled) {
        sideEffect = LudoSnackbarEffect(
          '$rollerName rolled $rolled — No moves available',
          icon: Icons.casino_outlined,
          iconColor: const Color(0xFF94A3B8),
        );
      }
    }

    final history = _withRollOutcome(currentState.history, stateBeforeRoll, gameState);
    // A real choice between tokens is a point the player can undo back to.
    final undoStack = gameState.validMoves.length > 1
        ? _withUndoPoint(
            currentState.undoStack,
            UndoPoint(state: gameState, historyLength: history.length),
          )
        : currentState.undoStack;

    emit(currentState.copyWith(
      gameState: gameState,
      clearPendingRoll: true,
      clearRollerPlayer: true,
      sideEffect: sideEffect,
      history: history,
      undoStack: undoStack,
    ));
    await _autosave();

    if (gameState.turnPhase == TurnPhase.awaitingPawnSelection) {
      if (gameState.validMoves.length == 1 && !gameState.activePlayer.isBotControlled) {
        // Human player with single forced move: auto-move gently
        _schedule(_scaled(220), LudoMoveSelected(gameState.validMoves.first));
      } else if (gameState.activePlayer.isBotControlled) {
        add(const LudoAiTurnTriggered());
      }
    } else {
      add(const LudoAiTurnTriggered());
    }
  }

  void _onLudoMoveSelected(LudoMoveSelected event, Emitter<LudoState> emit) {
    if (state is! LudoActiveState) return;
    final currentState = state as LudoActiveState;
    if (currentState.animatingMove != null || currentState.gameState.isGameOver) return;
    // Only moves legal right now (drops stale scheduled or double-tapped selections).
    if (!currentState.gameState.validMoves.contains(event.move)) return;

    emit(currentState.copyWith(
      animatingMove: event.move,
      clearSideEffect: true,
    ));
  }

  Future<void> _onLudoMoveAnimationCompleted(
    LudoMoveAnimationCompleted event,
    Emitter<LudoState> emit,
  ) async {
    if (state is! LudoActiveState) return;
    final currentState = state as LudoActiveState;
    // Stale completion (e.g. the match was resumed or restarted mid-animation).
    if (currentState.animatingMove != event.move) return;
    final stateBefore = currentState.gameState;

    final moveResult = executeMoveUseCase(stateBefore, event.move);

    await moveResult.fold(
      (failure) async {
        debugPrint('Move rejected: $failure');
        emit(currentState.copyWith(clearAnimatingMove: true));
      },
      (newState) async {
        LudoSideEffect? sideEffect;
        if (newState.isGameOver) {
          sideEffect = const LudoVictoryEffect();
        } else if (event.move.isCapture) {
          sideEffect = LudoSnackbarEffect(
            'Capture! ${stateBefore.activePlayer.name} gets an extra turn',
            icon: Icons.flash_on,
            iconColor: const Color(0xFFFBBF24),
          );
        } else if (event.move.isReachingHome) {
          sideEffect = LudoSnackbarEffect(
            'Token Home! ${stateBefore.activePlayer.name} gets an extra turn',
            icon: Icons.star,
            iconColor: const Color(0xFF34D399),
          );
        } else if (event.move.diceRoll == 6 &&
            newState.activePlayerColor == stateBefore.activePlayerColor) {
          sideEffect = const LudoSnackbarEffect(
            'Rolled a 6! Extra Turn',
            icon: Icons.casino,
            iconColor: Color(0xFF10B981),
          );
        }

        emit(currentState.copyWith(
          gameState: newState,
          clearAnimatingMove: true,
          sideEffect: sideEffect,
          history: [...currentState.history, _moveEntry(stateBefore, event.move)],
        ));
        if (newState.isGameOver) {
          await _clearAutosave();
        } else {
          await _autosave();
        }

        if (newState.activePlayer.isBotControlled) {
          add(const LudoAiTurnTriggered());
        }
      },
    );
  }

  Future<void> _onLudoSavedMatchResumed(
    LudoSavedMatchResumed event,
    Emitter<LudoState> emit,
  ) async {
    if (state is! LudoActiveState) return;
    final currentState = state as LudoActiveState;

    final saved = currentState.resumableGame;
    if (saved == null) return;

    _cancelScheduled();
    emit(currentState.copyWith(
      gameState: saved.game,
      clearResumableGame: true,
      clearAnimatingMove: true,
      clearPendingRoll: true,
      clearRollerPlayer: true,
      history: saved.history,
      undoStack: saved.undoStack,
      sideEffect: const LudoSnackbarEffect(
        'Restored previous match!',
        icon: Icons.history,
        iconColor: Color(0xFF38BDF8),
      ),
    ));

    if (saved.game.activePlayer.isBotControlled) {
      add(const LudoAiTurnTriggered());
    }
  }

  Future<void> _onLudoSavedMatchBannerDismissed(
    LudoSavedMatchBannerDismissed event,
    Emitter<LudoState> emit,
  ) async {
    if (state is! LudoActiveState) return;
    final current = state as LudoActiveState;
    emit(current.copyWith(clearResumableGame: true));
    // The old match is given up: the current game now owns the autosave slot.
    await _autosave();
  }

  /// Rewinds to the latest human token choice, with the same dice, undoing
  /// everything (including bot turns) played since.
  Future<void> _onLudoUndoRequested(
    LudoUndoRequested event,
    Emitter<LudoState> emit,
  ) async {
    if (state is! LudoActiveState) return;
    final current = state as LudoActiveState;
    if (!current.canUndo) return;
    final target = current.undoTarget!;

    _cancelScheduled();
    // Points after the target belong to the undone timeline. The target stays,
    // so after choosing again the player can come back to it.
    final keep = current.undoStack.indexOf(target) + 1;
    emit(current.copyWith(
      gameState: target.state,
      history: current.history.sublist(0, target.historyLength),
      undoStack: current.undoStack.sublist(0, keep),
      sideEffect: LudoSnackbarEffect(
        'Undone — ${target.state.activePlayer.name}, pick a token',
        icon: Icons.undo,
        iconColor: const Color(0xFF60A5FA),
      ),
    ));
    await _autosave();
  }

  static const _maxUndoPoints = 50;

  static List<UndoPoint> _withUndoPoint(List<UndoPoint> stack, UndoPoint point) {
    final next = [...stack, point];
    return next.length > _maxUndoPoints ? next.sublist(next.length - _maxUndoPoints) : next;
  }

  static bool _hitSixesLimit(GameState before, int roll) =>
      roll == 6 && before.consecutiveSixes + 1 >= before.config.consecutiveSixesLimit;

  /// Logs a roll that ended the turn without a move. Rolls that lead to a
  /// move are logged when the move is played.
  static List<HistoryEntry> _withRollOutcome(
    List<HistoryEntry> history,
    GameState before,
    GameState after,
  ) {
    final roll = after.lastDiceRoll;
    if (roll == null || after.turnPhase == TurnPhase.awaitingPawnSelection) return history;
    final player = before.activePlayer;
    return [
      ...history,
      HistoryEntry(
        color: player.color,
        playerName: player.name,
        roll: roll,
        outcome: _hitSixesLimit(before, roll) ? TurnOutcome.sixesPenalty : TurnOutcome.noMoves,
      ),
    ];
  }

  static HistoryEntry _moveEntry(GameState before, Move move) {
    final mover = before.activePlayer;
    final victim = move.isCapture
        ? before.players
            .where((p) => p.tokens.any((t) => t.id == move.capturedPawnId))
            .firstOrNull
        : null;
    return HistoryEntry(
      color: mover.color,
      playerName: mover.name,
      roll: move.diceRoll,
      outcome: TurnOutcome.moved,
      move: move,
      capturedPlayerName: victim?.name,
    );
  }

  /// Saves the current match (game, history, undo points) unless a resumable
  /// match is still awaiting the player's choice. Call after emitting.
  Future<void> _autosave() async {
    final s = state;
    if (s is! LudoActiveState || _isHoldingResumableGame) return;
    final result = await saveGameUseCase(
      SavedMatch(game: s.gameState, history: s.history, undoStack: s.undoStack),
    );
    result.fold((failure) => debugPrint('Autosave failed: $failure'), (_) {});
  }

  Future<void> _clearAutosave() async {
    if (_isHoldingResumableGame) return;
    final result = await clearSavedGameUseCase();
    result.fold((failure) => debugPrint('Clearing autosave failed: $failure'), (_) {});
  }

  bool get _isHoldingResumableGame {
    final s = state;
    return s is LudoActiveState && s.resumableGame != null;
  }

  void _onLudoAiTurnTriggered(
    LudoAiTurnTriggered event,
    Emitter<LudoState> emit,
  ) {
    if (state is! LudoActiveState) return;
    final gameState = (state as LudoActiveState).gameState;

    if (gameState.isGameOver || !gameState.activePlayer.isBotControlled) return;
    final speed = gameState.rules.gameSpeed;

    if (gameState.turnPhase == TurnPhase.awaitingRoll) {
      _scheduleBotStep(
        aiEngine.thinkingDelay(minMs: 600, maxMs: 900, gameSpeed: speed),
        const LudoDiceRollRequested(),
      );
    } else if (gameState.turnPhase == TurnPhase.awaitingPawnSelection &&
        gameState.validMoves.isNotEmpty) {
      final bestMove = aiEngine.selectBestMove(
        state: gameState,
        validMoves: gameState.validMoves,
      );
      _scheduleBotStep(
        aiEngine.thinkingDelay(minMs: 450, maxMs: 750, gameSpeed: speed),
        LudoMoveSelected(bestMove),
      );
    }
  }

  void _onLudoThemeChanged(LudoThemeChanged event, Emitter<LudoState> emit) {
    if (state is! LudoActiveState) return;
    emit((state as LudoActiveState).copyWith(themeType: event.themeType));
  }

  void _onLudoMatchRestarted(LudoMatchRestarted event, Emitter<LudoState> emit) {
    if (state is! LudoActiveState) return;
    final current = state as LudoActiveState;
    final players = current.gameState.players;

    add(LudoStarted(
      colors: players.map((p) => p.color).toList(),
      aiConfig: {for (final p in players) p.color: p.isAi},
      rules: current.gameState.rules,
      themeType: current.themeType,
    ));
  }
}
