/// Available victory conditions for match length.
enum WinCondition {
  classic(4, 'Classic (4 Tokens)'),
  quick1(1, 'Quick (1 Token)'),
  quick2(2, 'Rush (2 Tokens)');

  final int tokensRequired;
  final String displayName;

  const WinCondition(this.tokensRequired, this.displayName);

  static WinCondition fromString(String str) {
    return WinCondition.values.firstWhere(
      (w) => w.name == str,
      orElse: () => WinCondition.classic,
    );
  }
}

/// Artificial intelligence behavior tier.
enum AiDifficulty {
  easy('Easy'),
  medium('Medium'),
  hard('Grandmaster');

  final String displayName;

  const AiDifficulty(this.displayName);

  static AiDifficulty fromString(String str) {
    return AiDifficulty.values.firstWhere(
      (d) => d.name == str,
      orElse: () => AiDifficulty.medium,
    );
  }
}

/// Configurable rule set for tailoring offline Ludo game mechanics.
class GameRules {
  /// Match victory requirement (Classic 4 tokens, Quick 1 token, Rush 2 tokens).
  final WinCondition winCondition;

  /// AI tactical intelligence level.
  final AiDifficulty aiDifficulty;

  /// If true, a player must capture at least one opponent pawn before entering home corridor.
  final bool mustCaptureBeforeHome;

  /// If true, rolling either a 1 or a 6 can unlock a pawn from the yard.
  final bool unlockYardOnOneOrSix;

  /// Rolling this many sixes in a row forfeits the turn; 0 means no limit.
  final int consecutiveSixesLimit;

  /// Movement animation and bot thinking speed multiplier (1.0, 1.5, 2.0).
  final double gameSpeed;

  /// If true, human turns are timed; on timeout a bot plays the turn and the
  /// player takes a strike. At the strike limit a bot takes over the seat.
  final bool turnTimerEnabled;

  /// Seconds a human has for each decision when [turnTimerEnabled].
  final int turnTimeLimitSeconds;

  /// Timeouts after which a bot takes over the seat; 0 means never.
  final int turnTimerMaxStrikes;

  const GameRules({
    this.winCondition = WinCondition.classic,
    this.aiDifficulty = AiDifficulty.medium,
    this.mustCaptureBeforeHome = false,
    this.unlockYardOnOneOrSix = false,
    this.consecutiveSixesLimit = 3,
    this.gameSpeed = 1.0,
    this.turnTimerEnabled = false,
    this.turnTimeLimitSeconds = 12,
    this.turnTimerMaxStrikes = 3,
  })  : assert(turnTimeLimitSeconds > 0, 'Turn time limit must be positive'),
        assert(turnTimerMaxStrikes >= 0, 'Strike limit must be 0 (never) or more'),
        assert(consecutiveSixesLimit >= 0, 'Sixes limit must be 0 (none) or more');

  GameRules copyWith({
    WinCondition? winCondition,
    AiDifficulty? aiDifficulty,
    bool? mustCaptureBeforeHome,
    bool? unlockYardOnOneOrSix,
    int? consecutiveSixesLimit,
    double? gameSpeed,
    bool? turnTimerEnabled,
    int? turnTimeLimitSeconds,
    int? turnTimerMaxStrikes,
  }) {
    return GameRules(
      winCondition: winCondition ?? this.winCondition,
      aiDifficulty: aiDifficulty ?? this.aiDifficulty,
      mustCaptureBeforeHome:
          mustCaptureBeforeHome ?? this.mustCaptureBeforeHome,
      unlockYardOnOneOrSix: unlockYardOnOneOrSix ?? this.unlockYardOnOneOrSix,
      consecutiveSixesLimit:
          consecutiveSixesLimit ?? this.consecutiveSixesLimit,
      gameSpeed: gameSpeed ?? this.gameSpeed,
      turnTimerEnabled: turnTimerEnabled ?? this.turnTimerEnabled,
      turnTimeLimitSeconds: turnTimeLimitSeconds ?? this.turnTimeLimitSeconds,
      turnTimerMaxStrikes: turnTimerMaxStrikes ?? this.turnTimerMaxStrikes,
    );
  }

  Map<String, dynamic> toJson() => {
        'winCondition': winCondition.name,
        'aiDifficulty': aiDifficulty.name,
        'mustCaptureBeforeHome': mustCaptureBeforeHome,
        'unlockYardOnOneOrSix': unlockYardOnOneOrSix,
        'consecutiveSixesLimit': consecutiveSixesLimit,
        'gameSpeed': gameSpeed,
        'turnTimerEnabled': turnTimerEnabled,
        'turnTimeLimitSeconds': turnTimeLimitSeconds,
        'turnTimerMaxStrikes': turnTimerMaxStrikes,
      };

  factory GameRules.fromJson(Map<String, dynamic> json) => GameRules(
        winCondition: json['winCondition'] != null
            ? WinCondition.fromString(json['winCondition'] as String)
            : WinCondition.classic,
        aiDifficulty: json['aiDifficulty'] != null
            ? AiDifficulty.fromString(json['aiDifficulty'] as String)
            : AiDifficulty.medium,
        mustCaptureBeforeHome: json['mustCaptureBeforeHome'] as bool? ?? false,
        unlockYardOnOneOrSix: json['unlockYardOnOneOrSix'] as bool? ?? false,
        consecutiveSixesLimit: json['consecutiveSixesLimit'] as int? ?? 3,
        gameSpeed: (json['gameSpeed'] as num?)?.toDouble() ?? 1.0,
        turnTimerEnabled: json['turnTimerEnabled'] as bool? ?? false,
        turnTimeLimitSeconds: json['turnTimeLimitSeconds'] as int? ?? 12,
        turnTimerMaxStrikes: json['turnTimerMaxStrikes'] as int? ?? 3,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameRules &&
          runtimeType == other.runtimeType &&
          winCondition == other.winCondition &&
          aiDifficulty == other.aiDifficulty &&
          mustCaptureBeforeHome == other.mustCaptureBeforeHome &&
          unlockYardOnOneOrSix == other.unlockYardOnOneOrSix &&
          consecutiveSixesLimit == other.consecutiveSixesLimit &&
          gameSpeed == other.gameSpeed &&
          turnTimerEnabled == other.turnTimerEnabled &&
          turnTimeLimitSeconds == other.turnTimeLimitSeconds &&
          turnTimerMaxStrikes == other.turnTimerMaxStrikes;

  @override
  int get hashCode => Object.hash(
        winCondition,
        aiDifficulty,
        mustCaptureBeforeHome,
        unlockYardOnOneOrSix,
        consecutiveSixesLimit,
        gameSpeed,
        turnTimerEnabled,
        turnTimeLimitSeconds,
        turnTimerMaxStrikes,
      );

  @override
  String toString() =>
      'GameRules(mode: ${winCondition.name}, AI: ${aiDifficulty.name}, mustCapture: $mustCaptureBeforeHome, speed: ${gameSpeed}x)';
}
