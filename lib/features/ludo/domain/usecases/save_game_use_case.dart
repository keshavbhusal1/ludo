import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../models/game_state.dart';
import '../repositories/ludo_repository.dart';

/// Use case to persist the current active match state.
class SaveGameUseCase {
  final LudoRepository repository;

  SaveGameUseCase(this.repository);

  Future<Either<Failure, void>> call(GameState state) => repository.saveGame(state);
}
