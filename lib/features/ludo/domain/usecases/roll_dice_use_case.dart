import 'dart:math';

import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../engine/ludo_game_engine.dart';
import '../../../../models/game_state.dart';

/// Rolls the dice for the active player of a given match state.
///
/// Owns the only randomness in a turn; inject [random] for deterministic play.
class RollDiceUseCase {
  final LudoEngine engine;
  final Random _random;

  RollDiceUseCase(this.engine, {Random? random}) : _random = random ?? Random();

  Either<Failure, GameState> call(GameState state, {int? forcedRoll}) {
    try {
      return Right(engine.rollDice(state, forcedRoll ?? _random.nextInt(6) + 1));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
