import 'player_color.dart';
import 'token.dart';

/// Immutable model representing an active participant in a Ludo match (Human or AI).
class Player {
  final String id;
  final PlayerColor color;
  final String name;
  final bool isAi;
  final List<Token> tokens;
  final bool hasKilledOpponent;
  final int strikes;
  final bool isDisconnected;

  const Player({
    required this.id,
    required this.color,
    required this.name,
    this.isAi = false,
    required this.tokens,
    this.hasKilledOpponent = false,
    this.strikes = 0,
    this.isDisconnected = false,
  }) : assert(tokens.length == 4, 'A Ludo player must have exactly 4 tokens');

  /// Creates a player with 4 initial tokens.
  /// If [unlockedTokensCount] > 0 (e.g. QuickMode), the first token starts unlocked on the board track.
  factory Player.initial({
    required PlayerColor color,
    String? name,
    bool isAi = false,
    int unlockedTokensCount = 0,
  }) {
    final effectiveName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : (isAi ? 'Bot ${color.displayName}' : color.displayName);

    final tokens = List.generate(4, (index) {
      final isUnlocked = index < unlockedTokensCount;
      return Token.initial(color, index, unlocked: isUnlocked);
    });

    return Player(
      id: 'player_${color.name}',
      color: color,
      name: effectiveName,
      isAi: isAi,
      tokens: tokens,
      hasKilledOpponent: false,
      strikes: 0,
      isDisconnected: false,
    );
  }

  /// Whether a bot plays this seat: a bot from the start, or a human whose
  /// seat was taken over after too many turn timeouts.
  bool get isBotControlled => isAi || isDisconnected;

  int get finishedTokenCount => tokens.where((t) => t.isGoal).length;

  Player copyWith({
    String? id,
    PlayerColor? color,
    String? name,
    bool? isAi,
    List<Token>? tokens,
    bool? hasKilledOpponent,
    int? strikes,
    bool? isDisconnected,
  }) {
    return Player(
      id: id ?? this.id,
      color: color ?? this.color,
      name: name ?? this.name,
      isAi: isAi ?? this.isAi,
      tokens: tokens ?? this.tokens,
      hasKilledOpponent: hasKilledOpponent ?? this.hasKilledOpponent,
      strikes: strikes ?? this.strikes,
      isDisconnected: isDisconnected ?? this.isDisconnected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color.name,
        'name': name,
        'isAi': isAi,
        'tokens': tokens.map((t) => t.toJson()).toList(),
        'hasKilledOpponent': hasKilledOpponent,
        'strikes': strikes,
        'isDisconnected': isDisconnected,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final color = PlayerColor.fromString(json['color'] as String);
    final rawName = json['name'] as String?;
    final isAi = json['isAi'] as bool? ?? false;
    final effectiveName = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : (isAi ? 'Bot ${color.displayName}' : color.displayName);

    final rawTokens = json['tokens'] ?? json['pawns'];
    final tokens = (rawTokens as List)
        .map((t) => Token.fromJson(t as Map<String, dynamic>))
        .toList();

    return Player(
      id: json['id'] as String? ?? 'player_${color.name}',
      color: color,
      name: effectiveName,
      isAi: isAi,
      tokens: tokens,
      hasKilledOpponent: (json['hasKilledOpponent'] ??
          json['hasCapturedOpponent']) as bool? ??
          false,
      strikes: json['strikes'] as int? ?? 0,
      isDisconnected: json['isDisconnected'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          color == other.color &&
          name == other.name &&
          isAi == other.isAi &&
          hasKilledOpponent == other.hasKilledOpponent &&
          strikes == other.strikes &&
          isDisconnected == other.isDisconnected;

  @override
  int get hashCode => Object.hash(
        id,
        color,
        name,
        isAi,
        hasKilledOpponent,
        strikes,
        isDisconnected,
      );

  @override
  String toString() =>
      'Player($name, color: ${color.name}, killed: $hasKilledOpponent, home: $finishedTokenCount/4)';
}
