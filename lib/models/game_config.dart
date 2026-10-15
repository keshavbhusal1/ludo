import 'game_rules.dart';

/// Configuration for turn timer and disconnection penalty.
class TimerConfig {
  /// Turn duration timeout (default 12 seconds).
  final Duration turnTimeout;

  /// Maximum strikes allowed before penalty / disconnect (default 3 strikes).
  final int maxStrikes;

  /// Whether the turn timer is actively enforced (opt-in).
  final bool enabled;

  const TimerConfig({
    this.turnTimeout = const Duration(seconds: 12),
    this.maxStrikes = 3,
    this.enabled = false,
  });

  TimerConfig copyWith({
    Duration? turnTimeout,
    int? maxStrikes,
    bool? enabled,
  }) {
    return TimerConfig(
      turnTimeout: turnTimeout ?? this.turnTimeout,
      maxStrikes: maxStrikes ?? this.maxStrikes,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'turnTimeoutSeconds': turnTimeout.inSeconds,
        'maxStrikes': maxStrikes,
        'enabled': enabled,
      };

  factory TimerConfig.fromJson(Map<String, dynamic> json) => TimerConfig(
        turnTimeout:
            Duration(seconds: json['turnTimeoutSeconds'] as int? ?? 12),
        maxStrikes: json['maxStrikes'] as int? ?? 3,
        enabled: json['enabled'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerConfig &&
          runtimeType == other.runtimeType &&
          turnTimeout == other.turnTimeout &&
          maxStrikes == other.maxStrikes &&
          enabled == other.enabled;

  @override
  int get hashCode => Object.hash(turnTimeout, maxStrikes, enabled);

  @override
  String toString() =>
      'TimerConfig(${turnTimeout.inSeconds}s, maxStrikes: $maxStrikes, enabled: $enabled)';
}

/// Abstract base class for supported Ludo game modes.
sealed class GameMode {
  final String name;
  final int tokensToWin;
  final bool mandatoryKillRequired;
  final int unlockRoll;
  final int startingUnlockedTokens;

  const GameMode({
    required this.name,
    required this.tokensToWin,
    required this.mandatoryKillRequired,
    required this.unlockRoll,
    this.startingUnlockedTokens = 0,
  });

  Map<String, dynamic> toJson() => {
        'type': name.toLowerCase(),
        'tokensToWin': tokensToWin,
        'mandatoryKillRequired': mandatoryKillRequired,
        'unlockRoll': unlockRoll,
        'startingUnlockedTokens': startingUnlockedTokens,
      };

  factory GameMode.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?)?.toLowerCase();
    switch (type) {
      case 'quick':
      case 'quickmode':
      case 'quick1':
        return QuickMode(
          mandatoryKillRequired:
              json['mandatoryKillRequired'] as bool? ?? true,
          unlockRoll: json['unlockRoll'] as int? ?? 6,
        );
      case 'rush':
      case 'rushmode':
      case 'quick2':
        return RushMode(
          mandatoryKillRequired:
              json['mandatoryKillRequired'] as bool? ?? true,
          unlockRoll: json['unlockRoll'] as int? ?? 6,
        );
      case 'classic':
      case 'classicmode':
      default:
        return ClassicMode(
          mandatoryKillRequired:
              json['mandatoryKillRequired'] as bool? ?? true,
          unlockRoll: json['unlockRoll'] as int? ?? 6,
        );
    }
  }
}

/// Classic Ludo Mode:
/// - 4 tokens to win
/// - Mandatory kill required before entering home column
/// - 6 to unlock token from base
/// - 0 tokens start unlocked
class ClassicMode extends GameMode {
  const ClassicMode({
    super.mandatoryKillRequired = true,
    super.unlockRoll = 6,
  }) : super(
          name: 'Classic',
          tokensToWin: 4,
          startingUnlockedTokens: 0,
        );
}

/// Quick Ludo Mode:
/// - 1 token to win
/// - 1 token starts unlocked on the board start square
/// - Mandatory kill required before entering home column
/// - 6 to unlock remaining tokens from base
class QuickMode extends GameMode {
  const QuickMode({
    super.mandatoryKillRequired = true,
    super.unlockRoll = 6,
  }) : super(
          name: 'Quick',
          tokensToWin: 1,
          startingUnlockedTokens: 1,
        );
}

/// Rush Ludo Mode:
/// - 2 tokens to win
/// - Mandatory kill required
/// - 6 to unlock
class RushMode extends GameMode {
  const RushMode({
    super.mandatoryKillRequired = true,
    super.unlockRoll = 6,
  }) : super(
          name: 'Rush',
          tokensToWin: 2,
          startingUnlockedTokens: 0,
        );
}

/// Complete game configuration object for the Ludo engine.
class GameConfig {
  final GameMode mode;
  final TimerConfig timerConfig;
  final int consecutiveSixesLimit;
  final bool unlockYardOnOneOrSix;
  final double gameSpeed;
  final AiDifficulty aiDifficulty;

  const GameConfig({
    this.mode = const ClassicMode(),
    this.timerConfig = const TimerConfig(),
    this.consecutiveSixesLimit = 3,
    this.unlockYardOnOneOrSix = false,
    this.gameSpeed = 1.0,
    this.aiDifficulty = AiDifficulty.medium,
  });

