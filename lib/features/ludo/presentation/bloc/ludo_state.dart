import 'package:flutter/material.dart';
import '../../../../presentation/themes/board_theme.dart';
import '../../../../models/game_state.dart';
import '../../../../models/history_entry.dart';
import '../../../../models/saved_match.dart';
import '../../../../models/move.dart';
import '../../../../models/player.dart';
import '../../../../models/player_color.dart';

/// One-shot events for the screen to act on once (snackbars, victory haptics).
///
/// An effect stays in [LudoActiveState.sideEffect] until replaced or cleared,
/// so later states carry the same instance; [isNewSideEffect] tells a fresh
/// effect from a carried-over one. Constructors are deliberately non-const so
/// every event is a distinct instance.
sealed class LudoSideEffect {
  LudoSideEffect();
}

/// Something the player should notice now (penalties, timeouts, undo, ...).
/// Routine turn results go in [LudoActiveState.turnNote] instead.
final class LudoSnackbarEffect extends LudoSideEffect {
  final String message;
  final IconData icon;
  final Color? iconColor;

  LudoSnackbarEffect(
    this.message, {
    this.icon = Icons.info_outline,
    this.iconColor,
  });
}

final class LudoVictoryEffect extends LudoSideEffect {
  LudoVictoryEffect();
}

/// Whether [current] brings a side effect [previous] didn't have, i.e. one
/// the screen hasn't acted on yet.
bool isNewSideEffect(LudoState previous, LudoState current) {
  final effect = current is LudoActiveState ? current.sideEffect : null;
  if (effect == null) return false;
  final before = previous is LudoActiveState ? previous.sideEffect : null;
  return !identical(effect, before);
}

/// A short note about the last turn result (no moves, extra turn, capture),
/// shown in the bottom panel rather than as a snackbar.
class TurnNote {
  final String text;
  final IconData icon;
  final Color color;

  const TurnNote(this.text, {required this.icon, required this.color});
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

  /// The latest routine turn result, shown in the bottom panel.
  final TurnNote? turnNote;

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
    this.turnNote,
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

  /// The other human player who has played since [undoTarget]'s choice, if
  /// any. Undo never rewinds another person's turn, so this locks it.
  ///
  /// "Human" means seated as human at setup, including a seat a bot took
  /// over after timeouts: its turns still belong to that person.
  Player? get undoBlockedBy {
    final target = undoTarget;
    if (target == null) return null;
    final chooser = target.state.activePlayerColor;
    bool isOtherHuman(PlayerColor color) {
      final p = gameState.getPlayer(color);
      return color != chooser && p != null && !p.isAi;
    }

    // Turns resolved since that choice
    for (final entry in history.skip(target.historyLength)) {
      if (isOtherHuman(entry.color)) return gameState.getPlayer(entry.color);
    }
    // A turn in progress: rolled and now choosing
    if (gameState.fsmState == LudoFsmState.waitingForSelection &&
        isOtherHuman(gameState.activePlayerColor)) {
      return gameState.activePlayer;
    }
    return null;
  }

  bool get canUndo =>
      undoTarget != null &&
      animatingMove == null &&
      pendingRoll == null &&
      undoBlockedBy == null;

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
    TurnNote? turnNote,
    bool clearTurnNote = false,
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
      turnNote: clearTurnNote ? null : (turnNote ?? this.turnNote),
      themeType: themeType ?? this.themeType,
    );
  }
}
