import '../../../../core/storage/game_storage_service.dart';
import '../../../../models/game_state.dart';

/// Data source interface for local match state storage.
abstract class LudoLocalDataSource {
  Future<GameState?> loadGame();
  Future<void> saveGame(GameState state);
  Future<void> clearSavedGame();
  Future<bool> hasSavedGame();
}

/// Concrete implementation delegating to the offline file persistence service.
class LudoLocalDataSourceImpl implements LudoLocalDataSource {
  const LudoLocalDataSourceImpl();

  @override
  Future<GameState?> loadGame() => GameStorageService.loadGame();

  @override
  Future<void> saveGame(GameState state) => GameStorageService.saveGame(state);

  @override
  Future<void> clearSavedGame() => GameStorageService.clearSavedGame();

  @override
  Future<bool> hasSavedGame() => GameStorageService.hasSavedGame();
}
