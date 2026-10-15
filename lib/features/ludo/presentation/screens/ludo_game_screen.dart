import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/haptics_service.dart';
import '../../../../models/game_rules.dart';
import '../../../../models/game_state.dart';
import '../../../../models/move.dart';
import '../../../../models/player.dart';
import '../../../../models/player_color.dart';
import '../../../../presentation/themes/board_theme.dart';
import '../../../../presentation/widgets/board/ludo_board_widget.dart';
import '../../../../presentation/widgets/dialogs/game_setup_dialog.dart';
import '../../../../presentation/widgets/dialogs/reclaim_seat_dialog.dart';
import '../../../../presentation/widgets/dice/animated_dice_widget.dart';
import '../../../../presentation/widgets/dice/full_screen_dice_roll_overlay.dart';
import '../../../../presentation/widgets/effects/confetti_overlay.dart';
import '../../../../presentation/widgets/hud/move_history_sheet.dart';
import '../../../../presentation/widgets/hud/player_badge_widget.dart';
import '../../../../presentation/widgets/hud/turn_countdown.dart';
import '../bloc/ludo_bloc.dart';
import '../bloc/ludo_event.dart';
import '../bloc/ludo_state.dart';

/// Clean, human-centric Tabletop Ludo Screen powered by BLoC.
class LudoGameScreen extends StatefulWidget {
  const LudoGameScreen({super.key});

  @override
  State<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends State<LudoGameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pawnHopController;
  Move? _currentlyAnimatingMove;

  @override
  void initState() {
    super.initState();
    _pawnHopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pawnHopController.dispose();
    super.dispose();
  }

