import 'game_state.dart';
import 'history_entry.dart';

/// A position the player can undo back to: a human choosing between tokens.
class UndoPoint {
  final GameState state;

  /// Length of the move history at this point; undo truncates back to it.
  final int historyLength;

  const UndoPoint({required this.state, required this.historyLength});

  Map<String, dynamic> toJson() => {
        'state': state.toJson(),
        'historyLength': historyLength,
      };

  factory UndoPoint.fromJson(Map<String, dynamic> json) => UndoPoint(
        state: GameState.fromJson(json['state'] as Map<String, dynamic>),
        historyLength: json['historyLength'] as int,
      );
}

/// Everything persisted for an unfinished match: the game, its move history,
/// and recent undo points.
class SavedMatch {
  /// Bumped when the JSON layout or meaning changes.
  /// - 1: a bare [GameState].
  /// - 2: game + history + undo points.
  /// - 3: the turn timer became opt-in. Earlier saves recorded it as enabled
  ///   although nothing enforced it, so it's switched off when loading them.
  static const int formatVersion = 3;

  /// Undo points written to storage; each is ~5 KB of JSON and the save is
  /// rewritten on every roll, so only the most recent are kept.
  static const int maxPersistedUndoPoints = 10;

  final GameState game;
  final List<HistoryEntry> history;
  final List<UndoPoint> undoStack;

  const SavedMatch({
    required this.game,
    this.history = const [],
    this.undoStack = const [],
  });

  Map<String, dynamic> toJson() {
    final points = undoStack.length > maxPersistedUndoPoints
        ? undoStack.sublist(undoStack.length - maxPersistedUndoPoints)
        : undoStack;
    // When sitting at the latest choice point, store that state once. Undo
    // relies on this being the same object after loading (see fromJson).
    final gameIsLatestUndoPoint = points.isNotEmpty && identical(points.last.state, game);

    return {
      'format': formatVersion,
      'gameIsLatestUndoPoint': gameIsLatestUndoPoint,
      if (!gameIsLatestUndoPoint) 'game': game.toJson(),
      'history': history.map((e) => e.toJson()).toList(),
      'undoStack': points.map((p) => p.toJson()).toList(),
    };
  }

  /// Reads the current format, or a version 1 save (a bare [GameState]).
  factory SavedMatch.fromJson(Map<String, dynamic> json) {
    final format = json['format'] as int?;
    if (format == null) {
      return SavedMatch(game: _withoutTimer(GameState.fromJson(json)));
    }
    if (format > formatVersion) {
      throw FormatException('Saved match format $format is newer than supported ($formatVersion)');
    }

    GameState migrate(GameState g) => format < 3 ? _withoutTimer(g) : g;

    final undoStack = (json['undoStack'] as List? ?? []).map((p) {
      final point = UndoPoint.fromJson(p as Map<String, dynamic>);
      return UndoPoint(state: migrate(point.state), historyLength: point.historyLength);
    }).toList();
    final game = json['gameIsLatestUndoPoint'] == true
        ? undoStack.last.state
        : migrate(GameState.fromJson(json['game'] as Map<String, dynamic>));

    return SavedMatch(
      game: game,
      history: (json['history'] as List? ?? [])
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      undoStack: undoStack,
    );
  }

  static GameState _withoutTimer(GameState g) => g.copyWith(
        config: g.config.copyWith(
          timerConfig: g.config.timerConfig.copyWith(enabled: false),
        ),
      );
}
