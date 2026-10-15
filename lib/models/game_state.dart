import 'game_config.dart';
import 'game_rules.dart';
import 'move.dart';
import 'player.dart';
import 'player_color.dart';

/// Deterministic Finite State Machine (FSM) states for Ludo game flow.
enum LudoFsmState {
  waitingForRoll,
  evaluatingMoves,
  waitingForSelection,
  movingToken,
  turnResolved,
  gameOver;

  static LudoFsmState fromString(String str) {
    final clean = str.toLowerCase().replaceAll('_', '');
    return LudoFsmState.values.firstWhere(
      (s) => s.name.toLowerCase() == clean,
      orElse: () => LudoFsmState.waitingForRoll,
    );
  }
}

/// Constant names matching exact FSM specification.
abstract final class FsmStates {
  static const LudoFsmState waitingForRoll = LudoFsmState.waitingForRoll;
  static const LudoFsmState evaluatingMoves = LudoFsmState.evaluatingMoves;
  static const LudoFsmState waitingForSelection = LudoFsmState.waitingForSelection;
  static const LudoFsmState movingToken = LudoFsmState.movingToken;
  static const LudoFsmState turnResolved = LudoFsmState.turnResolved;
  static const LudoFsmState gameOver = LudoFsmState.gameOver;
}

/// Explicit phases in the turn lifecycle for legacy UI compatibility.
enum TurnPhase {
  awaitingRoll,
  awaitingPawnSelection,
  animatingMove,
  turnTransition,
  gameOver;

  static TurnPhase fromString(String str) {
    return TurnPhase.values.firstWhere(
      (p) => p.name == str,
      orElse: () => TurnPhase.awaitingRoll,
    );
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
  final Move? currentAnimatingMove;
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
    this.currentAnimatingMove,
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
      currentAnimatingMove: null,
      rankings: const [],
    );
  }

  // Compatibility getters
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
      );

  TurnPhase get turnPhase {
    switch (fsmState) {
      case LudoFsmState.waitingForRoll:
      case LudoFsmState.evaluatingMoves:
        return TurnPhase.awaitingRoll;
      case LudoFsmState.waitingForSelection:
        return TurnPhase.awaitingPawnSelection;
      case LudoFsmState.movingToken:
        return TurnPhase.animatingMove;
      case LudoFsmState.turnResolved:
        return TurnPhase.turnTransition;
      case LudoFsmState.gameOver:
        return TurnPhase.gameOver;
    }
  }

  int get consecutiveSixes => consecutiveSixesCount;

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
    GameRules? rules,
    List<Player>? players,
    int? activePlayerIndex,
    LudoFsmState? fsmState,
    TurnPhase? turnPhase,
    int? lastDiceRoll,
    bool clearDiceRoll = false,
    int? consecutiveSixesCount,
    int? consecutiveSixes,
    List<Move>? validMoves,
    Move? currentAnimatingMove,
    bool clearAnimatingMove = false,
    List<PlayerColor>? rankings,
  }) {
    LudoFsmState effectiveFsm = fsmState ?? this.fsmState;
    if (fsmState == null && turnPhase != null) {
      switch (turnPhase) {
        case TurnPhase.awaitingRoll:
          effectiveFsm = LudoFsmState.waitingForRoll;
          break;
        case TurnPhase.awaitingPawnSelection:
          effectiveFsm = LudoFsmState.waitingForSelection;
          break;
        case TurnPhase.animatingMove:
          effectiveFsm = LudoFsmState.movingToken;
          break;
        case TurnPhase.turnTransition:
          effectiveFsm = LudoFsmState.turnResolved;
          break;
        case TurnPhase.gameOver:
          effectiveFsm = LudoFsmState.gameOver;
          break;
      }
    }

    GameConfig effectiveConfig = config ?? this.config;
    if (config == null && rules != null) {
      effectiveConfig = GameConfig.fromRules(rules);
    }

    return GameState(
      id: id ?? this.id,
      config: effectiveConfig,
      players: players ?? this.players,
      activePlayerIndex: activePlayerIndex ?? this.activePlayerIndex,
      fsmState: effectiveFsm,
      lastDiceRoll: clearDiceRoll ? null : (lastDiceRoll ?? this.lastDiceRoll),
      consecutiveSixesCount:
          consecutiveSixesCount ?? consecutiveSixes ?? this.consecutiveSixesCount,
      validMoves: validMoves ?? this.validMoves,
      currentAnimatingMove: clearAnimatingMove
          ? null
          : (currentAnimatingMove ?? this.currentAnimatingMove),
      rankings: rankings ?? this.rankings,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'config': config.toJson(),
        'rules': rules.toJson(),
        'players': players.map((p) => p.toJson()).toList(),
        'activePlayerIndex': activePlayerIndex,
        'fsmState': fsmState.name,
        'turnPhase': turnPhase.name,
        'lastDiceRoll': lastDiceRoll,
        'consecutiveSixesCount': consecutiveSixesCount,
        'consecutiveSixes': consecutiveSixesCount,
        'validMoves': validMoves.map((m) => m.toJson()).toList(),
        'currentAnimatingMove': currentAnimatingMove?.toJson(),
        'rankings': rankings.map((c) => c.name).toList(),
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final config = json['config'] != null
        ? GameConfig.fromJson(json['config'] as Map<String, dynamic>)
        : (json['rules'] != null
            ? GameConfig.fromRules(
                GameRules.fromJson(json['rules'] as Map<String, dynamic>))
            : const GameConfig());

    final fsmState = json['fsmState'] != null
        ? LudoFsmState.fromString(json['fsmState'] as String)
        : (json['turnPhase'] != null
            ? () {
                final tp = TurnPhase.fromString(json['turnPhase'] as String);
                switch (tp) {
                  case TurnPhase.awaitingRoll:
                    return LudoFsmState.waitingForRoll;
                  case TurnPhase.awaitingPawnSelection:
                    return LudoFsmState.waitingForSelection;
                  case TurnPhase.animatingMove:
                    return LudoFsmState.movingToken;
                  case TurnPhase.turnTransition:
                    return LudoFsmState.turnResolved;
                  case TurnPhase.gameOver:
                    return LudoFsmState.gameOver;
                }
              }()
            : LudoFsmState.waitingForRoll);

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
      currentAnimatingMove: json['currentAnimatingMove'] != null
          ? Move.fromJson(
              json['currentAnimatingMove'] as Map<String, dynamic>)
          : null,
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
