import 'dart:math';

import 'package:ludo/engine/ludo_engine.dart';

/// Test convenience: a mutable cursor over the pure [LudoEngine], so scenario
/// tests can roll and move step by step without threading state by hand.
/// The app itself never uses this; the bloc owns its [GameState].
class LudoGameController {
  static const _engine = LudoEngine();

  GameState _state;
  final Random _random;

  /// Plays the only legal move straight away, as some house rules do.
  final bool autoExecuteSingleMove;

  LudoGameController({
    required GameState initialState,
    Random? random,
    this.autoExecuteSingleMove = true,
  })  : _state = initialState,
        _random = random ?? Random();

  factory LudoGameController.newGame({
    required List<PlayerColor> colors,
    Map<PlayerColor, bool>? aiConfig,
    GameConfig? config,
    GameRules rules = const GameRules(),
    Random? random,
    bool autoExecuteSingleMove = true,
  }) {
    return LudoGameController(
      initialState: _engine.newGame(
        colors: colors,
        aiConfig: aiConfig,
        config: config,
        rules: rules,
      ),
      random: random,
      autoExecuteSingleMove: autoExecuteSingleMove,
    );
  }

  GameState get state => _state;

  void startNewGame({
    required List<PlayerColor> colors,
    Map<PlayerColor, bool>? aiConfig,
    GameConfig? config,
    GameRules rules = const GameRules(),
  }) {
    _state = _engine.newGame(colors: colors, aiConfig: aiConfig, config: config, rules: rules);
  }

  GameState rollDice([int? forcedValue]) {
    _state = _engine.rollDice(_state, forcedValue ?? _random.nextInt(6) + 1);
    if (autoExecuteSingleMove && _state.validMoves.length == 1) {
      _state = _engine.executeMove(_state, _state.validMoves.single);
    }
    return _state;
  }

  GameState executeMove(Move move) => _state = _engine.executeMove(_state, move);

  GameState handleTurnTimeout() => _state = _engine.handleTurnTimeout(_state);

  void restoreState(GameState restored) => _state = restored;
}
