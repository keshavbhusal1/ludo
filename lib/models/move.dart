import '../core/coordinates/board_coordinate.dart';
import 'board_position.dart';
import 'player_color.dart';

/// Represents a validated, executable token movement in the game.
class Move {
  /// ID of the token/pawn executing this move.
  final String pawnId;

  /// Player color controlling the token.
  final PlayerColor playerColor;

  /// Dice roll value driving this move (1 to 6).
  final int diceRoll;

  /// Starting state of the token.
  final BoardPosition fromPosition;

  /// Target state of the token after move execution.
  final BoardPosition toPosition;

  /// Starting relative step (-1 if in base/yard).
  final int fromRelativeStep;

  /// Destination relative step.
  final int toRelativeStep;

  /// Whether executing this move captures an opponent token.
  final bool isCapture;

  /// ID of the opponent token captured, if any.
  final String? capturedPawnId;

  /// Whether this move results in the token entering the final home center.
  final bool isReachingHome;

  /// Whether this move unlocks the token from base/yard to the start square.
  final bool isYardExit;

  /// Whether this move awards the active player an extra turn.
  final bool grantsExtraTurn;

  /// Complete list of discrete grid coordinates traversed for step-by-step animation.
  final List<BoardCoordinate> trajectory;

  const Move({
    required this.pawnId,
    required this.playerColor,
    required this.diceRoll,
    required this.fromPosition,
    required this.toPosition,
    required this.fromRelativeStep,
    required this.toRelativeStep,
    this.isCapture = false,
    this.capturedPawnId,
    this.isReachingHome = false,
    this.isYardExit = false,
    this.grantsExtraTurn = false,
    this.trajectory = const [],
  });

  /// Factory constructor using Token nomenclature
  factory Move.token({
    required String tokenId,
    required PlayerColor playerColor,
    required int diceRoll,
    required BoardPosition fromPosition,
    required BoardPosition toPosition,
    required int fromRelativeStep,
    required int toRelativeStep,
    bool isCapture = false,
    String? capturedTokenId,
    bool isReachingHome = false,
    bool isBaseExit = false,
    bool grantsExtraTurn = false,
    List<BoardCoordinate> trajectory = const [],
  }) {
    return Move(
      pawnId: tokenId,
      playerColor: playerColor,
      diceRoll: diceRoll,
      fromPosition: fromPosition,
      toPosition: toPosition,
      fromRelativeStep: fromRelativeStep,
      toRelativeStep: toRelativeStep,
      isCapture: isCapture,
      capturedPawnId: capturedTokenId,
      isReachingHome: isReachingHome,
      isYardExit: isBaseExit,
      grantsExtraTurn: grantsExtraTurn,
      trajectory: trajectory,
    );
  }

  // Token nomenclature getters
  String get tokenId => pawnId;
  String? get capturedTokenId => capturedPawnId;
  bool get isBaseExit => isYardExit;

  Map<String, dynamic> toJson() => {
        'pawnId': pawnId,
        'tokenId': pawnId,
        'playerColor': playerColor.name,
        'diceRoll': diceRoll,
        'fromPosition': fromPosition.toJson(),
        'toPosition': toPosition.toJson(),
        'fromRelativeStep': fromRelativeStep,
        'toRelativeStep': toRelativeStep,
        'isCapture': isCapture,
        'capturedPawnId': capturedPawnId,
        'capturedTokenId': capturedPawnId,
        'isReachingHome': isReachingHome,
        'isYardExit': isYardExit,
        'isBaseExit': isYardExit,
        'grantsExtraTurn': grantsExtraTurn,
        'trajectory': trajectory.map((c) => c.toJson()).toList(),
      };

  factory Move.fromJson(Map<String, dynamic> json) => Move(
        pawnId: (json['pawnId'] ?? json['tokenId']) as String,
        playerColor: PlayerColor.fromString(json['playerColor'] as String),
        diceRoll: json['diceRoll'] as int,
        fromPosition: BoardPosition.fromJson(
            json['fromPosition'] as Map<String, dynamic>),
        toPosition:
            BoardPosition.fromJson(json['toPosition'] as Map<String, dynamic>),
        fromRelativeStep: json['fromRelativeStep'] as int,
        toRelativeStep: json['toRelativeStep'] as int,
        isCapture: json['isCapture'] as bool? ?? false,
        capturedPawnId:
            (json['capturedPawnId'] ?? json['capturedTokenId']) as String?,
        isReachingHome: json['isReachingHome'] as bool? ?? false,
        isYardExit:
            (json['isYardExit'] ?? json['isBaseExit']) as bool? ?? false,
        grantsExtraTurn: json['grantsExtraTurn'] as bool? ?? false,
        trajectory: (json['trajectory'] as List? ?? [])
            .map((c) => BoardCoordinate.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Move &&
          runtimeType == other.runtimeType &&
          pawnId == other.pawnId &&
          playerColor == other.playerColor &&
          diceRoll == other.diceRoll &&
          fromPosition == other.fromPosition &&
          toPosition == other.toPosition &&
          isCapture == other.isCapture &&
          capturedPawnId == other.capturedPawnId;

  @override
  int get hashCode => Object.hash(
        pawnId,
        playerColor,
        diceRoll,
        fromPosition,
        toPosition,
        isCapture,
        capturedPawnId,
      );

  @override
  String toString() =>
      'Move($pawnId: $fromPosition -> $toPosition, roll: $diceRoll, capture: $isCapture)';
}
