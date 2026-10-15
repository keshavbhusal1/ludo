import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/coordinates/board_coordinate.dart';
import '../../../core/coordinates/board_path_registry.dart';
import '../../../models/player_color.dart';
import '../../themes/board_theme.dart';

/// Authentic classic 15x15 Ludo board CustomPainter.
///
/// Features:
/// - Crisp, high-contrast white path square tiles with distinct borders.
/// - Vibrant colored home run paths with bold directional chevron arrows (> > > > >).
/// - Distinct colored start squares with large directional arrows.
/// - Clear, high-visibility golden safe stars.
/// - Classic 4-quadrant yard bases with clean token ring slots.
/// - Converging 4-color center home triangles with gold victory star.
class LudoBoardPainter extends CustomPainter {
  final double borderRadius;
  final BoardTheme theme;

  const LudoBoardPainter({
    this.borderRadius = 16.0,
    this.theme = BoardTheme.darkModern,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellSize = size.width / 15.0;

    // 1. Board Background Base
    final boardRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(boardRect, Paint()..color = theme.boardBg);

    // 2. Draw 4 Corner Yards
    _drawYard(canvas, cellSize, PlayerColor.red, 0, 0);
    _drawYard(canvas, cellSize, PlayerColor.green, 9, 0);
    _drawYard(canvas, cellSize, PlayerColor.yellow, 9, 9);
    _drawYard(canvas, cellSize, PlayerColor.blue, 0, 9);

    // 3. Draw Track Cells & Home Runs
    _drawTrackCells(canvas, cellSize);

    // 4. Draw Center Triangle Home
    _drawCenterHome(canvas, cellSize);

    // 5. Draw Safe Zone Stars & Start Square Arrows
    _drawLandmarks(canvas, cellSize);

    // 6. Draw Board Outer Border
    final borderPaint = Paint()
      ..color = theme.outerBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(boardRect, borderPaint);
  }

  void _drawYard(
    Canvas canvas,
    double cellSize,
    PlayerColor color,
    int startCol,
    int startRow,
  ) {
    final yardRect = Rect.fromLTWH(
      startCol * cellSize,
      startRow * cellSize,
      6 * cellSize,
      6 * cellSize,
    );

    // Outer colored quadrant
    final quadrantPaint = Paint()..color = Color(color.primaryColorValue);
    canvas.drawRect(yardRect, quadrantPaint);

    // Inner rounded container
    final innerMargin = cellSize * 0.75;
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        startCol * cellSize + innerMargin,
        startRow * cellSize + innerMargin,
        6 * cellSize - (innerMargin * 2),
        6 * cellSize - (innerMargin * 2),
      ),
      Radius.circular(cellSize * 0.45),
    );
    final containerPaint = Paint()..color = theme.yardContainerBg;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    canvas.drawRRect(innerRect.shift(const Offset(0, 2)), shadowPaint);
    canvas.drawRRect(innerRect, containerPaint);

    // Yard container border
    final yardBorderPaint = Paint()
      ..color = Color(color.darkColorValue).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(innerRect, yardBorderPaint);

