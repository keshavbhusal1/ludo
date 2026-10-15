/// The four canonical player colors in Ludo arranged clockwise.
enum PlayerColor {
  red(
    startTrackIndex: 1,
    homeEntranceTrackIndex: 51,
    starTrackIndex: 9,
  ),
  green(
    startTrackIndex: 14,
    homeEntranceTrackIndex: 12,
    starTrackIndex: 22,
  ),
  yellow(
    startTrackIndex: 27,
    homeEntranceTrackIndex: 25,
    starTrackIndex: 35,
  ),
  blue(
    startTrackIndex: 40,
    homeEntranceTrackIndex: 38,
    starTrackIndex: 48,
  );

  final int startTrackIndex;
  final int homeEntranceTrackIndex;
  final int starTrackIndex;

  const PlayerColor({
    required this.startTrackIndex,
    required this.homeEntranceTrackIndex,
    required this.starTrackIndex,
  });

  /// Name formatted for display (e.g. "Red").
  String get displayName => name[0].toUpperCase() + name.substring(1);

  /// Primary 32-bit ARGB color integer for offline rendering without Flutter dependency.
  int get primaryColorValue {
    switch (this) {
      case PlayerColor.red:
        return 0xFFE53935; // Material Red 600
      case PlayerColor.green:
        return 0xFF43A047; // Material Green 600
      case PlayerColor.yellow:
        return 0xFFFDD835; // Material Yellow 600
      case PlayerColor.blue:
        return 0xFF1E88E5; // Material Blue 600
    }
  }

  /// Dark shade for pawn borders, dice pips, and path highlights.
  int get darkColorValue {
    switch (this) {
      case PlayerColor.red:
        return 0xFFB71C1C;
      case PlayerColor.green:
        return 0xFF1B5E20;
      case PlayerColor.yellow:
        return 0xFFF57F17;
      case PlayerColor.blue:
        return 0xFF0D47A1;
    }
  }

  /// Next color clockwise.
  PlayerColor get nextClockwise {
    switch (this) {
      case PlayerColor.red:
        return PlayerColor.green;
      case PlayerColor.green:
        return PlayerColor.yellow;
      case PlayerColor.yellow:
        return PlayerColor.blue;
      case PlayerColor.blue:
        return PlayerColor.red;
    }
  }

  static PlayerColor fromString(String str) {
    return PlayerColor.values.firstWhere(
      (c) => c.name.toLowerCase() == str.toLowerCase(),
      orElse: () => PlayerColor.red,
    );
  }
}
