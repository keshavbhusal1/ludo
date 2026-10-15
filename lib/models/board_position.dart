/// Sealed class representing the position of a token on the Ludo board.
sealed class BoardPosition {
  const BoardPosition();

  /// Relative step progress from start (-1 for base, 0..50 for common track, 51..55 for home column, 56 for goal).
  int get relativeStep;

  /// Whether the token is in its starting yard/base.
  bool get isInBase => this is BoardPositionBase;

  /// Whether the token is traversing the 52-tile common perimeter track.
  bool get isOnTrack => this is BoardPositionTrack;

  /// Whether the token has turned into its colored home column (corridor).
  bool get isInHomeColumn => this is BoardPositionHomeColumn;

  /// Whether the token has reached the final Home/Goal center.
  bool get isGoal => this is BoardPositionGoal;

  // Compatibility aliases
  bool get isInYard => isInBase;
  bool get isInHomeRun => isInHomeColumn;
  bool get isFinished => isGoal;

  Map<String, dynamic> toJson();

  /// Factory constructors for clear domain instantiation
  const factory BoardPosition.base(int slotIndex) = BoardPositionBase;
  const factory BoardPosition.track({
    required int trackIndex,
    required int relativeStep,
  }) = BoardPositionTrack;
  const factory BoardPosition.homeColumn({
    required int columnStep,
  }) = BoardPositionHomeColumn;
  const factory BoardPosition.goal() = BoardPositionGoal;

  factory BoardPosition.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'base':
      case 'inYard':
        return BoardPositionBase(json['slotIndex'] as int);
      case 'track':
      case 'onTrack':
        return BoardPositionTrack(
          trackIndex: json['trackIndex'] as int,
          relativeStep: json['relativeStep'] as int,
        );
      case 'homeColumn':
      case 'inHomeRun':
        return BoardPositionHomeColumn(
          columnStep: (json['columnStep'] ?? json['homeRunStep']) as int,
        );
      case 'goal':
      case 'finished':
        return const BoardPositionGoal();
      default:
        throw ArgumentError('Unknown BoardPosition type: $type');
    }
  }
}

/// The token is resting in its home base / yard.
class BoardPositionBase extends BoardPosition {
  /// Slot index within the base quadrant (0 to 3).
  final int slotIndex;

  const BoardPositionBase(this.slotIndex)
      : assert(slotIndex >= 0 && slotIndex <= 3, 'Slot index must be 0..3');

  @override
  int get relativeStep => -1;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'base',
        'slotIndex': slotIndex,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPositionBase &&
          runtimeType == other.runtimeType &&
          slotIndex == other.slotIndex;

  @override
  int get hashCode => Object.hash(runtimeType, slotIndex);

  @override
  String toString() => 'BoardPosition.base($slotIndex)';
}

/// The token is actively moving along the 52-tile common perimeter track.
class BoardPositionTrack extends BoardPosition {
  /// Discrete index on the 52-tile common track (0 to 51).
  final int trackIndex;

  /// Relative steps advanced from player's starting square (0 to 50).
  @override
  final int relativeStep;

  const BoardPositionTrack({
    required this.trackIndex,
    required this.relativeStep,
  })  : assert(trackIndex >= 0 && trackIndex < 52, 'Track index must be 0..51'),
        assert(relativeStep >= 0 && relativeStep <= 50,
            'Relative step on track must be 0..50');

  @override
  Map<String, dynamic> toJson() => {
        'type': 'track',
        'trackIndex': trackIndex,
        'relativeStep': relativeStep,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPositionTrack &&
          runtimeType == other.runtimeType &&
          trackIndex == other.trackIndex &&
          relativeStep == other.relativeStep;

  @override
  int get hashCode => Object.hash(runtimeType, trackIndex, relativeStep);

  @override
  String toString() =>
      'BoardPosition.track(trackIndex: $trackIndex, relativeStep: $relativeStep)';
}

/// The token is in its colored 5-tile home column (indices 0 to 4).
class BoardPositionHomeColumn extends BoardPosition {
  /// Step index along the home column (0 to 4).
  final int columnStep;

  const BoardPositionHomeColumn({
    required this.columnStep,
  }) : assert(
            columnStep >= 0 && columnStep <= 4, 'Column step must be 0..4');

  /// Compatibility alias for homeRunStep
  int get homeRunStep => columnStep;

  @override
  int get relativeStep => 51 + columnStep;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'homeColumn',
        'columnStep': columnStep,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardPositionHomeColumn &&
          runtimeType == other.runtimeType &&
          columnStep == other.columnStep;

  @override
  int get hashCode => Object.hash(runtimeType, columnStep);

  @override
  String toString() =>
      'BoardPosition.homeColumn(columnStep: $columnStep, relativeStep: $relativeStep)';
}

/// The token has reached the final Home/Goal destination tile (index 5 / step 56).
class BoardPositionGoal extends BoardPosition {
  const BoardPositionGoal();

  @override
  int get relativeStep => 56;

  @override
  Map<String, dynamic> toJson() => {'type': 'goal'};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BoardPositionGoal;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'BoardPosition.goal(step: 56)';
}
