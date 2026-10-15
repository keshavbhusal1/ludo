import '../../models/player_color.dart';
import 'board_coordinate.dart';

/// Master registry of coordinates for the 15x15 Ludo board.
///
/// Contains the mathematical definitions for:
/// - 52-tile common perimeter track.
/// - 4 Yard quadrants with 4 pawn slots each.
/// - 4 Colored Home Runs (5 tiles each).
/// - 4 Center Home target cells.
/// - Safe zones (4 starting squares + 4 star squares).
class BoardPathRegistry {
  const BoardPathRegistry._();

  /// Total number of tiles on the common perimeter track.
  static const int totalCommonTiles = 52;

  /// Total relative steps from start tile (0) to finished center (56).
  static const int totalPathSteps = 56;

  /// The 52 coordinates of the common outer track in clockwise sequence.
  /// Index 0 corresponds to coordinate (0, 6).
  /// Index 1 corresponds to Red's start square at (1, 6).
  static const List<BoardCoordinate> commonTrack = [
    // 0: Corner before Red start
    BoardCoordinate(0, 6), // 0
    // 1..5: Left arm upper row moving right
    BoardCoordinate(1, 6), // 1: Red Start (Safe)
    BoardCoordinate(2, 6), // 2
    BoardCoordinate(3, 6), // 3
    BoardCoordinate(4, 6), // 4
    BoardCoordinate(5, 6), // 5
    // 6..11: Top arm left col moving up
    BoardCoordinate(6, 5), // 6
    BoardCoordinate(6, 4), // 7
    BoardCoordinate(6, 3), // 8
    BoardCoordinate(6, 2), // 9: Star 1 (Safe)
    BoardCoordinate(6, 1), // 10
    BoardCoordinate(6, 0), // 11
    // 12: Top arm middle top
    BoardCoordinate(7, 0), // 12: Green Home Entrance
    // 13..18: Top arm right col moving down
    BoardCoordinate(8, 0), // 13
    BoardCoordinate(8, 1), // 14: Green Start (Safe)
    BoardCoordinate(8, 2), // 15
    BoardCoordinate(8, 3), // 16
    BoardCoordinate(8, 4), // 17
    BoardCoordinate(8, 5), // 18
    // 19..24: Right arm upper row moving right
    BoardCoordinate(9, 6),  // 19
    BoardCoordinate(10, 6), // 20
    BoardCoordinate(11, 6), // 21
    BoardCoordinate(12, 6), // 22: Star 2 (Safe)
    BoardCoordinate(13, 6), // 23
    BoardCoordinate(14, 6), // 24
    // 25: Right arm middle right
    BoardCoordinate(14, 7), // 25: Yellow Home Entrance
    // 26..31: Right arm lower row moving left
    BoardCoordinate(14, 8), // 26
    BoardCoordinate(13, 8), // 27: Yellow Start (Safe)
    BoardCoordinate(12, 8), // 28
    BoardCoordinate(11, 8), // 29
    BoardCoordinate(10, 8), // 30
    BoardCoordinate(9, 8),  // 31
    // 32..37: Bottom arm right col moving down
    BoardCoordinate(8, 9),  // 32
    BoardCoordinate(8, 10), // 33
    BoardCoordinate(8, 11), // 34
    BoardCoordinate(8, 12), // 35: Star 3 (Safe)
    BoardCoordinate(8, 13), // 36
    BoardCoordinate(8, 14), // 37
    // 38: Bottom arm middle bottom
    BoardCoordinate(7, 14), // 38: Blue Home Entrance
    // 39..44: Bottom arm left col moving up
    BoardCoordinate(6, 14), // 39
    BoardCoordinate(6, 13), // 40: Blue Start (Safe)
    BoardCoordinate(6, 12), // 41
    BoardCoordinate(6, 11), // 42
    BoardCoordinate(6, 10), // 43
    BoardCoordinate(6, 9),  // 44
    // 45..50: Left arm lower row moving left
    BoardCoordinate(5, 8),  // 45
    BoardCoordinate(4, 8),  // 46
    BoardCoordinate(3, 8),  // 47
    BoardCoordinate(2, 8),  // 48: Star 4 (Safe)
    BoardCoordinate(1, 8),  // 49
    BoardCoordinate(0, 8),  // 50
    // 51: Left arm middle left
    BoardCoordinate(0, 7),  // 51: Red Home Entrance
  ];