    // 4 circular pawn slots
    final slots = BoardPathRegistry.yardSlots[color]!;
    for (final slot in slots) {
      final center = Offset(
        (slot.x + 0.5) * cellSize,
        (slot.y + 0.5) * cellSize,
      );
      final radius = cellSize * 0.42;

      // Slot border ring
      final ringPaint = Paint()
        ..color = Color(color.primaryColorValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(center, radius, ringPaint);

      // Slot inner fill
      final slotFillPaint = Paint()
        ..color = Color(color.primaryColorValue).withValues(alpha: 0.14)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, slotFillPaint);
    }
  }

  void _drawTrackCells(Canvas canvas, double cellSize) {
    final cellBorderPaint = Paint()
      ..color = theme.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final whiteTilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    void drawCell(int c, int r, Color? fillColor) {
      final rect = Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize);
      // Base tile
      canvas.drawRect(rect, fillColor != null ? (Paint()..color = fillColor) : whiteTilePaint);
      // Border outline
      canvas.drawRect(rect, cellBorderPaint);
    }

    // Top Arm (cols 6..8, rows 0..5)
    for (int r = 0; r < 6; r++) {
      for (int c = 6; c <= 8; c++) {
        Color? fill;
        if (c == 7 && r > 0) fill = Color(PlayerColor.green.primaryColorValue);
        if (c == 8 && r == 1) fill = Color(PlayerColor.green.primaryColorValue);
        drawCell(c, r, fill);
      }
    }

    // Bottom Arm (cols 6..8, rows 9..14)
    for (int r = 9; r < 15; r++) {
      for (int c = 6; c <= 8; c++) {
        Color? fill;
        if (c == 7 && r < 14) fill = Color(PlayerColor.blue.primaryColorValue);
        if (c == 6 && r == 13) fill = Color(PlayerColor.blue.primaryColorValue);
        drawCell(c, r, fill);
      }
    }

    // Left Arm (cols 0..5, rows 6..8)
    for (int r = 6; r <= 8; r++) {
      for (int c = 0; c < 6; c++) {
        Color? fill;
        if (r == 7 && c > 0) fill = Color(PlayerColor.red.primaryColorValue);
        if (r == 6 && c == 1) fill = Color(PlayerColor.red.primaryColorValue);
        drawCell(c, r, fill);
      }
    }

    // Right Arm (cols 9..14, rows 6..8)
    for (int r = 6; r <= 8; r++) {
      for (int c = 9; c < 15; c++) {
        Color? fill;
        if (r == 7 && c < 14) fill = Color(PlayerColor.yellow.primaryColorValue);
        if (r == 8 && c == 13) fill = Color(PlayerColor.yellow.primaryColorValue);
        drawCell(c, r, fill);
      }
    }

    // Draw Directional Chevrons on Home Run Corridors
    _drawHomeRunChevrons(canvas, cellSize);
  }

  void _drawHomeRunChevrons(Canvas canvas, double cellSize) {
    final chevronPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Red Home Run: cols 1..5, row 7 (pointing RIGHT >)
    for (int c = 1; c <= 5; c++) {
      final cx = (c + 0.5) * cellSize;
      final cy = 7.5 * cellSize;
      final path = Path()
        ..moveTo(cx - cellSize * 0.14, cy - cellSize * 0.18)
        ..lineTo(cx + cellSize * 0.12, cy)
        ..lineTo(cx - cellSize * 0.14, cy + cellSize * 0.18);
      canvas.drawPath(path, chevronPaint);
    }

    // Green Home Run: col 7, rows 1..5 (pointing DOWN v)
    for (int r = 1; r <= 5; r++) {
      final cx = 7.5 * cellSize;
      final cy = (r + 0.5) * cellSize;
      final path = Path()
        ..moveTo(cx - cellSize * 0.18, cy - cellSize * 0.14)
        ..lineTo(cx, cy + cellSize * 0.12)
        ..lineTo(cx + cellSize * 0.18, cy - cellSize * 0.14);
      canvas.drawPath(path, chevronPaint);
    }

    // Yellow Home Run: cols 9..13, row 7 (pointing LEFT <)
    for (int c = 9; c <= 13; c++) {
      final cx = (c + 0.5) * cellSize;
      final cy = 7.5 * cellSize;
      final path = Path()
        ..moveTo(cx + cellSize * 0.14, cy - cellSize * 0.18)
        ..lineTo(cx - cellSize * 0.12, cy)
        ..lineTo(cx + cellSize * 0.14, cy + cellSize * 0.18);
      canvas.drawPath(path, chevronPaint);
    }

    // Blue Home Run: col 7, rows 9..13 (pointing UP ^)
    for (int r = 9; r <= 13; r++) {
      final cx = 7.5 * cellSize;
      final cy = (r + 0.5) * cellSize;
      final path = Path()
        ..moveTo(cx - cellSize * 0.18, cy + cellSize * 0.14)
        ..lineTo(cx, cy - cellSize * 0.12)
        ..lineTo(cx + cellSize * 0.18, cy + cellSize * 0.14);
      canvas.drawPath(path, chevronPaint);
    }
  }

  void _drawCenterHome(Canvas canvas, double cellSize) {
    final centerOrigin = Offset(6 * cellSize, 6 * cellSize);
    final centerSize = 3 * cellSize;
    final apex = Offset(7.5 * cellSize, 7.5 * cellSize);

    // Red Triangle (Left)
    final redPath = Path()
      ..moveTo(centerOrigin.dx, centerOrigin.dy)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(centerOrigin.dx, centerOrigin.dy + centerSize)
      ..close();
    canvas.drawPath(
      redPath,
      Paint()..color = Color(PlayerColor.red.primaryColorValue),
    );

    // Green Triangle (Top)
    final greenPath = Path()
      ..moveTo(centerOrigin.dx, centerOrigin.dy)
      ..lineTo(centerOrigin.dx + centerSize, centerOrigin.dy)
      ..lineTo(apex.dx, apex.dy)
      ..close();
    canvas.drawPath(
      greenPath,
      Paint()..color = Color(PlayerColor.green.primaryColorValue),
    );

    // Yellow Triangle (Right)
    final yellowPath = Path()
      ..moveTo(centerOrigin.dx + centerSize, centerOrigin.dy)
      ..lineTo(centerOrigin.dx + centerSize, centerOrigin.dy + centerSize)
      ..lineTo(apex.dx, apex.dy)
      ..close();
    canvas.drawPath(
      yellowPath,
      Paint()..color = Color(PlayerColor.yellow.primaryColorValue),
    );

    // Blue Triangle (Bottom)
    final bluePath = Path()
      ..moveTo(centerOrigin.dx, centerOrigin.dy + centerSize)
      ..lineTo(apex.dx, apex.dy)
      ..lineTo(centerOrigin.dx + centerSize, centerOrigin.dy + centerSize)
      ..close();
    canvas.drawPath(
      bluePath,
      Paint()..color = Color(PlayerColor.blue.primaryColorValue),
    );

    // Center divider lines
    final dividerPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(redPath, dividerPaint);
    canvas.drawPath(greenPath, dividerPaint);
    canvas.drawPath(yellowPath, dividerPaint);
    canvas.drawPath(bluePath, dividerPaint);

    // Center Victory Star Badge
    _drawStar(canvas, apex, cellSize * 0.45, const Color(0xFFFBBF24), Colors.white);
  }

  void _drawLandmarks(Canvas canvas, double cellSize) {
    const starCoords = [
      BoardCoordinate(6, 2),
      BoardCoordinate(12, 6),
      BoardCoordinate(8, 12),
      BoardCoordinate(2, 8),
    ];

    for (final coord in starCoords) {
      final center = Offset((coord.x + 0.5) * cellSize, (coord.y + 0.5) * cellSize);
      canvas.drawCircle(
        center,
        cellSize * 0.38,
        Paint()..color = const Color(0xFFFEF3C7),
      );
      _drawStar(canvas, center, cellSize * 0.32, const Color(0xFFF59E0B), Colors.white);
    }

    _drawStartArrow(canvas, cellSize, const BoardCoordinate(1, 6), 0);
    _drawStartArrow(canvas, cellSize, const BoardCoordinate(8, 1), pi / 2);
    _drawStartArrow(canvas, cellSize, const BoardCoordinate(13, 8), pi);
    _drawStartArrow(canvas, cellSize, const BoardCoordinate(6, 13), -pi / 2);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color fillColor, Color strokeColor) {
    final path = Path();
    const int points = 5;
    const double angle = (2 * pi) / points;
    final double innerRadius = radius * 0.42;

    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : innerRadius;
      final a = (i * angle / 2) - (pi / 2);
      final x = center.dx + r * cos(a);
      final y = center.dy + r * sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _drawStartArrow(Canvas canvas, double cellSize, BoardCoordinate coord, double rotationAngle) {
    final center = Offset((coord.x + 0.5) * cellSize, (coord.y + 0.5) * cellSize);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    final arrowPath = Path()
      ..moveTo(-cellSize * 0.24, -cellSize * 0.22)
      ..lineTo(cellSize * 0.24, 0)
      ..lineTo(-cellSize * 0.24, cellSize * 0.22)
      ..close();

    canvas.drawPath(arrowPath, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LudoBoardPainter oldDelegate) =>
      oldDelegate.theme != theme;
}
