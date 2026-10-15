import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../engine/ludo_game_controller.dart';
import '../../../../models/game_state.dart';
import '../../../../models/move.dart';

/// Pure domain use case responsible for executing legal pawn moves.
class ExecuteMoveUseCase {
  final LudoGameController controller;

  ExecuteMoveUseCase(this.controller);

  Either<Failure, GameState> call(Move move) {
    try {
      final state = controller.executeMove(move);
      return Right(state);
    } catch (e) {
      return Left(InvalidMoveFailure(e.toString()));
    }
  }
}
