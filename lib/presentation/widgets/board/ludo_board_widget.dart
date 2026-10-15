import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/coordinates/board_coordinate.dart';
import '../../../core/coordinates/board_path_registry.dart';
import '../../../models/game_state.dart';
import '../../../models/move.dart';
import '../../../models/token.dart';
import '../../themes/board_theme.dart';
import 'ludo_board_painter.dart';
import 'ludo_pawn_widget.dart';

/// Clean, responsive board widget with trajectory path trails,
/// target landing highlights, and parabolic token hops.
class LudoBoardWidget extends StatelessWidget {
  final GameState gameState;
  final ValueChanged<Move> onMoveSelected;
  final Move? animatingMove;
  final double animationProgress; // 0.0 to 1.0
  final BoardTheme theme;

  const LudoBoardWidget({
    super.key,
    required this.gameState,
    required this.onMoveSelected,
    this.animatingMove,
    this.animationProgress = 0.0,
    this.theme = BoardTheme.darkModern,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double boardSize = constraints.maxWidth;
          final double cellSize = boardSize / 15.0;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // 1. Static Board Canvas with clear path lines & chevrons
                  RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: LudoBoardPainter(
                        borderRadius: 16,
                        theme: theme,
                        seatedColors: {for (final p in gameState.players) p.color},
                      ),
                    ),
                  ),

                  // 2. Trajectory Path Trails & Target Landing Badges
                  if (gameState.fsmState == LudoFsmState.waitingForSelection)
                    ..._buildPathPreviews(cellSize),

                  // 3. Interactive / Animated Token Layer
                  ..._buildPawnLayers(cellSize),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPathPreviews(double cellSize) {
    final widgets = <Widget>[];

    for (final move in gameState.validMoves) {
      final primaryColor = Color(move.playerColor.primaryColorValue);

      // A. Path trail dots
      if (move.trajectory.length > 2) {
        for (int i = 1; i < move.trajectory.length - 1; i++) {
          final coord = move.trajectory[i];
          final dotSize = cellSize * 0.22;
          widgets.add(
            Positioned(
              left: (coord.x + 0.5) * cellSize - (dotSize / 2),
              top: (coord.y + 0.5) * cellSize - (dotSize / 2),
              width: dotSize,
              height: dotSize,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.0),
                  ),
                ),
              ),
            ),
          );
        }
      }

      // B. Landing Target Ring
      if (move.trajectory.isNotEmpty) {
        final dest = move.trajectory.last;
        final ringSize = cellSize * 0.82;
        widgets.add(
          Positioned(
            left: (dest.x + 0.5) * cellSize - (ringSize / 2),
            top: (dest.y + 0.5) * cellSize - (ringSize / 2),
            width: ringSize,
            height: ringSize,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor, width: 2.8),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.55),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: cellSize * 0.24,
                    height: cellSize * 0.24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  List<Widget> _buildPawnLayers(double cellSize) {
    final widgets = <Widget>[];

    final movableMoveMap = <String, Move>{};
    if (gameState.fsmState == LudoFsmState.waitingForSelection) {
      for (final move in gameState.validMoves) {
        movableMoveMap[move.tokenId] = move;
      }
    }

    final allPawns = <Token>[];
    for (final player in gameState.players) {
      for (final pawn in player.tokens) {
        allPawns.add(pawn);
      }
    }

    Token? activePawn;
    final staticPawns = <Token>[];

    for (final pawn in allPawns) {
      if (animatingMove != null && pawn.id == animatingMove!.tokenId) {
        activePawn = pawn;
      } else {
        staticPawns.add(pawn);
      }
    }

    // Group static pawns by their discrete coordinate to compute cluster offsets
    final coordinateClusters = <BoardCoordinate, List<Token>>{};
    for (final pawn in staticPawns) {
      final coord = _getPawnCoordinate(pawn);
      coordinateClusters.putIfAbsent(coord, () => []).add(pawn);
    }

    // Render Static Pawns with Cluster Offsets
    for (final entry in coordinateClusters.entries) {
      final coord = entry.key;
      final pawnsInCell = entry.value;
      final int clusterCount = pawnsInCell.length;

      for (int i = 0; i < clusterCount; i++) {
        final pawn = pawnsInCell[i];
        final isMovable = movableMoveMap.containsKey(pawn.id);
        final move = movableMoveMap[pawn.id];

        Offset offset = Offset(
          (coord.x + 0.5) * cellSize,
          (coord.y + 0.5) * cellSize,
        );
        double pawnRenderSize = cellSize * 0.78;

        if (clusterCount > 1) {
          final double angle = (2 * pi / clusterCount) * i;
          final double radius = cellSize * 0.22;
          offset += Offset(cos(angle) * radius, sin(angle) * radius);
          pawnRenderSize = cellSize * 0.58;
        }

        widgets.add(
          Positioned(
            left: offset.dx - (pawnRenderSize / 2),
            top: offset.dy - (pawnRenderSize / 2),
            width: pawnRenderSize,
            height: pawnRenderSize,
            child: LudoPawnWidget(
              pawn: pawn,
              size: pawnRenderSize,
              isMovable: isMovable,
              onTap: isMovable && move != null
                  ? () => onMoveSelected(move)
                  : null,
            ),
          ),
        );
      }
    }

    // Render Animating Token with Parabolic Hops
    if (activePawn != null && animatingMove != null) {
      final trajectory = animatingMove!.trajectory;
      final pawnRenderSize = cellSize * 0.82;

      Offset animatedOffset;
      if (trajectory.length <= 1) {
        final coord = trajectory.isNotEmpty
            ? trajectory.first
            : _getPawnCoordinate(activePawn);
        animatedOffset = Offset(
          (coord.x + 0.5) * cellSize,
          (coord.y + 0.5) * cellSize,
        );
      } else {
        final totalSegments = trajectory.length - 1;
        final scaledProgress = (animationProgress * totalSegments).clamp(0.0, totalSegments.toDouble());
        final currentSegment = scaledProgress.floor().clamp(0, totalSegments - 1);
        final segmentT = (scaledProgress - currentSegment).clamp(0.0, 1.0);

        final fromCoord = trajectory[currentSegment];
        final toCoord = trajectory[currentSegment + 1];

        final startPx = Offset(
          (fromCoord.x + 0.5) * cellSize,
          (fromCoord.y + 0.5) * cellSize,
        );
        final endPx = Offset(
          (toCoord.x + 0.5) * cellSize,
          (toCoord.y + 0.5) * cellSize,
        );

        final linearOffset = Offset.lerp(startPx, endPx, segmentT)!;
        final hopHeight = cellSize * 0.35;
        final hopOffset = sin(segmentT * pi) * hopHeight;

        animatedOffset = Offset(linearOffset.dx, linearOffset.dy - hopOffset);
      }

      widgets.add(
        Positioned(
          left: animatedOffset.dx - (pawnRenderSize / 2),
          top: animatedOffset.dy - (pawnRenderSize / 2),
          width: pawnRenderSize,
          height: pawnRenderSize,
          child: LudoPawnWidget(
            pawn: activePawn,
            size: pawnRenderSize,
            isMovable: false,
          ),
        ),
      );
    }

    return widgets;
  }

  BoardCoordinate _getPawnCoordinate(Token pawn) {
    if (pawn.isInBase) {
      return BoardPathRegistry.yardSlots[pawn.color]![pawn.index];
    } else {
      return BoardPathRegistry.getCoordinateForStep(pawn.color, pawn.relativeStep);
    }
  }
}
