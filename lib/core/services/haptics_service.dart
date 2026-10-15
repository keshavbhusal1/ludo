import 'package:flutter/services.dart';

/// Centralized haptic feedback service with vibration patterns.
class HapticsService {
  static bool isEnabled = true;

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

  /// Triggered when a player wins the match.
  static void victory() {
    if (!isEnabled) return;
    HapticFeedback.vibrate();
  }
}