  /// 5 colored home run coordinates for each player leading towards center.
  static const Map<PlayerColor, List<BoardCoordinate>> homeRuns = {
    PlayerColor.red: [
      BoardCoordinate(1, 7),
      BoardCoordinate(2, 7),
      BoardCoordinate(3, 7),
      BoardCoordinate(4, 7),
      BoardCoordinate(5, 7),
    ],
    PlayerColor.green: [
      BoardCoordinate(7, 1),
      BoardCoordinate(7, 2),
      BoardCoordinate(7, 3),
      BoardCoordinate(7, 4),
      BoardCoordinate(7, 5),
    ],
    PlayerColor.yellow: [
      BoardCoordinate(13, 7),
      BoardCoordinate(12, 7),
      BoardCoordinate(11, 7),
      BoardCoordinate(10, 7),
      BoardCoordinate(9, 7),
    ],
    PlayerColor.blue: [
      BoardCoordinate(7, 13),
      BoardCoordinate(7, 12),
      BoardCoordinate(7, 11),
      BoardCoordinate(7, 10),
      BoardCoordinate(7, 9),
    ],
  };

  /// Center home destination cell for each player (Step 56, Goal / Home Tile Index 5).
  static const Map<PlayerColor, BoardCoordinate> homeCenters = {
    PlayerColor.red: BoardCoordinate(6, 7),
    PlayerColor.green: BoardCoordinate(7, 6),
    PlayerColor.yellow: BoardCoordinate(8, 7),
    PlayerColor.blue: BoardCoordinate(7, 8),
  };

  /// The 4 pawn slot coordinates inside each player's 6x6 home yard.
  static const Map<PlayerColor, List<BoardCoordinate>> yardSlots = {
    PlayerColor.red: [
      BoardCoordinate(1, 1),
      BoardCoordinate(4, 1),
      BoardCoordinate(1, 4),
      BoardCoordinate(4, 4),
    ],
    PlayerColor.green: [
      BoardCoordinate(10, 1),
      BoardCoordinate(13, 1),
      BoardCoordinate(10, 4),
      BoardCoordinate(13, 4),
    ],
    PlayerColor.yellow: [
      BoardCoordinate(10, 10),
      BoardCoordinate(13, 10),
      BoardCoordinate(10, 13),
      BoardCoordinate(13, 13),
    ],
    PlayerColor.blue: [
      BoardCoordinate(1, 10),
      BoardCoordinate(4, 10),
      BoardCoordinate(1, 13),
      BoardCoordinate(4, 13),
    ],
  };

  /// Set of 8 global safe track indices (4 start squares + 4 star squares).
  static const Set<int> safeTrackIndices = {
    1,  // Red Start
    9,  // Star 1
    14, // Green Start
    22, // Star 2
    27, // Yellow Start
    35, // Star 3
    40, // Blue Start
    48, // Star 4
  };

  /// Returns true if the common track index is a designated safe zone.
  static bool isSafeTrackIndex(int trackIndex) => safeTrackIndices.contains(trackIndex);

  /// Converts a player's relative progress step (0 to 56) to its corresponding 15x15 [BoardCoordinate].
  ///
  /// - Step 0: Player's start tile on common track.
  /// - Step 1..50: Continuous progression along common track.
  /// - Step 51..55: Home run colored tiles (0 to 4).
  /// - Step 56: Home center destination.
  static BoardCoordinate getCoordinateForStep(PlayerColor color, int relativeStep) {
    assert(relativeStep >= 0 && relativeStep <= totalPathSteps, 'Step out of bounds: $relativeStep');

    if (relativeStep <= 50) {
      final trackIndex = (color.startTrackIndex + relativeStep) % totalCommonTiles;
      return commonTrack[trackIndex];
    } else if (relativeStep <= 55) {
      final homeRunIndex = relativeStep - 51;
      return homeRuns[color]![homeRunIndex];
    } else {
      return homeCenters[color]!;
    }
  }

  /// Calculates the step-by-step path between two relative steps.
  /// Used by animation controllers for hopped interpolation.
  static List<BoardCoordinate> getTrajectoryCoordinates(
    PlayerColor color,
    int fromStep,
    int toStep,
  ) {
    final trajectory = <BoardCoordinate>[];
    for (int step = fromStep; step <= toStep; step++) {
      trajectory.add(getCoordinateForStep(color, step));
    }
    return trajectory;
  }
}
