import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../models/game_state.dart';

/// Contract defining persistence operations for the Ludo match state.
abstract class LudoRepository {
  /// Loads the saved match state from local storage.
  Future<Either<Failure, GameState?>> getSavedGame();

  /// Persists the active match state into local storage.
  Future<Either<Failure, void>> saveGame(GameState state);

  /// Clears any persisted match state from local storage.
  Future<Either<Failure, void>> clearSavedGame();
}
