import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../models/game_state.dart';
import '../repositories/ludo_repository.dart';

/// Use case to load any previously saved match state from local storage.
class GetSavedGameUseCase {
  final LudoRepository repository;

  GetSavedGameUseCase(this.repository);

  Future<Either<Failure, GameState?>> call() => repository.getSavedGame();
}
