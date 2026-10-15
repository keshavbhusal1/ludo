import 'board_position.dart';

export 'board_position.dart';

/// Legacy alias for [BoardPosition].
typedef PawnPosition = BoardPosition;

/// The pawn is resting in its home yard base.
class PawnPositionInYard extends BoardPositionBase {
  const PawnPositionInYard(super.slotIndex);
}

/// The pawn is actively moving along the 52-tile common perimeter track.
class PawnPositionOnTrack extends BoardPositionTrack {
  const PawnPositionOnTrack({
    required super.trackIndex,
    required super.relativeStep,
  });
}

/// The pawn has turned into its colored 5-tile home run track.
class PawnPositionInHomeRun extends BoardPositionHomeColumn {
  const PawnPositionInHomeRun({
    required int homeRunStep,
  }) : super(columnStep: homeRunStep);
}

/// The pawn has reached the center triangle and finished the game.
class PawnPositionFinished extends BoardPositionGoal {
  const PawnPositionFinished();
}
