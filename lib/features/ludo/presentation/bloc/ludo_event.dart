import '../../../../presentation/themes/board_theme.dart';
import '../../../../models/game_rules.dart';
import '../../../../models/game_state.dart';
import '../../../../models/player_color.dart';
import '../../../../models/move.dart';

/// Sealed base class for all events dispatched to LudoBloc.
sealed class LudoEvent {
  const LudoEvent();
}

/// Dispatched to initialize or restart a match.
final class LudoStarted extends LudoEvent {
  final List<PlayerColor> colors;
  final Map<PlayerColor, bool>? aiConfig;
  final GameRules rules;
  final BoardThemeType themeType;

  const LudoStarted({
    this.colors = const [
      PlayerColor.red,
      PlayerColor.green,
      PlayerColor.yellow,
      PlayerColor.blue,
    ],
    this.aiConfig,
    this.rules = const GameRules(),
    this.themeType = BoardThemeType.darkModern,
  });
}

/// Dispatched when active player requests a dice roll (user tap or AI trigger).
final class LudoDiceRollRequested extends LudoEvent {
  const LudoDiceRollRequested();
}

/// Dispatched when the 3D tumbling dice overlay finishes its animation.
final class LudoDiceRollOverlayCompleted extends LudoEvent {
  const LudoDiceRollOverlayCompleted();
}

/// Dispatched when a legal pawn move is chosen.
final class LudoMoveSelected extends LudoEvent {
  final Move move;
  const LudoMoveSelected(this.move);
}

/// Dispatched when pawn hopping animation finishes along its trajectory.
final class LudoMoveAnimationCompleted extends LudoEvent {
  final Move move;
  const LudoMoveAnimationCompleted(this.move);
}

/// Dispatched to restore a previously autosaved match.
final class LudoSavedMatchResumed extends LudoEvent {
  const LudoSavedMatchResumed();
}

/// Dispatched to dismiss the saved match prompt banner.
final class LudoSavedMatchBannerDismissed extends LudoEvent {
  const LudoSavedMatchBannerDismissed();
}

/// Dispatched to trigger next AI bot thinking & turn step.
final class LudoAiTurnTriggered extends LudoEvent {
  const LudoAiTurnTriggered();
}

/// Dispatched to switch the active visual board theme.
final class LudoThemeChanged extends LudoEvent {
  final BoardThemeType themeType;
  const LudoThemeChanged(this.themeType);
}

/// Dispatched to rewind to the most recent human token choice (same dice).
final class LudoUndoRequested extends LudoEvent {
  const LudoUndoRequested();
}

/// Dispatched by the turn timer when a human's turn runs out.
final class LudoTurnTimedOut extends LudoEvent {
  /// The game state the timer was started for; stale if the game moved on.
  final GameState forState;
  const LudoTurnTimedOut(this.forState);
}

/// Dispatched when the app moves to or from the background; the turn timer
/// is paused while in the background.
final class LudoAppLifecycleChanged extends LudoEvent {
  final bool isForeground;
  const LudoAppLifecycleChanged({required this.isForeground});
}

/// Dispatched when a human takes back a seat a bot took over after timeouts.
final class LudoSeatReclaimed extends LudoEvent {
  final PlayerColor color;
  const LudoSeatReclaimed(this.color);
}

/// Dispatched to restart current match with identical player config.
final class LudoMatchRestarted extends LudoEvent {
  const LudoMatchRestarted();
}
