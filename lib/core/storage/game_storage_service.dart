import 'dart:convert';
import 'dart:io';
import '../../models/game_state.dart';

/// Lightweight offline persistence service for auto-saving and restoring mid-game states.
class GameStorageService {
  static GameState? _memoryCache;

  static File get _storageFile {
    final tempDir = Directory.systemTemp.path;
    return File('$tempDir/ludo_offline_autosave.json');
  }

  /// Automatically saves the current match state to local offline storage.
  static Future<void> saveGame(GameState state) async {
    _memoryCache = state;
    try {
      final jsonStr = jsonEncode(state.toJson());
      await _storageFile.writeAsString(jsonStr, flush: true);
    } catch (_) {
      // Memory fallback is always intact even if disk I/O is restricted
    }
  }

  /// Loads the persisted match state, returning null if no saved match exists or game concluded.
  static Future<GameState?> loadGame() async {
    if (_memoryCache != null && !_memoryCache!.isGameOver) {
      return _memoryCache;
    }

    try {
      final file = _storageFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          final state = GameState.fromJson(jsonMap);
          if (!state.isGameOver) {
            _memoryCache = state;
            return state;
          }
        }
      }
    } catch (_) {
      // Return null on corrupted file
    }
    return null;
  }

  /// Checks if a valid, uncompleted saved match exists to offer resume.
  static Future<bool> hasSavedGame() async {
    if (_memoryCache != null && !_memoryCache!.isGameOver) return true;
    try {
      final file = _storageFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final jsonMap = jsonDecode(content) as Map<String, dynamic>;
          final state = GameState.fromJson(jsonMap);
          return !state.isGameOver;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// Clears saved match upon conclusion.
  static Future<void> clearSavedGame() async {
    _memoryCache = null;
    try {
      final file = _storageFile;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
