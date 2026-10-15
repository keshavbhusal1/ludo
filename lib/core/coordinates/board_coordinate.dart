/// Represents a 2D discrete coordinate on the 15x15 Ludo board grid.
///
/// Coordinate space:
/// - [x]: column index from 0 (left) to 14 (right).
/// - [y]: row index from 0 (top) to 14 (bottom).
class BoardCoordinate {
  final int x;
  final int y;

  const BoardCoordinate(this.x, this.y)
      : assert(x >= 0 && x <= 14, 'x must be between 0 and 14'),
        assert(y >= 0 && y <= 14, 'y must be between 0 and 14');

  /// Translates coordinate to normalized 0.0 - 1.0 UV space for responsive canvas rendering.
  double get u => (x + 0.5) / 15.0;
  double get v => (y + 0.5) / 15.0;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory BoardCoordinate.fromJson(Map<String, dynamic> json) =>
      BoardCoordinate(json['x'] as int, json['y'] as int);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardCoordinate && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}
