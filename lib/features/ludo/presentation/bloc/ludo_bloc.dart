import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../engine/ai/ludo_ai_engine.dart';
import '../../../../engine/ludo_game_controller.dart';
import '../../../../models/game_state.dart';
import '../../../../models/player.dart';
import '../../domain/usecases/clear_saved_game_use_case.dart';
import '../../domain/usecases/execute_move_use_case.dart';
import '../../domain/usecases/get_saved_game_use_case.dart';
import '../../domain/usecases/roll_dice_use_case.dart';
import '../../domain/usecases/save_game_use_case.dart';
import 'ludo_event.dart';
import 'ludo_state.dart';

/// BLoC orchestrating match lifecycle, use cases, AI heuristics, and state emissions.
class LudoBloc extends Bloc<LudoEvent, LudoState> {
  final LudoGameController controller;
  final RollDiceUseCase rollDiceUseCase;
  final ExecuteMoveUseCase executeMoveUseCase;
  final GetSavedGameUseCase getSavedGameUseCase;
  final SaveGameUseCase saveGameUseCase;
  final ClearSavedGameUseCase clearSavedGameUseCase;
  final LudoAiEngine aiEngine;

  LudoBloc({
    required this.controller,
    required this.rollDiceUseCase,
    required this.executeMoveUseCase,
    required this.getSavedGameUseCase,
    required this.saveGameUseCase,
    required this.clearSavedGameUseCase,
    required this.aiEngine,
  }) : super(const LudoInitial()) {
    on<LudoStarted>(_onLudoStarted);
    on<LudoDiceRollRequested>(_onLudoDiceRollRequested);
    on<LudoDiceRollOverlayCompleted>(_onLudoDiceRollOverlayCompleted);
    on<LudoMoveSelected>(_onLudoMoveSelected);
    on<LudoMoveAnimationCompleted>(_onLudoMoveAnimationCompleted);
    on<LudoSavedMatchResumed>(_onLudoSavedMatchResumed);
    on<LudoSavedMatchBannerDismissed>(_onLudoSavedMatchBannerDismissed);
    on<LudoAiTurnTriggered>(_onLudoAiTurnTriggered);
    on<LudoThemeChanged>(_onLudoThemeChanged);
    on<LudoMatchRestarted>(_onLudoMatchRestarted);
  }

