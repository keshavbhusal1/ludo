import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../models/saved_match.dart';
import '../repositories/ludo_repository.dart';

/// Use case to persist the current active match state.
class SaveGameUseCase {
  final LudoRepository repository;

  SaveGameUseCase(this.repository);

  Future<Either<Failure, void>> call(SavedMatch match) => repository.saveGame(match);
}
