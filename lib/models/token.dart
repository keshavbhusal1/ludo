import 'board_position.dart';
import 'player_color.dart';

/// Immutable model representing an individual Ludo token.
class Token {
  /// Unique identifier (e.g. "red_0", "token_green_2").
  final String id;

  /// The player color this token belongs to.
  final PlayerColor color;

  /// Index of the token within the player's 4-token set (0 to 3).
  final int index;

  /// The current state and location of the token on the board.
  final BoardPosition position;

  const Token({
    required this.id,
    required this.color,
    required this.index,
    required this.position,
  }) : assert(index >= 0 && index <= 3, 'Token index must be 0..3');

  /// Creates a token initialized in its base or unlocked at starting square.
  factory Token.initial(
    PlayerColor color,
    int index, {
    bool unlocked = false,
  }) {
    return Token(
      id: '${color.name}_$index',
      color: color,
      index: index,
      position: unlocked
          ? BoardPosition.track(
              trackIndex: color.startTrackIndex,
              relativeStep: 0,
            )
          : BoardPosition.base(index),
    );
  }

  bool get isInBase => position.isInBase;
  bool get isOnTrack => position.isOnTrack;
  bool get isInHomeColumn => position.isInHomeColumn;
  bool get isGoal => position.isGoal;


  int get relativeStep => position.relativeStep;

  Token copyWith({
    String? id,
    PlayerColor? color,
    int? index,
    BoardPosition? position,
  }) {
    return Token(
      id: id ?? this.id,
      color: color ?? this.color,
      index: index ?? this.index,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color.name,
        'index': index,
        'position': position.toJson(),
      };

  factory Token.fromJson(Map<String, dynamic> json) => Token(
        id: json['id'] as String,
        color: PlayerColor.fromString(json['color'] as String),
        index: json['index'] as int,
        position:
            BoardPosition.fromJson(json['position'] as Map<String, dynamic>),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          color == other.color &&
          index == other.index &&
          position == other.position;

  @override
  int get hashCode => Object.hash(id, color, index, position);

  @override
  String toString() => 'Token($id, pos: $position)';
}
