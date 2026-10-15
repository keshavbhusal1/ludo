import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../models/saved_match.dart';
import '../repositories/ludo_repository.dart';

/// Use case to load any previously saved match state from local storage.
class GetSavedGameUseCase {
  final LudoRepository repository;

  GetSavedGameUseCase(this.repository);

  Future<Either<Failure, SavedMatch?>> call() => repository.getSavedGame();
}
