import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/move.dart';

/// Centralized haptic feedback service with vibration patterns.
class HapticsService {
  static const String enabledKey = 'haptics_enabled';

  /// Read directly by the feedback methods; change it with [setEnabled] so
  /// the choice is saved.
  static bool isEnabled = true;

  static SharedPreferences? _prefs;

  /// Restores the saved on/off choice (default on) and saves future changes to [prefs].
  static void loadFrom(SharedPreferences prefs) {
    _prefs = prefs;
    isEnabled = prefs.getBool(enabledKey) ?? true;
  }

  /// Switches haptics on or off and remembers the choice across launches.
  static Future<void> setEnabled(bool enabled) async {
    isEnabled = enabled;
    await _prefs?.setBool(enabledKey, enabled);
  }

  /// Triggered during dice roll shaking/spinning.
  static void diceRoll() {
    if (!isEnabled) return;
    HapticFeedback.lightImpact();
  }

  /// Triggered when a token hops onto a cell.
  static void pawnHop() {
    if (!isEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// Triggered when an opponent token is captured.
  static void capture() {
    if (!isEnabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Triggered when a token reaches the home center.
  static void tokenHome() {
    if (!isEnabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Triggered when a move's animation lands: a capture or a token reaching
  /// home gets its own pattern; ordinary moves already had their hop.
  static void moveLanded(Move move) {
    if (move.isCapture) {
      capture();
    } else if (move.isReachingHome) {
      tokenHome();
    }
  }

  /// Triggered when a player wins the match.
  static void victory() {
    if (!isEnabled) return;
    HapticFeedback.vibrate();
  }
}
