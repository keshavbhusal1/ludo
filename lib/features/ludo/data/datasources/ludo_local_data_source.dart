import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../../models/saved_match.dart';

/// Data source interface for local match state storage.
abstract class LudoLocalDataSource {
  /// Returns the saved match, or null if none exists. Throws on unreadable data.
  Future<SavedMatch?> loadGame();

  /// Persists [match], replacing any previous save. Throws if the write fails.
  Future<void> saveGame(SavedMatch match);

  /// Removes any saved match.
  Future<void> clearSavedGame();
}

/// Stores the autosaved match as JSON in platform key-value storage
/// (app-private on mobile/desktop, localStorage on web).
///
/// The key predates [SavedMatch]; [SavedMatch.fromJson] still reads the older
/// bare-GameState saves found under it.
class LudoLocalDataSourceImpl implements LudoLocalDataSource {
  static const String autosaveKey = 'ludo_autosave_v1';

  final SharedPreferences _prefs;

  const LudoLocalDataSourceImpl(this._prefs);

  @override
  Future<SavedMatch?> loadGame() async {
    final raw = _prefs.getString(autosaveKey);
    if (raw == null || raw.isEmpty) return null;
    return SavedMatch.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveGame(SavedMatch match) async {
    final ok = await _prefs.setString(autosaveKey, jsonEncode(match.toJson()));
    if (!ok) throw StateError('Platform storage rejected the autosave write');
  }

  @override
  Future<void> clearSavedGame() async {
    await _prefs.remove(autosaveKey);
  }
}
