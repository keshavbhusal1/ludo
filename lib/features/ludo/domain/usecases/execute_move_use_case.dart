import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../engine/ludo_game_engine.dart';
import '../../../../models/game_state.dart';
import '../../../../models/move.dart';

/// Applies a legal pawn move to a given match state.
class ExecuteMoveUseCase {
  final LudoEngine engine;

  ExecuteMoveUseCase(this.engine);

  Either<Failure, GameState> call(GameState state, Move move) {
    try {
      final next = engine.executeMove(state, move);
      if (identical(next, state)) {
        return Left(InvalidMoveFailure('Move $move is not legal in the current state'));
      }
      return Right(next);
    } catch (e) {
      return Left(InvalidMoveFailure(e.toString()));
    }
  }
}
