import 'package:ludo/features/ludo/data/datasources/ludo_local_data_source.dart';
import 'package:ludo/models/saved_match.dart';

/// Keeps saves in memory. Use in widget tests: real platform storage never
/// completes inside testWidgets' fake-async zone.
class InMemoryLocalDataSource implements LudoLocalDataSource {
  SavedMatch? saved;
  int saveCount = 0;

  InMemoryLocalDataSource([this.saved]);

  @override
  Future<SavedMatch?> loadGame() async => saved;

  @override
  Future<void> saveGame(SavedMatch match) async {
    saveCount++;
    saved = match;
  }

  @override
  Future<void> clearSavedGame() async => saved = null;
}
