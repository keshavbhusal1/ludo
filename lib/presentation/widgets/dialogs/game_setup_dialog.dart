import 'package:flutter/material.dart';
import '../../../models/game_rules.dart';
import '../../../models/player_color.dart';
import '../../themes/board_theme.dart';

class GameSetupResult {
  final List<PlayerColor> colors;
  final Map<PlayerColor, bool> aiConfig;
  final GameRules rules;
  final BoardThemeType themeType;

  const GameSetupResult({
    required this.colors,
    required this.aiConfig,
    required this.rules,
    this.themeType = BoardThemeType.darkModern,
  });
}

/// Modal configuration dialog for starting a custom match.
class GameSetupDialog extends StatefulWidget {
  final GameSetupResult? initialConfig;

  const GameSetupDialog({super.key, this.initialConfig});

  @override
  State<GameSetupDialog> createState() => _GameSetupDialogState();
}

class _GameSetupDialogState extends State<GameSetupDialog> {
  /// Multipliers offered for bot thinking, dice settling and pawn hops.
  static const List<double> _speedOptions = [1.0, 1.5, 2.0];

  /// Seconds per human decision offered when the turn timer is on.
  static const List<int> _timeLimitOptions = [8, 12, 20, 30];

  /// Timeouts before a bot takes over the seat; 0 means never.
  static const List<int> _maxStrikeOptions = [1, 3, 5, 0];

  int _playerCount = 4;
  final Map<PlayerColor, bool> _aiMap = {
    PlayerColor.red: false,
    PlayerColor.green: true,
    PlayerColor.yellow: true,
    PlayerColor.blue: true,
  };
  WinCondition _winCondition = WinCondition.classic;
  AiDifficulty _aiDifficulty = AiDifficulty.medium;
  double _gameSpeed = 1.0;
  BoardThemeType _themeType = BoardThemeType.darkModern;
  bool _mustCapture = false;
  bool _unlockOneOrSix = false;
  bool _turnTimer = false;
  int _turnSeconds = 12;
  int _maxStrikes = 3;

  @override
  void initState() {
    super.initState();
    if (widget.initialConfig != null) {
      final config = widget.initialConfig!;
      _playerCount = config.colors.length;
      _aiMap.addAll(config.aiConfig);
      _winCondition = config.rules.winCondition;
      _aiDifficulty = config.rules.aiDifficulty;
      _gameSpeed = config.rules.gameSpeed;
      _themeType = config.themeType;
      _mustCapture = config.rules.mustCaptureBeforeHome;
      _unlockOneOrSix = config.rules.unlockYardOnOneOrSix;
      _turnTimer = config.rules.turnTimerEnabled;
      _turnSeconds = config.rules.turnTimeLimitSeconds;
      _maxStrikes = config.rules.turnTimerMaxStrikes;
    }
  }