  Future<void> _onLudoStarted(LudoStarted event, Emitter<LudoState> emit) async {
    // Check if an existing unfinished match exists
    final savedResult = await getSavedGameUseCase();
    final hasSaved = savedResult.fold((_) => false, (game) => game != null && !game.isGameOver);

    controller.startNewGame(
      colors: event.colors,
      aiConfig: event.aiConfig,
      rules: event.rules,
    );

    emit(LudoActiveState(
      gameState: controller.state,
      hasSavedGameBanner: hasSaved,
      themeType: event.themeType,
    ));

    if (controller.state.activePlayer.isAi) {
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
    final rollResult = rollDiceUseCase();

    rollResult.fold(
      (failure) => null,
      (newState) {
        final rolled = newState.lastDiceRoll ?? 1;

        if (!rollingPlayer.isAi) {
          // Human player: launch dramatic 3D tumbling overlay
          emit(currentState.copyWith(
            rollerPlayer: rollingPlayer,
            overlayRollValue: rolled,
            isShowingRollOverlay: true,
            clearSideEffect: true,
          ));
        } else {
          // AI player: smooth inline roll without taking over screen
          emit(currentState.copyWith(
            gameState: newState,
            clearSideEffect: true,
          ));
          saveGameUseCase(newState);
          _scheduleBotRollSettlement(rollingPlayer, rolled);
        }
      },
    );
  }

  void _scheduleBotRollSettlement(Player rollingPlayer, int rolled) {
    Future.delayed(const Duration(milliseconds: 380), () {
      if (!isClosed && state is LudoActiveState) {
        final current = (state as LudoActiveState).gameState;
        if (current.turnPhase == TurnPhase.awaitingPawnSelection) {
          add(const LudoAiTurnTriggered());
        } else {
          Future.delayed(const Duration(milliseconds: 320), () {
            if (!isClosed) add(const LudoAiTurnTriggered());
          });
        }
      }
    });
  }

  Future<void> _onLudoDiceRollOverlayCompleted(
    LudoDiceRollOverlayCompleted event,
    Emitter<LudoState> emit,
  ) async {
    if (state is! LudoActiveState) return;
    final currentState = state as LudoActiveState;

    final stateBeforeRoll = currentState.gameState;
    final gameState = controller.state;
    final rolled = gameState.lastDiceRoll ?? 1;
    final roller = currentState.rollerPlayer ?? gameState.activePlayer;
    final rollerName = roller.name.isNotEmpty ? roller.name : roller.color.displayName;

    await saveGameUseCase(gameState);

    LudoSideEffect? sideEffect;
    final hitSixesLimit = rolled == 6 &&
        stateBeforeRoll.consecutiveSixes + 1 >= stateBeforeRoll.config.consecutiveSixesLimit;
    if (hitSixesLimit) {
      sideEffect = LudoSnackbarEffect(
        'Three 6s penalty! Turn passes to ${gameState.activePlayer.name}',
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFF87171),
      );
    } else if (gameState.validMoves.isEmpty) {
      if (!roller.isAi) {
        sideEffect = LudoSnackbarEffect(
          '$rollerName rolled $rolled — No moves available',
          icon: Icons.casino_outlined,
          iconColor: const Color(0xFF94A3B8),
        );
      }
    }

    emit(currentState.copyWith(
      gameState: gameState,
      isShowingRollOverlay: false,
      clearRollerPlayer: true,
      sideEffect: sideEffect,
    ));

    if (gameState.turnPhase == TurnPhase.awaitingPawnSelection) {
      if (gameState.validMoves.length == 1 && !gameState.activePlayer.isAi) {
        // Human player with single forced move: auto-move gently
        Future.delayed(const Duration(milliseconds: 220), () {
          if (!isClosed && (state as LudoActiveState).gameState.turnPhase == TurnPhase.awaitingPawnSelection) {
            add(LudoMoveSelected(gameState.validMoves.first));
          }
        });
      } else if (gameState.activePlayer.isAi) {
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
    final stateBefore = currentState.gameState;

    final moveResult = executeMoveUseCase(event.move);

    await moveResult.fold(
      (failure) async => null,
      (newState) async {
        await saveGameUseCase(newState);

        LudoSideEffect? sideEffect;
        if (newState.isGameOver) {
          await clearSavedGameUseCase();
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
        ));

        if (newState.activePlayer.isAi) {
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

    final savedResult = await getSavedGameUseCase();
    savedResult.fold(
      (failure) => null,
      (saved) {
        if (saved != null) {
          controller.restoreState(saved);
          emit(currentState.copyWith(
            gameState: saved,
            hasSavedGameBanner: false,
            sideEffect: const LudoSnackbarEffect(
              'Restored previous match!',
              icon: Icons.history,
              iconColor: Color(0xFF38BDF8),
            ),
          ));

          if (saved.activePlayer.isAi) {
            add(const LudoAiTurnTriggered());
          }
        }
      },
    );
  }

  void _onLudoSavedMatchBannerDismissed(
    LudoSavedMatchBannerDismissed event,
    Emitter<LudoState> emit,
  ) {
    if (state is! LudoActiveState) return;
    emit((state as LudoActiveState).copyWith(hasSavedGameBanner: false));
  }

  Future<void> _onLudoAiTurnTriggered(
    LudoAiTurnTriggered event,
    Emitter<LudoState> emit,
  ) async {
    if (state is! LudoActiveState) return;
    final currentState = state as LudoActiveState;
    final gameState = currentState.gameState;

    if (gameState.isGameOver || !gameState.activePlayer.isAi) return;

    if (gameState.turnPhase == TurnPhase.awaitingRoll) {
      await aiEngine.simulateThinkingDelay(minMs: 600, maxMs: 900);
      if (!isClosed && (state as LudoActiveState).gameState.turnPhase == TurnPhase.awaitingRoll) {
        add(const LudoDiceRollRequested());
      }
    } else if (gameState.turnPhase == TurnPhase.awaitingPawnSelection &&
        gameState.validMoves.isNotEmpty) {
      await aiEngine.simulateThinkingDelay(minMs: 450, maxMs: 750);
      if (!isClosed && (state as LudoActiveState).gameState.turnPhase == TurnPhase.awaitingPawnSelection) {
        final bestMove = aiEngine.selectBestMove(
          state: (state as LudoActiveState).gameState,
          validMoves: (state as LudoActiveState).gameState.validMoves,
        );
        add(LudoMoveSelected(bestMove));
      }
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
