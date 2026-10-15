import 'game_config.dart';
import 'game_rules.dart';
import 'move.dart';
import 'player.dart';
import 'player_color.dart';

/// Where the active player's turn stands.
enum LudoFsmState {
  /// The active player needs to roll.
  waitingForRoll,

  /// The active player rolled and must choose one of [GameState.validMoves].
  waitingForSelection,

  gameOver;

  /// Parses a stored name, including the older names found in earlier saves
  /// ("awaitingRoll", "awaitingPawnSelection", "evaluatingMoves", ...).
  static LudoFsmState fromString(String str) {
    switch (str.toLowerCase().replaceAll('_', '')) {
      case 'waitingforselection':
      case 'awaitingpawnselection':
        return LudoFsmState.waitingForSelection;
      case 'gameover':
        return LudoFsmState.gameOver;
      default:
        return LudoFsmState.waitingForRoll;
    }
  }
}

/// Fully immutable root aggregate capturing the complete state of a Ludo match.
class GameState {
  final String id;
  final GameConfig config;
  final List<Player> players;
  final int activePlayerIndex;
  final LudoFsmState fsmState;
  final int? lastDiceRoll;
  final int consecutiveSixesCount;
  final List<Move> validMoves;
  final List<PlayerColor> rankings;

  const GameState({
    required this.id,
    this.config = const GameConfig(),
    required this.players,
    this.activePlayerIndex = 0,
    this.fsmState = LudoFsmState.waitingForRoll,
    this.lastDiceRoll,
    this.consecutiveSixesCount = 0,
    this.validMoves = const [],
    this.rankings = const [],
  }) : assert(players.length >= 2 && players.length <= 4, 'Must have 2 to 4 players');

  /// Creates a standard new game.
  factory GameState.initial({
    required List<PlayerColor> colors,
    Map<PlayerColor, bool>? aiConfig,
    GameConfig? config,
    GameRules? rules,
    String? gameId,
  }) {
    assert(colors.length >= 2 && colors.length <= 4, 'Game must have 2 to 4 players');

    final effectiveConfig =
        config ?? (rules != null ? GameConfig.fromRules(rules) : const GameConfig());

    final unlockedPerPlayer = effectiveConfig.mode.startingUnlockedTokens;

    final players = colors.map((c) {
      final isAi = aiConfig?[c] ?? false;
      return Player.initial(
        color: c,
        isAi: isAi,
        unlockedTokensCount: unlockedPerPlayer,
      );
    }).toList();

    return GameState(
      id: gameId ?? 'ludo_${DateTime.now().millisecondsSinceEpoch}',
      config: effectiveConfig,
      players: players,
      activePlayerIndex: 0,
      fsmState: LudoFsmState.waitingForRoll,
      lastDiceRoll: null,
      consecutiveSixesCount: 0,
      validMoves: const [],
      rankings: const [],
    );
  }

  /// The user-facing rules this match's [config] corresponds to.
  GameRules get rules => GameRules(
        winCondition: config.mode is QuickMode
            ? WinCondition.quick1
            : (config.mode is RushMode ? WinCondition.quick2 : WinCondition.classic),
        aiDifficulty: config.aiDifficulty,
        mustCaptureBeforeHome: config.mode.mandatoryKillRequired,
        unlockYardOnOneOrSix: config.unlockYardOnOneOrSix,
        consecutiveSixesLimit: config.consecutiveSixesLimit,
        gameSpeed: config.gameSpeed,
        turnTimerEnabled: config.timerConfig.enabled,
        // Rounded up: sub-second limits (tests) still map to a valid rule
        turnTimeLimitSeconds:
            (config.timerConfig.turnTimeout.inMilliseconds / 1000).ceil().clamp(1, 1 << 20),
        turnTimerMaxStrikes: config.timerConfig.maxStrikes,
      );

  Player get activePlayer => players[activePlayerIndex];
  PlayerColor get activePlayerColor => activePlayer.color;
  bool get isGameOver => fsmState == LudoFsmState.gameOver;
  PlayerColor? get winner => rankings.isNotEmpty ? rankings.first : null;

  /// Retrieves a specific player by color.
  Player? getPlayer(PlayerColor color) {
    try {
      return players.firstWhere((p) => p.color == color);
    } catch (_) {
      return null;
    }
  }

  GameState copyWith({
    String? id,
    GameConfig? config,
    List<Player>? players,
    int? activePlayerIndex,
    LudoFsmState? fsmState,
    int? lastDiceRoll,
    bool clearDiceRoll = false,
    int? consecutiveSixesCount,
    List<Move>? validMoves,
    List<PlayerColor>? rankings,
  }) {
    return GameState(
      id: id ?? this.id,
      config: config ?? this.config,
      players: players ?? this.players,
      activePlayerIndex: activePlayerIndex ?? this.activePlayerIndex,
      fsmState: fsmState ?? this.fsmState,
      lastDiceRoll: clearDiceRoll ? null : (lastDiceRoll ?? this.lastDiceRoll),
      consecutiveSixesCount: consecutiveSixesCount ?? this.consecutiveSixesCount,
      validMoves: validMoves ?? this.validMoves,
      rankings: rankings ?? this.rankings,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'config': config.toJson(),
        'players': players.map((p) => p.toJson()).toList(),
        'activePlayerIndex': activePlayerIndex,
        'fsmState': fsmState.name,
        'lastDiceRoll': lastDiceRoll,
        'consecutiveSixesCount': consecutiveSixesCount,
        'validMoves': validMoves.map((m) => m.toJson()).toList(),
        'rankings': rankings.map((c) => c.name).toList(),
      };

  /// Also reads the older key names found in earlier saves ("rules" instead
  /// of "config", "turnPhase", "consecutiveSixes").
  factory GameState.fromJson(Map<String, dynamic> json) {
    final config = json['config'] != null
        ? GameConfig.fromJson(json['config'] as Map<String, dynamic>)
        : (json['rules'] != null
            ? GameConfig.fromRules(
                GameRules.fromJson(json['rules'] as Map<String, dynamic>))
            : const GameConfig());

    final fsmName = (json['fsmState'] ?? json['turnPhase']) as String?;
    final fsmState =
        fsmName != null ? LudoFsmState.fromString(fsmName) : LudoFsmState.waitingForRoll;

    return GameState(
      id: json['id'] as String,
      config: config,
      players: (json['players'] as List)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      activePlayerIndex: json['activePlayerIndex'] as int,
      fsmState: fsmState,
      lastDiceRoll: json['lastDiceRoll'] as int?,
      consecutiveSixesCount:
          (json['consecutiveSixesCount'] ?? json['consecutiveSixes']) as int? ?? 0,
      validMoves: (json['validMoves'] as List? ?? [])
          .map((m) => Move.fromJson(m as Map<String, dynamic>))
          .toList(),
      rankings: (json['rankings'] as List? ?? [])
          .map((c) => PlayerColor.fromString(c as String))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          activePlayerIndex == other.activePlayerIndex &&
          fsmState == other.fsmState &&
          lastDiceRoll == other.lastDiceRoll &&
          consecutiveSixesCount == other.consecutiveSixesCount;

  @override
  int get hashCode => Object.hash(
        id,
        activePlayerIndex,
        fsmState,
        lastDiceRoll,
        consecutiveSixesCount,
      );

  @override
  String toString() =>
      'GameState(id: $id, active: ${activePlayer.name}, fsm: ${fsmState.name}, roll: $lastDiceRoll)';
}