  /// Pauses the turn timer while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final bool? isForeground = switch (lifecycle) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached => false,
      AppLifecycleState.inactive => null, // transient (e.g. notification shade)
    };
    if (isForeground != null) {
      context.read<LudoBloc>().add(LudoAppLifecycleChanged(isForeground: isForeground));
    }
  }

  void _showSnackbar(
    String text, {
    IconData icon = Icons.info_outline,
    Color? iconColor,
  }) {
    if (!mounted) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: iconColor ?? const Color(0xFF60A5FA),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                trimmed,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  letterSpacing: 0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  Future<void> _startPawnAnimation(Move move, double gameSpeed) async {
    _currentlyAnimatingMove = move;
    final int hopCount = max(1, move.trajectory.length - 1);
    final rawDuration = min(850, max(320, hopCount * 125));
    _pawnHopController.duration =
        Duration(milliseconds: (rawDuration / gameSpeed).round());

    HapticsService.pawnHop();
    await _pawnHopController.forward(from: 0.0);

    if (mounted && _currentlyAnimatingMove == move) {
      _currentlyAnimatingMove = null;
      HapticsService.moveLanded(move);
      context.read<LudoBloc>().add(LudoMoveAnimationCompleted(move));
    }
  }

  void _toggleHaptics() {
    // Flips the flag at once; saving it finishes in the background.
    // (setState's callback must not return that Future.)
    HapticsService.setEnabled(!HapticsService.isEnabled);
    setState(() {});
    _showSnackbar(
      HapticsService.isEnabled ? 'Haptics On' : 'Haptics Off',
      icon: Icons.vibration,
      iconColor: const Color(0xFF60A5FA),
    );
  }

  static Widget _menuRow(IconData icon, String label) => Row(
        children: [
          Icon(icon, size: 18, color: Colors.white70),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      );

  /// Short mode name for the app bar title.
  static String _modeName(WinCondition mode) => switch (mode) {
        WinCondition.classic => 'Classic',
        WinCondition.quick1 => 'Quick',
        WinCondition.quick2 => 'Rush',
      };

  /// Confirms, then hands a taken-over seat back to its human.
  Future<void> _reclaimSeat(PlayerColor color) async {
    final bloc = context.read<LudoBloc>();
    final current = bloc.state;
    final player = current is LudoActiveState ? current.gameState.getPlayer(color) : null;
    if (player == null) return;

    if (await confirmReclaimSeat(context, player) && mounted) {
      bloc.add(LudoSeatReclaimed(color));
    }
  }

  Future<void> _openMatchSetup(LudoActiveState activeState) async {
    final state = activeState.gameState;
    final initialAiMap = {for (final p in state.players) p.color: p.isAi};

    final result = await showDialog<GameSetupResult>(
      context: context,
      builder: (context) => GameSetupDialog(
        initialConfig: GameSetupResult(
          colors: state.players.map((p) => p.color).toList(),
          aiConfig: initialAiMap,
          rules: state.rules,
          themeType: activeState.themeType,
        ),
      ),
    );

    if (result != null && mounted) {
      context.read<LudoBloc>().add(LudoStarted(
            colors: result.colors,
            aiConfig: result.aiConfig,
            rules: result.rules,
            themeType: result.themeType,
          ));
    }
  }

  String _buildStatusMessage(LudoActiveState state) {
    final game = state.gameState;
    if (game.isGameOver) {
      final winner = game.winner;
      return winner != null ? '🎉 ${winner.displayName} Wins the Game!' : 'Match Ended!';
    }
    // Whose turn only; what to do goes on the line below (one prompt, not two)
    if (state.isShowingRollOverlay) {
      final roller = state.rollerPlayer ?? game.activePlayer;
      return '${roller.name} is rolling the dice…';
    }
    return "${game.activePlayer.name}'s turn";
  }

  @override
  Widget build(BuildContext context) {
    // Each side effect is acted on once: later states carry the same effect
    // until it's replaced, and must not re-show it.
    return BlocListener<LudoBloc, LudoState>(
      listenWhen: isNewSideEffect,
      listener: (context, state) {
        final sideEffect = (state as LudoActiveState).sideEffect;
        if (sideEffect is LudoSnackbarEffect) {
          _showSnackbar(
            sideEffect.message,
            icon: sideEffect.icon,
            iconColor: sideEffect.iconColor,
          );
        } else if (sideEffect is LudoVictoryEffect) {
          HapticsService.victory();
        }
      },
      child: BlocConsumer<LudoBloc, LudoState>(
      listener: (context, state) {
        // Handle pawn movement animation
        if (state is LudoActiveState &&
            state.animatingMove != null &&
            state.animatingMove != _currentlyAnimatingMove) {
          _startPawnAnimation(state.animatingMove!, state.gameState.rules.gameSpeed);
        }
      },
      builder: (context, state) {
        if (state is! LudoActiveState) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentTheme = BoardTheme.fromType(state.themeType);
        final gameState = state.gameState;
        final activePlayer = gameState.activePlayer;
        final primaryColor = Color(activePlayer.color.primaryColorValue);
        final isHumanTurn = !activePlayer.isBotControlled;
        final isAwaitingRoll = gameState.fsmState == LudoFsmState.waitingForRoll;
        final requiredTokens = gameState.rules.winCondition.tokensRequired;

        Player? getPlayer(PlayerColor color) => gameState.getPlayer(color);

        return Scaffold(
          backgroundColor: currentTheme.scaffoldBg,
          appBar: AppBar(
            backgroundColor: currentTheme.hudBg,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.casino, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Ludo · ${_modeName(gameState.rules.winCondition)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              // Undo to last token choice
              IconButton(
                icon: Icon(
                  Icons.undo,
                  color: state.canUndo ? Colors.white : Colors.white24,
                  size: 20,
                ),
                tooltip: undoTooltip(state),
                onPressed: state.canUndo
                    ? () => context.read<LudoBloc>().add(const LudoUndoRequested())
                    : null,
              ),
              // Move history
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white, size: 20),
                tooltip: 'Move history',
                onPressed: () => MoveHistorySheet.show(context),
              ),
              // Settings Modal
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white, size: 20),
                tooltip: 'Settings',
                onPressed: () => _openMatchSetup(state),
              ),
              // Less frequent actions, so the title has room
              PopupMenuButton<_MenuAction>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                color: const Color(0xFF1E293B),
                onSelected: (action) {
                  switch (action) {
                    case _MenuAction.toggleHaptics:
                      _toggleHaptics();
                    case _MenuAction.restart:
                      context.read<LudoBloc>().add(const LudoMatchRestarted());
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _MenuAction.toggleHaptics,
                    child: _menuRow(
                      HapticsService.isEnabled ? Icons.phone_android : Icons.vibration,
                      HapticsService.isEnabled ? 'Turn haptics off' : 'Turn haptics on',
                    ),
                  ),
                  PopupMenuItem(
                    value: _MenuAction.restart,
                    child: _menuRow(Icons.refresh, 'Restart match'),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ConfettiOverlay(
            isPlaying: gameState.isGameOver,
            child: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      // Resume Banner
                      if (state.hasSavedGameBanner)
                        Container(
                          color: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.save_as, color: Colors.white, size: 16),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Previous match found',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  context.read<LudoBloc>().add(const LudoSavedMatchResumed());
                                },
                                child: const Text(
                                  'RESUME',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                                onPressed: () {
                                  context.read<LudoBloc>().add(const LudoSavedMatchBannerDismissed());
                                },
                              ),
                            ],
                          ),
                        ),

                      // PLAY AREA: badges sit on the board's corners; the group is
                      // centered in the space between the app bar and the HUD.
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const badgeRowHeight = 44.0;
                            const gap = 8.0;
                            final boardSize = max(
                              0.0,
                              min(
                                constraints.maxWidth * 0.94,
                                constraints.maxHeight - 2 * (badgeRowHeight + gap),
                              ),
                            );

                            Widget badgeRow(PlayerColor left, PlayerColor right) => SizedBox(
                                  width: boardSize,
                                  height: badgeRowHeight,
                                  child: Center(
                                    child: PlayerBadgeRow(
                                      left: getPlayer(left),
                                      right: getPlayer(right),
                                      activeColor: activePlayer.color,
                                      tokensRequired: requiredTokens,
                                      onReclaim: _reclaimSeat,
                                    ),
                                  ),
                                );

                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  badgeRow(PlayerColor.red, PlayerColor.green),
                                  const SizedBox(height: gap),
                                  SizedBox(
                                    width: boardSize,
                                    height: boardSize,
                                    child: AnimatedBuilder(
                                      animation: _pawnHopController,
                                      builder: (context, _) => LudoBoardWidget(
                                        gameState: gameState,
                                        onMoveSelected: (move) {
                                          context.read<LudoBloc>().add(LudoMoveSelected(move));
                                        },
                                        animatingMove: state.animatingMove,
                                        animationProgress: _pawnHopController.value,
                                        theme: currentTheme,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: gap),
                                  badgeRow(PlayerColor.blue, PlayerColor.yellow),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // BOTTOM HUD: Single Shared Dice & Action Prompt
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                        decoration: BoxDecoration(
                          color: currentTheme.hudBg,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            topRight: Radius.circular(24),
                          ),
                        ),
                        child: Row(
                          children: [
                            // The ONE Single Shared Dice
                            AnimatedDiceWidget(
                              value: gameState.lastDiceRoll,
                              playerColor: state.isShowingRollOverlay
                                  ? (state.rollerPlayer?.color ?? activePlayer.color)
                                  : activePlayer.color,
                              isEnabled: isHumanTurn && isAwaitingRoll && !state.isShowingRollOverlay,
                              isRolling: state.isShowingRollOverlay,
                              onRollPressed: () {
                                context.read<LudoBloc>().add(const LudoDiceRollRequested());
                              },
                              onDisabledTap: () {
                                if (state.isShowingRollOverlay) return;
                                if (isHumanTurn &&
                                    gameState.fsmState == LudoFsmState.waitingForSelection) {
                                  _showSnackbar(
                                    'Please tap a highlighted token on the board to move',
                                    icon: Icons.touch_app,
                                    iconColor: const Color(0xFFFBBF24),
                                  );
                                } else if (activePlayer.isBotControlled) {
                                  _showSnackbar(
                                    "${activePlayer.name} is taking their turn...",
                                    icon: Icons.smart_toy,
                                    iconColor: const Color(0xFF94A3B8),
                                  );
                                }
                              },
                              size: 58,
                            ),

                            const SizedBox(width: 16),

                            // Action Prompt
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _buildStatusMessage(state),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      // The last turn's result if there is one, else a prompt
                                      if (state.turnNote case final note?) ...[
                                        Icon(note.icon, size: 14, color: note.color),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            note.text,
                                            key: const Key('turn-note'),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: note.color,
                                            ),
                                          ),
                                        ),
                                      ] else
                                        Flexible(
                                          child: Text(
                                            activePlayer.isBotControlled
                                                ? 'Bot thinking…'
                                                : (isAwaitingRoll
                                                    ? 'Tap the dice to roll'
                                                    : 'Tap a highlighted token to move'),
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      if (state.turnDeadline != null) ...[
                                        const SizedBox(width: 8),
                                        TurnCountdown(
                                          deadline: state.turnDeadline!,
                                          limit: gameState.config.timerConfig.turnTimeout,
                                          color: primaryColor,
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Big Roll Button for Human Player
                            if (isHumanTurn && isAwaitingRoll)
                              ElevatedButton.icon(
                                onPressed: state.isShowingRollOverlay
                                    ? null
                                    : () {
                                        context.read<LudoBloc>().add(const LudoDiceRollRequested());
                                      },
                                icon: const Icon(Icons.casino, size: 20),
                                label: const Text(
                                  'ROLL',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                ),
                              )
                            else if (isHumanTurn &&
                                gameState.fsmState == LudoFsmState.waitingForSelection)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: primaryColor, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.touch_app, size: 18, color: primaryColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      'PICK TOKEN',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // FULL-SCREEN DRAMATIC 3D DICE ROLLING OVERLAY
                if (state.isShowingRollOverlay)
                  FullScreenDiceRollOverlay(
                    activePlayer: state.rollerPlayer ?? activePlayer,
                    finalRoll: state.overlayRollValue ?? 1,
                    onComplete: () {
                      context.read<LudoBloc>().add(const LudoDiceRollOverlayCompleted());
                    },
                    gameSpeed: gameState.rules.gameSpeed,
                  ),
              ],
            ),
          ),
        );
      },
    ),
    );
  }
}

enum _MenuAction { toggleHaptics, restart }
