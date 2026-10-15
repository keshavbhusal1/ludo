import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/ludo_repository.dart';

/// Use case to wipe any saved game upon victory or new match setup.
class ClearSavedGameUseCase {
  final LudoRepository repository;

  ClearSavedGameUseCase(this.repository);

  Future<Either<Failure, void>> call() => repository.clearSavedGame();
}
