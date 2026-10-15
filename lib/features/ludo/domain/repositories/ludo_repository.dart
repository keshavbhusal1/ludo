import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../models/saved_match.dart';

/// Contract defining persistence operations for the Ludo match state.
abstract class LudoRepository {
  /// Loads the saved match state from local storage.
  Future<Either<Failure, SavedMatch?>> getSavedGame();

  /// Persists the active match state into local storage.
  Future<Either<Failure, void>> saveGame(SavedMatch match);

  /// Clears any persisted match state from local storage.
  Future<Either<Failure, void>> clearSavedGame();
}