  /// Factory for Classic Mode
  factory GameConfig.classic({
    TimerConfig timerConfig = const TimerConfig(),
    bool mandatoryKillRequired = true,
    double gameSpeed = 1.0,
    AiDifficulty aiDifficulty = AiDifficulty.medium,
  }) {
    return GameConfig(
      mode: ClassicMode(mandatoryKillRequired: mandatoryKillRequired),
      timerConfig: timerConfig,
      gameSpeed: gameSpeed,
      aiDifficulty: aiDifficulty,
    );
  }

  /// Factory for Quick Mode (1 token to win, 1 starts unlocked, mandatory kill)
  factory GameConfig.quick({
    TimerConfig timerConfig = const TimerConfig(),
    bool mandatoryKillRequired = true,
    double gameSpeed = 1.0,
    AiDifficulty aiDifficulty = AiDifficulty.medium,
  }) {
    return GameConfig(
      mode: QuickMode(mandatoryKillRequired: mandatoryKillRequired),
      timerConfig: timerConfig,
      gameSpeed: gameSpeed,
      aiDifficulty: aiDifficulty,
    );
  }

  /// The engine config for a set of user-facing [rules].
  factory GameConfig.fromRules(GameRules rules) {
    final kill = rules.mustCaptureBeforeHome;
    return GameConfig(
      mode: switch (rules.winCondition) {
        WinCondition.quick1 => QuickMode(mandatoryKillRequired: kill),
        WinCondition.quick2 => RushMode(mandatoryKillRequired: kill),
        WinCondition.classic => ClassicMode(mandatoryKillRequired: kill),
      },
      timerConfig: TimerConfig(enabled: rules.turnTimerEnabled),
      consecutiveSixesLimit: rules.consecutiveSixesLimit,
      unlockYardOnOneOrSix: rules.unlockYardOnOneOrSix,
      gameSpeed: rules.gameSpeed,
      aiDifficulty: rules.aiDifficulty,
    );
  }

  bool get mustCaptureBeforeHome => mode.mandatoryKillRequired;
  int get tokensToWin => mode.tokensToWin;

  GameConfig copyWith({
    GameMode? mode,
    TimerConfig? timerConfig,
    int? consecutiveSixesLimit,
    bool? unlockYardOnOneOrSix,
    double? gameSpeed,
    AiDifficulty? aiDifficulty,
  }) {
    return GameConfig(
      mode: mode ?? this.mode,
      timerConfig: timerConfig ?? this.timerConfig,
      consecutiveSixesLimit:
          consecutiveSixesLimit ?? this.consecutiveSixesLimit,
      unlockYardOnOneOrSix:
          unlockYardOnOneOrSix ?? this.unlockYardOnOneOrSix,
      gameSpeed: gameSpeed ?? this.gameSpeed,
      aiDifficulty: aiDifficulty ?? this.aiDifficulty,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.toJson(),
        'timerConfig': timerConfig.toJson(),
        'consecutiveSixesLimit': consecutiveSixesLimit,
        'unlockYardOnOneOrSix': unlockYardOnOneOrSix,
        'gameSpeed': gameSpeed,
        'aiDifficulty': aiDifficulty.name,
      };

  factory GameConfig.fromJson(Map<String, dynamic> json) => GameConfig(
        mode: json['mode'] != null
            ? GameMode.fromJson(json['mode'] as Map<String, dynamic>)
            : (json['winCondition'] != null
                ? (json['winCondition'] == 'quick1'
                    ? const QuickMode()
                    : (json['winCondition'] == 'quick2'
                        ? const RushMode()
                        : const ClassicMode()))
                : const ClassicMode()),
        timerConfig: json['timerConfig'] != null
            ? TimerConfig.fromJson(
                json['timerConfig'] as Map<String, dynamic>)
            : const TimerConfig(),
        consecutiveSixesLimit: json['consecutiveSixesLimit'] as int? ?? 3,
        unlockYardOnOneOrSix: json['unlockYardOnOneOrSix'] as bool? ?? false,
        gameSpeed: (json['gameSpeed'] as num?)?.toDouble() ?? 1.0,
        aiDifficulty: json['aiDifficulty'] != null
            ? AiDifficulty.fromString(json['aiDifficulty'] as String)
            : AiDifficulty.medium,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameConfig &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          timerConfig == other.timerConfig &&
          consecutiveSixesLimit == other.consecutiveSixesLimit &&
          unlockYardOnOneOrSix == other.unlockYardOnOneOrSix &&
          gameSpeed == other.gameSpeed &&
          aiDifficulty == other.aiDifficulty;

  @override
  int get hashCode => Object.hash(
        mode,
        timerConfig,
        consecutiveSixesLimit,
        unlockYardOnOneOrSix,
        gameSpeed,
        aiDifficulty,
      );

  @override
  String toString() =>
      'GameConfig(mode: ${mode.name}, tokensToWin: ${mode.tokensToWin}, mandatoryKill: ${mode.mandatoryKillRequired}, timer: ${timerConfig.turnTimeout.inSeconds}s)';
}
