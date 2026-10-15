import 'move.dart';
import 'player_color.dart';

/// How a dice roll resolved.
enum TurnOutcome {
  /// A token moved (see [HistoryEntry.move]).
  moved,

  /// No legal move existed; the turn passed.
  noMoves,

  /// The consecutive-sixes limit was hit; the turn was forfeited.
  sixesPenalty,
}

/// One resolved dice roll in a match, for the move history log.
class HistoryEntry {
  final PlayerColor color;
  final String playerName;
  final int roll;
  final TurnOutcome outcome;

  /// The move played, when [outcome] is [TurnOutcome.moved].
  final Move? move;

  /// Name of the player whose token was captured, if [move] captured one.
  final String? capturedPlayerName;

  const HistoryEntry({
    required this.color,
    required this.playerName,
    required this.roll,
    required this.outcome,
    this.move,
    this.capturedPlayerName,
  }) : assert(outcome != TurnOutcome.moved || move != null,
            'A moved entry needs its move');

  /// Human-readable summary, e.g. "rolled 4 — captured Green's token".
  String get description {
    switch (outcome) {
      case TurnOutcome.noMoves:
        return 'rolled $roll — no legal moves';
      case TurnOutcome.sixesPenalty:
        return 'rolled too many 6s in a row — turn forfeited';
      case TurnOutcome.moved:
        final m = move!;
        if (m.isCapture) {
          return "rolled $roll — captured ${capturedPlayerName ?? 'an opponent'}'s token";
        }
        if (m.isReachingHome) return 'rolled $roll — token reached home';
        if (m.isYardExit) return 'rolled $roll — brought a token out';
        if (m.fromRelativeStep <= 50 && m.toRelativeStep > 50) {
          return 'rolled $roll — token entered the home column';
        }
        return 'rolled $roll — moved a token $roll spaces';
    }
  }

  Map<String, dynamic> toJson() => {
        'color': color.name,
        'playerName': playerName,
        'roll': roll,
        'outcome': outcome.name,
        // The animation path isn't needed for the log; it's most of a move's JSON.
        if (move != null) 'move': move!.toJson()..remove('trajectory'),
        'capturedPlayerName': capturedPlayerName,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        color: PlayerColor.fromString(json['color'] as String),
        playerName: json['playerName'] as String,
        roll: json['roll'] as int,
        outcome: TurnOutcome.values.byName(json['outcome'] as String),
        move: json['move'] != null
            ? Move.fromJson(json['move'] as Map<String, dynamic>)
            : null,
        capturedPlayerName: json['capturedPlayerName'] as String?,
      );

  @override
  String toString() => '$playerName $description';
}