  /// One of a row of equal-width choices (game speed, time per turn).
  Widget _optionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0EA5E9) : const Color(0xFF334155),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFCBD5E1),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Standard strike choices in display order (Never last), plus the current
  /// value if it's non-standard so it stays selectable.
  List<int> _strikeChoices() {
    final counts = {
      ..._maxStrikeOptions.where((n) => n > 0),
      if (_maxStrikes > 0) _maxStrikes,
    }.toList()
      ..sort();
    return [...counts, 0];
  }

  static String _speedLabel(double speed) =>
      '${speed == speed.roundToDouble() ? speed.toInt() : speed}×';

  List<PlayerColor> _getActiveColors() {
    if (_playerCount == 2) {
      return [PlayerColor.red, PlayerColor.yellow];
    } else if (_playerCount == 3) {
      return [PlayerColor.red, PlayerColor.green, PlayerColor.yellow];
    } else {
      return [PlayerColor.red, PlayerColor.green, PlayerColor.yellow, PlayerColor.blue];
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColors = _getActiveColors();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.84,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune, color: Color(0xFF60A5FA), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Match Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Scrollable Options Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Game Mode (Classic / Quick / Rush)
              const Text(
                'Game Mode',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 6),
              Row(
                children: WinCondition.values.map((mode) {
                  final isSelected = _winCondition == mode;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: InkWell(
                        onTap: () => setState(() => _winCondition = mode),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              mode.name == 'quick1'
                                  ? 'Quick (1)'
                                  : mode.name == 'quick2'
                                      ? 'Rush (2)'
                                      : 'Classic (4)',
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Number of Players
              const Text(
                'Player Count',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [2, 3, 4].map((count) {
                  final isSelected = _playerCount == count;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: InkWell(
                        onTap: () => setState(() => _playerCount = count),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$count Players',
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // AI Difficulty Tier
              const Text(
                'AI Difficulty',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 6),
              Row(
                children: AiDifficulty.values.map((diff) {
                  final isSelected = _aiDifficulty == diff;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: InkWell(
                        onTap: () => setState(() => _aiDifficulty = diff),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              diff.displayName,
                              style: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Game Speed
              const Text(
                'Game Speed',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 6),
              Row(
                children: _speedOptions
                    .map((speed) => _optionChip(
                          label: _speedLabel(speed),
                          selected: _gameSpeed == speed,
                          onTap: () => setState(() => _gameSpeed = speed),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),

              // Board Theme
              const Text(
                'Visual Board Theme',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: BoardThemeType.values.map((th) {
                  final isSelected = _themeType == th;
                  return ChoiceChip(
                    label: Text(th.displayName, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6366F1),
                    onSelected: (val) {
                      if (val) setState(() => _themeType = th);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Active Players (Human vs Bot)
              const Text(
                'Player Slots (Human vs Bot)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 6),
              ...activeColors.map((color) {
                final isAi = _aiMap[color] ?? false;
                final primaryColor = Color(color.primaryColorValue);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        color.displayName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      ChoiceChip(
                        label: const Text('Human', style: TextStyle(fontSize: 11)),
                        selected: !isAi,
                        selectedColor: primaryColor,
                        onSelected: (val) {
                          if (val) setState(() => _aiMap[color] = false);
                        },
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('Bot', style: TextStyle(fontSize: 11)),
                        selected: isAi,
                        selectedColor: const Color(0xFF64748B),
                        onSelected: (val) {
                          if (val) setState(() => _aiMap[color] = true);
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),

              // Rule Toggles
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Must capture before home', style: TextStyle(color: Colors.white, fontSize: 12)),
                subtitle: const Text('Must capture an opponent to enter corridor', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                value: _mustCapture,
                activeThumbColor: const Color(0xFF3B82F6),
                activeTrackColor: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                onChanged: (val) => setState(() => _mustCapture = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Unlock with 1 or 6', style: TextStyle(color: Colors.white, fontSize: 12)),
                subtitle: const Text('Roll either 1 or 6 to exit yard base', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                value: _unlockOneOrSix,
                activeThumbColor: const Color(0xFF3B82F6),
                activeTrackColor: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                onChanged: (val) => setState(() => _unlockOneOrSix = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Turn timer', style: TextStyle(color: Colors.white, fontSize: 12)),
                subtitle: const Text('On timeout a bot plays that turn for the player', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                value: _turnTimer,
                activeThumbColor: const Color(0xFF3B82F6),
                activeTrackColor: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                onChanged: (val) => setState(() => _turnTimer = val),
              ),
              if (_turnTimer) ...[
                const SizedBox(height: 6),
                const Text(
                  'Time per turn',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 6),
                Row(
                  // Keep a non-standard current value (e.g. from code) selectable
                  children: ({..._timeLimitOptions, _turnSeconds}.toList()..sort())
                      .map((secs) => _optionChip(
                            label: '$secs s',
                            selected: _turnSeconds == secs,
                            onTap: () => setState(() => _turnSeconds = secs),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Timeouts before a bot takes over',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 6),
                Row(
                  children: _strikeChoices()
                      .map((n) => _optionChip(
                            label: n == 0 ? 'Never' : '$n',
                            selected: _maxStrikes == n,
                            onTap: () => setState(() => _maxStrikes = n),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),

      // Start Match Button (Pinned at Bottom)
      ElevatedButton(
        onPressed: () {
          final result = GameSetupResult(
            colors: activeColors,
            aiConfig: _aiMap,
            rules: GameRules(
              winCondition: _winCondition,
              aiDifficulty: _aiDifficulty,
              mustCaptureBeforeHome: _mustCapture,
              unlockYardOnOneOrSix: _unlockOneOrSix,
              gameSpeed: _gameSpeed,
              turnTimerEnabled: _turnTimer,
              turnTimeLimitSeconds: _turnSeconds,
              turnTimerMaxStrikes: _maxStrikes,
              // Not editable here; keep the current match's value
              consecutiveSixesLimit:
                  widget.initialConfig?.rules.consecutiveSixesLimit ?? 3,
            ),
            themeType: _themeType,
          );
          Navigator.of(context).pop(result);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: const Text(
          'APPLY & START MATCH',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
      ),
    ],
  ),
),
),
);
}
}
