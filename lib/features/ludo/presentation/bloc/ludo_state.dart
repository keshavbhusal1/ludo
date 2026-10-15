import 'package:flutter/material.dart';
import '../../../../presentation/themes/board_theme.dart';
import '../../../../models/game_state.dart';
import '../../../../models/history_entry.dart';
import '../../../../models/saved_match.dart';
import '../../../../models/move.dart';
import '../../../../models/player.dart';

/// Sealed side-effect events consumed by BlocListener (SnackBars, haptics, victory).
sealed class LudoSideEffect {
  const LudoSideEffect();
}

final class LudoSnackbarEffect extends LudoSideEffect {
  final String message;
  final IconData icon;
  final Color? iconColor;

  const LudoSnackbarEffect(
    this.message, {
    this.icon = Icons.info_outline,
    this.iconColor,
  });
}

final class LudoVictoryEffect extends LudoSideEffect {
  const LudoVictoryEffect();
}

/// Sealed state hierarchy consumed by BlocBuilder.
sealed class LudoState {
  final BoardThemeType themeType;
  const LudoState({this.themeType = BoardThemeType.darkModern});
}

/// Initial loading / uninitialized state.
final class LudoInitial extends LudoState {
  const LudoInitial({super.themeType});
}

/// Active match in progress.
final class LudoActiveState extends LudoState {
  /// The match as the player currently sees it. Single source of truth.
  final GameState gameState;
  final Move? animatingMove;

  /// Result of a human's roll, held back until the dice overlay finishes
  /// tumbling. Non-null exactly while the overlay is showing.
  final GameState? pendingRoll;
  final Player? rollerPlayer;
  /// Unfinished match found in storage at launch, kept here until the player
  /// resumes or dismisses it. While set, the current game is not autosaved so
  /// the stored match can't be overwritten.
  final SavedMatch? resumableGame;
  final LudoSideEffect? sideEffect;

  /// Every resolved roll this session, oldest first.
  final List<HistoryEntry> history;

  /// Undo targets, oldest first.
  final List<UndoPoint> undoStack;

  /// When the current human turn times out, if the turn timer is running.
  final DateTime? turnDeadline;

  const LudoActiveState({
    required this.gameState,
    this.animatingMove,
    this.pendingRoll,
    this.rollerPlayer,
    this.resumableGame,
    this.sideEffect,
    this.history = const [],
    this.undoStack = const [],
    this.turnDeadline,
    super.themeType,
  });

  bool get hasSavedGameBanner => resumableGame != null;
  bool get isShowingRollOverlay => pendingRoll != null;
  int? get overlayRollValue => pendingRoll?.lastDiceRoll;

  /// The point undo would return to: the latest one that isn't where we are now.
  UndoPoint? get undoTarget {
    for (final point in undoStack.reversed) {
      if (!identical(point.state, gameState)) return point;
    }
    return null;
  }

  bool get canUndo => undoTarget != null && animatingMove == null && pendingRoll == null;

  LudoActiveState copyWith({
    GameState? gameState,
    Move? animatingMove,
    GameState? pendingRoll,
    bool clearPendingRoll = false,
    Player? rollerPlayer,
    SavedMatch? resumableGame,
    bool clearResumableGame = false,
    LudoSideEffect? sideEffect,
    bool clearSideEffect = false,
    bool clearAnimatingMove = false,
    bool clearRollerPlayer = false,
    List<HistoryEntry>? history,
    List<UndoPoint>? undoStack,
    DateTime? turnDeadline,
    bool clearTurnDeadline = false,
    BoardThemeType? themeType,
  }) {
    return LudoActiveState(
      gameState: gameState ?? this.gameState,
      animatingMove: clearAnimatingMove ? null : (animatingMove ?? this.animatingMove),
      pendingRoll: clearPendingRoll ? null : (pendingRoll ?? this.pendingRoll),
      rollerPlayer: clearRollerPlayer ? null : (rollerPlayer ?? this.rollerPlayer),
      resumableGame: clearResumableGame ? null : (resumableGame ?? this.resumableGame),
      sideEffect: clearSideEffect ? null : (sideEffect ?? this.sideEffect),
      history: history ?? this.history,
      undoStack: undoStack ?? this.undoStack,
      turnDeadline: clearTurnDeadline ? null : (turnDeadline ?? this.turnDeadline),
      themeType: themeType ?? this.themeType,
    );
  }
}
