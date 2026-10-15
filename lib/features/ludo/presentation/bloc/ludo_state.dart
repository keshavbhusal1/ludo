import 'package:flutter/material.dart';
import '../../../../presentation/themes/board_theme.dart';
import '../../../../models/game_state.dart';
import '../../../../models/move.dart';
import '../../../../models/player.dart';

/// Sealed side-effect events consumed by BlocListener (SnackBars, haptics, victory).
sealed class LudoSideEffect {
  const LudoSideEffect();
}

final class LudoSnackbarEffect extends LudoSideEffect {
  final String message;
  final IconData icon;
  final Color? iconColor;

  const LudoSnackbarEffect(
    this.message, {
    this.icon = Icons.info_outline,
    this.iconColor,
  });
}

final class LudoVictoryEffect extends LudoSideEffect {
  const LudoVictoryEffect();
}

/// Sealed state hierarchy consumed by BlocBuilder.
sealed class LudoState {
  final BoardThemeType themeType;
  const LudoState({this.themeType = BoardThemeType.darkModern});
}

/// Initial loading / uninitialized state.
final class LudoInitial extends LudoState {
  const LudoInitial({super.themeType});
}

/// Active match in progress.
final class LudoActiveState extends LudoState {
  final GameState gameState;
  final Move? animatingMove;
  final bool isShowingRollOverlay;
  final Player? rollerPlayer;
  final int? overlayRollValue;
  final bool hasSavedGameBanner;
  final LudoSideEffect? sideEffect;

  const LudoActiveState({
    required this.gameState,
    this.animatingMove,
    this.isShowingRollOverlay = false,
    this.rollerPlayer,
    this.overlayRollValue,
    this.hasSavedGameBanner = false,
    this.sideEffect,
    super.themeType,
  });

  LudoActiveState copyWith({
    GameState? gameState,
    Move? animatingMove,
    bool? isShowingRollOverlay,
    Player? rollerPlayer,
    int? overlayRollValue,
    bool? hasSavedGameBanner,
    LudoSideEffect? sideEffect,
    bool clearSideEffect = false,
    bool clearAnimatingMove = false,
    bool clearRollerPlayer = false,
    BoardThemeType? themeType,
  }) {
    return LudoActiveState(
      gameState: gameState ?? this.gameState,
      animatingMove: clearAnimatingMove ? null : (animatingMove ?? this.animatingMove),
      isShowingRollOverlay: isShowingRollOverlay ?? this.isShowingRollOverlay,
      rollerPlayer: clearRollerPlayer ? null : (rollerPlayer ?? this.rollerPlayer),
      overlayRollValue: overlayRollValue ?? this.overlayRollValue,
      hasSavedGameBanner: hasSavedGameBanner ?? this.hasSavedGameBanner,
      sideEffect: clearSideEffect ? null : (sideEffect ?? this.sideEffect),
      themeType: themeType ?? this.themeType,
    );
  }
}
