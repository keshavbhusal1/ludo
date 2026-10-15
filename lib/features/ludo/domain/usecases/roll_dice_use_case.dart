import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../engine/ludo_game_controller.dart';
import '../../../../models/game_state.dart';

/// Pure domain use case responsible for rolling the dice and updating turn math.
class RollDiceUseCase {
  final LudoGameController controller;

  RollDiceUseCase(this.controller);

  Either<Failure, GameState> call({int? forcedRoll}) {
    try {
      final state = controller.rollDice(forcedRoll);
      return Right(state);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
