import 'package:fpdart/fpdart.dart';
import '../../../../core/errors/failures.dart';
import '../../../../models/saved_match.dart';
import '../../domain/repositories/ludo_repository.dart';
import '../datasources/ludo_local_data_source.dart';

/// Concrete repository implementation returning fpdart Either for functional error handling.
class LudoRepositoryImpl implements LudoRepository {
  final LudoLocalDataSource localDataSource;

  const LudoRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, SavedMatch?>> getSavedGame() async {
    try {
      final game = await localDataSource.loadGame();
      return Right(game);
    } catch (e) {
      return Left(StorageFailure('Failed to load saved game: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveGame(SavedMatch match) async {
    try {
      await localDataSource.saveGame(match);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure('Failed to save game: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearSavedGame() async {
    try {
      await localDataSource.clearSavedGame();
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure('Failed to clear saved game: $e'));
    }
  }
}
