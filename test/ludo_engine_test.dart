import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/engine/ai/ludo_ai_engine.dart';
import 'package:ludo/engine/ludo_engine.dart';

import 'helpers/ludo_game_controller.dart';

void main() {
  group('1. Board Topology & Coordinates (15x15 Grid & 52-Tile Track)', () {
    test('Common track has exactly 52 sequential coordinates within 15x15 bounds', () {
      expect(BoardPathRegistry.commonTrack.length, equals(52));
      for (int i = 0; i < 52; i++) {
        final coord = BoardPathRegistry.commonTrack[i];
        expect(coord.x, inInclusiveRange(0, 14));
        expect(coord.y, inInclusiveRange(0, 14));
      }
    });

    test('4 Player starting tiles match exact specified indices: P1=1, P2=14, P3=27, P4=40', () {
      expect(PlayerColor.red.startTrackIndex, equals(1));
      expect(PlayerColor.green.startTrackIndex, equals(14));
      expect(PlayerColor.yellow.startTrackIndex, equals(27));
      expect(PlayerColor.blue.startTrackIndex, equals(40));

      expect(BoardPathRegistry.commonTrack[1], equals(const BoardCoordinate(1, 6)));
      expect(BoardPathRegistry.commonTrack[14], equals(const BoardCoordinate(8, 1)));
      expect(BoardPathRegistry.commonTrack[27], equals(const BoardCoordinate(13, 8)));
      expect(BoardPathRegistry.commonTrack[40], equals(const BoardCoordinate(6, 13)));
    });

    test('4 Player home entrance indices match: Red=51, Green=12, Yellow=25, Blue=38', () {
      expect(PlayerColor.red.homeEntranceTrackIndex, equals(51));
      expect(PlayerColor.green.homeEntranceTrackIndex, equals(12));
      expect(PlayerColor.yellow.homeEntranceTrackIndex, equals(25));
      expect(PlayerColor.blue.homeEntranceTrackIndex, equals(38));

      expect(BoardPathRegistry.commonTrack[51], equals(const BoardCoordinate(0, 7)));
      expect(BoardPathRegistry.commonTrack[12], equals(const BoardCoordinate(7, 0)));
      expect(BoardPathRegistry.commonTrack[25], equals(const BoardCoordinate(14, 7)));
      expect(BoardPathRegistry.commonTrack[38], equals(const BoardCoordinate(7, 14)));
    });

    test('8 Global safe squares match exactly: [1, 9, 14, 22, 27, 35, 40, 48]', () {
      const expectedSafeSquares = [1, 9, 14, 22, 27, 35, 40, 48];
      expect(BoardPathRegistry.safeTrackSquares, equals(expectedSafeSquares));
      expect(BoardPathRegistry.safeTrackIndices.length, equals(8));

      for (final index in expectedSafeSquares) {
        expect(BoardPathRegistry.isSafeTrackIndex(index), isTrue,
            reason: 'Track index $index should be marked safe');
      }

      // Non-safe squares check
      expect(BoardPathRegistry.isSafeTrackIndex(0), isFalse);
      expect(BoardPathRegistry.isSafeTrackIndex(2), isFalse);
      expect(BoardPathRegistry.isSafeTrackIndex(15), isFalse);
      expect(BoardPathRegistry.isSafeTrackIndex(51), isFalse);
    });

    test('Each player has a home column of 5 tiles (0-4) plus 1 final Goal tile (index 5)', () {
      for (final color in PlayerColor.values) {
        final homeColumn = BoardPathRegistry.homeRuns[color]!;
        expect(homeColumn.length, equals(5)); // indices 0 to 4
        for (final coord in homeColumn) {
          expect(coord.x, inInclusiveRange(0, 14));
          expect(coord.y, inInclusiveRange(0, 14));
        }

        final goalCenter = BoardPathRegistry.homeCenters[color]!;
        expect(goalCenter.x, inInclusiveRange(0, 14));
        expect(goalCenter.y, inInclusiveRange(0, 14));
      }
    });

    test('Relative step maps accurately from start (0) to entrance (50) to corridor (51-55) to goal (56)', () {
      // Step 0: Start tile on track (index 1)
      expect(BoardPathRegistry.getCoordinateForStep(PlayerColor.red, 0),
          equals(const BoardCoordinate(1, 6)));

      // Step 50: Home entrance on track (index 51)
      expect(BoardPathRegistry.getCoordinateForStep(PlayerColor.red, 50),
          equals(const BoardCoordinate(0, 7)));

      // Step 51: Home column corridor tile 0
      expect(BoardPathRegistry.getCoordinateForStep(PlayerColor.red, 51),
          equals(const BoardCoordinate(1, 7)));

      // Step 55: Home column corridor tile 4
      expect(BoardPathRegistry.getCoordinateForStep(PlayerColor.red, 55),
          equals(const BoardCoordinate(5, 7)));

      // Step 56: Final Goal / Home Center (index 5)
      expect(BoardPathRegistry.getCoordinateForStep(PlayerColor.red, 56),
          equals(const BoardCoordinate(6, 7)));
    });
  });

  group('2. Deterministic FSM, Dice Rules & Movement Logic', () {
    test('Three consecutive sixes forfeits roll and transitions to next player immediately', () {
      final controller = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        config: GameConfig.classic(mandatoryKillRequired: false),
        autoExecuteSingleMove: false,
      );

      // Roll 1: First six -> valid moves available, consecutiveSixes = 1, stays Red
      var state = controller.rollDice(6);
      expect(state.consecutiveSixesCount, equals(1));
      expect(state.activePlayerColor, equals(PlayerColor.red));
      expect(state.fsmState, equals(LudoFsmState.waitingForSelection));
      state = controller.executeMove(state.validMoves.first);
      expect(state.activePlayerColor, equals(PlayerColor.red));
      expect(state.fsmState, equals(LudoFsmState.waitingForRoll));

      // Roll 2: Second six -> moves available, consecutiveSixes = 2, stays Red
      state = controller.rollDice(6);
      expect(state.consecutiveSixesCount, equals(2));
      expect(state.activePlayerColor, equals(PlayerColor.red));
      expect(state.fsmState, equals(LudoFsmState.waitingForSelection));
      state = controller.executeMove(state.validMoves.first);
      expect(state.activePlayerColor, equals(PlayerColor.red));
      expect(state.fsmState, equals(LudoFsmState.waitingForRoll));

      // Roll 3: Third six -> Turn forfeited immediately! Transitions to next player
      state = controller.rollDice(6);
      expect(state.consecutiveSixesCount, equals(0));
      expect(state.activePlayerColor, equals(PlayerColor.green));
      expect(state.fsmState, equals(LudoFsmState.waitingForRoll));
      expect(state.validMoves, isEmpty);
    });

    test('Safe tile coexistence: multiple tokens from different players coexist safely without capture', () {
      final initialController = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        config: GameConfig.classic(mandatoryKillRequired: false),
        autoExecuteSingleMove: false,
      );
      var state = initialController.state;

      // Position Red token 0 at track index 8 (relativeStep 7 for Red)
      final redTokens = List<Token>.from(state.players[0].tokens);
      redTokens[0] = redTokens[0].copyWith(
        position: const BoardPosition.track(trackIndex: 8, relativeStep: 7),
      );

      // Position Green token 0 at track index 9 (Safe Star 1)
      final greenTokens = List<Token>.from(state.players[1].tokens);
      greenTokens[0] = greenTokens[0].copyWith(
        position: const BoardPosition.track(trackIndex: 9, relativeStep: 47),
      );

      final controller = LudoGameController(
        initialState: state.copyWith(
          players: [
            state.players[0].copyWith(tokens: redTokens),
            state.players[1].copyWith(tokens: greenTokens),
          ],
        ),
        autoExecuteSingleMove: false,
      );

      // Red rolls 1 -> moves from index 8 to 9 (Star 1 Safe Square!)
      final rollState = controller.rollDice(1);
      final move = rollState.validMoves.firstWhere((m) => m.pawnId == 'red_0');

      // Verify NO capture occurs on safe tile
      expect(move.isCapture, isFalse);
      expect(move.capturedTokenId, isNull);

      final stateAfterMove = controller.executeMove(move);
      final greenPlayer = stateAfterMove.getPlayer(PlayerColor.green)!;

      // Green token is NOT reset to base; it remains safely on track index 9
      expect(greenPlayer.tokens[0].isOnTrack, isTrue);
      final greenPos = greenPlayer.tokens[0].position as BoardPositionTrack;
      expect(greenPos.trackIndex, equals(9));
    });

    test('Non-safe tile collision: captures opponent token, resets it to Base, and awards extra roll', () {
      final initialController = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        config: GameConfig.classic(mandatoryKillRequired: false),
        autoExecuteSingleMove: false,
      );
      var state = initialController.state;

      // Position Red token 0 at track index 1 (Red start, relativeStep 0)
      final redTokens = List<Token>.from(state.players[0].tokens);
      redTokens[0] = redTokens[0].copyWith(
        position: const BoardPosition.track(trackIndex: 1, relativeStep: 0),
      );

      // Position Green token 0 at track index 5 (NOT a safe tile)
      final greenTokens = List<Token>.from(state.players[1].tokens);
      greenTokens[0] = greenTokens[0].copyWith(
        position: const BoardPosition.track(trackIndex: 5, relativeStep: 43),
      );

      final controller = LudoGameController(
        initialState: state.copyWith(
          players: [
            state.players[0].copyWith(tokens: redTokens),
            state.players[1].copyWith(tokens: greenTokens),
          ],
        ),
        autoExecuteSingleMove: false,
      );

      // Red rolls 4: 1 + 4 = 5 (landing square is non-safe index 5 with Green token)
      final rollState = controller.rollDice(4);
      final captureMove = rollState.validMoves.firstWhere((m) => m.pawnId == 'red_0');

      expect(captureMove.isCapture, isTrue);
      expect(captureMove.capturedTokenId, equals('green_0'));
      expect(captureMove.grantsExtraTurn, isTrue);

      final stateAfterMove = controller.executeMove(captureMove);

      // Green token was sent back to Base
      final greenPlayer = stateAfterMove.getPlayer(PlayerColor.green)!;
      expect(greenPlayer.tokens[0].isInBase, isTrue);

      // Red player flagged capture bonus
      final redPlayer = stateAfterMove.getPlayer(PlayerColor.red)!;
      expect(redPlayer.hasKilledOpponent, isTrue);

      // Red gets an extra roll!
      expect(stateAfterMove.activePlayerColor, equals(PlayerColor.red));
      expect(stateAfterMove.fsmState, equals(LudoFsmState.waitingForRoll));
    });

    test('Exact dice roll required to reach final Home index (Step 56, Goal tile index 5)', () {
      final initialController = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        config: GameConfig.classic(mandatoryKillRequired: false),
        autoExecuteSingleMove: false,
      );
      var state = initialController.state;

      // Position Red token 0 at step 54 (home column index 3, 2 steps away from 56)
      final redTokens = List<Token>.from(state.players[0].tokens);
      redTokens[0] = redTokens[0].copyWith(
        position: const BoardPosition.homeColumn(columnStep: 3), // step 54
      );

      final controller = LudoGameController(
        initialState: state.copyWith(
          players: [
            state.players[0].copyWith(tokens: redTokens),
            state.players[1],
          ],
        ),
        autoExecuteSingleMove: false,
      );

      // Case A: Roll 3 -> 54 + 3 = 57 > 56 (Overshoot!). Invalid move, auto-skips turn
      final rollStateOvershoot = controller.rollDice(3);
      expect(rollStateOvershoot.validMoves, isEmpty);
      expect(rollStateOvershoot.activePlayerColor, equals(PlayerColor.green));

      // Reset controller for exact roll test
      final controller2 = LudoGameController(
        initialState: state.copyWith(
          players: [
            state.players[0].copyWith(tokens: redTokens),
            state.players[1],
          ],
        ),
        autoExecuteSingleMove: false,
      );

      // Case B: Roll 2 -> 54 + 2 = 56 (Exact roll to Goal!). Valid move!
      final rollStateExact = controller2.rollDice(2);
      expect(rollStateExact.validMoves.length, equals(1));
      final goalMove = rollStateExact.validMoves.first;
      expect(goalMove.isReachingHome, isTrue);
      expect(goalMove.toRelativeStep, equals(56));
      expect(goalMove.toPosition.isGoal, isTrue);
    });

    test('Mandatory kill requirement blocks entry into home column until a kill is secured', () {
      final initialController = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        config: GameConfig.classic(mandatoryKillRequired: true),
        autoExecuteSingleMove: false,
      );
      var state = initialController.state;

      // Position Red token 0 at step 48 on common track (entrance is step 50)
      final redTokens = List<Token>.from(state.players[0].tokens);
      redTokens[0] = redTokens[0].copyWith(
        position: const BoardPosition.track(trackIndex: 49, relativeStep: 48),
      );

      // Subtest A: hasKilledOpponent == false -> rolling 5 would land on step 53 (> 50). Illegal!
      final controllerNoKill = LudoGameController(
        initialState: state.copyWith(
          players: [
            state.players[0].copyWith(tokens: redTokens, hasKilledOpponent: false),
            state.players[1],
          ],
        ),
        autoExecuteSingleMove: false,
      );
      final rollStateNoKill = controllerNoKill.rollDice(5);
      expect(rollStateNoKill.validMoves, isEmpty);

      // Subtest B: hasKilledOpponent == true -> rolling 5 is permitted into home column
      final controllerWithKill = LudoGameController(
        initialState: state.copyWith(
          players: [
            state.players[0].copyWith(tokens: redTokens, hasKilledOpponent: true),
            state.players[1],
          ],
        ),
        autoExecuteSingleMove: false,
      );
      final rollStateWithKill = controllerWithKill.rollDice(5);
      expect(rollStateWithKill.validMoves.length, equals(1));
      expect(rollStateWithKill.validMoves.first.toRelativeStep, equals(53));
    });

    test('If 0 legal moves exist: automatically advance turn', () {
      final controller = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        autoExecuteSingleMove: true,
      );

      // All Red tokens are in base, rolls 3 -> cannot unlock
      final stateAfterRoll = controller.rollDice(3);
      expect(stateAfterRoll.lastDiceRoll, equals(3));
      expect(stateAfterRoll.activePlayerColor, equals(PlayerColor.green));
      expect(stateAfterRoll.fsmState, equals(LudoFsmState.waitingForRoll));
    });

    test('If exactly 1 legal move exists: auto-select that token when autoExecuteSingleMove is true', () {
      final initialController = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        config: GameConfig.classic(mandatoryKillRequired: false),
      );
      var state = initialController.state;

      // 1 Red token is on track at step 0 (index 1), other 3 are in base
      final redTokens = List<Token>.from(state.players[0].tokens);
      redTokens[0] = redTokens[0].copyWith(
        position: const BoardPosition.track(trackIndex: 1, relativeStep: 0),
      );

      final controller = LudoGameController(
        initialState: state.copyWith(
          players: [
            state.players[0].copyWith(tokens: redTokens),
            state.players[1],
          ],
        ),
        autoExecuteSingleMove: true, // auto-select enabled
      );

      // Roll 3 -> only token 0 can move (tokens in base need 6). Exactly 1 legal move!
      final stateAfterRoll = controller.rollDice(3);

      // Move was auto-selected and executed immediately!
      final movedToken = stateAfterRoll.players[0].tokens[0];
      expect(movedToken.relativeStep, equals(3));
      expect((movedToken.position as BoardPositionTrack).trackIndex, equals(4));
      // No extra turn (roll was 3, no capture, no home) -> advances to green
      expect(stateAfterRoll.activePlayerColor, equals(PlayerColor.green));
    });

    test('A six with no legal moves passes the turn without carrying the sixes streak', () {
      final state = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
      ).state;

      // 3 Red tokens home, last one at step 53: a 6 would overshoot the goal
      final redTokens = [
        for (final t in state.players[0].tokens)
          t.copyWith(position: const BoardPosition.goal()),
      ];
      redTokens[3] = redTokens[3].copyWith(
        position: const BoardPosition.homeColumn(columnStep: 2),
      );

      final controller = LudoGameController(
        initialState: state.copyWith(
          players: [
            state.players[0].copyWith(tokens: redTokens),
            state.players[1],
          ],
          consecutiveSixesCount: 1,
        ),
        autoExecuteSingleMove: false,
      );

      final stateAfterRoll = controller.rollDice(6);
      expect(stateAfterRoll.activePlayerColor, equals(PlayerColor.green));
      expect(stateAfterRoll.consecutiveSixesCount, equals(0));
    });
  });

  group('Undo keeps turn-timer standing', () {
    const engine = LudoEngine();

    test('copies strikes and bot takeovers from now onto the earlier board', () {
      final earlier = engine.newGame(colors: [PlayerColor.red, PlayerColor.green]);
      final moved = engine.executeMove(engine.rollDice(earlier, 6), engine.rollDice(earlier, 6).validMoves.first);
      final now = moved.copyWith(players: [
        moved.players[0].copyWith(strikes: 1),
        moved.players[1].copyWith(strikes: 3, isDisconnected: true),
      ]);

      final restored = engine.withTimerStandingFrom(earlier, now);
      expect(restored.players[0].strikes, 1);
      expect(restored.players[1].isBotControlled, isTrue);
      // The board itself is the earlier one
      expect(restored.players[0].tokens.every((t) => t.isInBase), isTrue);
      expect(restored.activePlayerColor, earlier.activePlayerColor);
    });

    test('a reclaimed seat stays human; nothing to change returns the same state', () {
      final earlier = engine.newGame(colors: [PlayerColor.red, PlayerColor.green]).copyWith(
        players: [
          Player.initial(color: PlayerColor.red).copyWith(strikes: 3, isDisconnected: true),
          Player.initial(color: PlayerColor.green),
        ],
      );
      final reclaimed = engine.reclaimSeat(earlier, PlayerColor.red);
      expect(engine.withTimerStandingFrom(earlier, reclaimed).players[0].isBotControlled, isFalse);
      expect(identical(engine.withTimerStandingFrom(earlier, earlier), earlier), isTrue);
    });
  });

  group('Rules from setup dialog reach the engine config', () {
    test('strike limit maps to the timer: 1 takes over at once, 0 never does', () {
      const engine = LudoEngine();
      GameState timed(int maxStrikes) => engine.newGame(
            colors: [PlayerColor.red, PlayerColor.green],
            rules: GameRules(turnTimerEnabled: true, turnTimerMaxStrikes: maxStrikes),
          );

      final once = timed(1);
      expect(once.config.timerConfig.maxStrikes, 1);
      expect(engine.handleTurnTimeout(once).players[0].isBotControlled, isTrue);

      var never = timed(0);
      for (var i = 0; i < 10; i++) {
        never = engine.handleTurnTimeout(never);
      }
      expect(never.players[0].strikes, 10);
      expect(never.players[0].isBotControlled, isFalse);

      expect(timed(5).rules.turnTimerMaxStrikes, 5);
      expect(GameRules.fromJson(timed(0).rules.toJson()).turnTimerMaxStrikes, 0);
      expect(GameRules.fromJson(const {}).turnTimerMaxStrikes, 3, reason: 'default');
    });

    test('turn time limit maps to the timer and back, and survives JSON', () {
      final controller = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        rules: const GameRules(turnTimerEnabled: true, turnTimeLimitSeconds: 20),
      );
      final timer = controller.state.config.timerConfig;
      expect(timer.enabled, isTrue);
      expect(timer.turnTimeout, const Duration(seconds: 20));
      expect(controller.state.rules.turnTimeLimitSeconds, 20);

      final restored = GameState.fromJson(controller.state.toJson());
      expect(restored.config.timerConfig.turnTimeout, const Duration(seconds: 20));
      expect(GameRules.fromJson(controller.state.rules.toJson()).turnTimeLimitSeconds, 20);
      expect(GameRules.fromJson(const {}).turnTimeLimitSeconds, 12, reason: 'default');
    });

    test('newGame honours unlockYardOnOneOrSix and consecutiveSixesLimit', () {
      final controller = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        rules: const GameRules(
          unlockYardOnOneOrSix: true,
          consecutiveSixesLimit: 2,
        ),
        autoExecuteSingleMove: false,
      );
      expect(controller.state.config.unlockYardOnOneOrSix, isTrue);
      expect(controller.state.config.consecutiveSixesLimit, equals(2));

      // Rolling a 1 can now unlock any of the 4 yard tokens
      final state = controller.rollDice(1);
      expect(state.fsmState, equals(LudoFsmState.waitingForSelection));
      expect(state.validMoves, hasLength(4));
      expect(state.validMoves.every((m) => m.isYardExit), isTrue);
    });

    test('startNewGame honours rules and the custom sixes limit is enforced', () {
      final controller = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        autoExecuteSingleMove: false,
      );
      controller.startNewGame(
        colors: [PlayerColor.red, PlayerColor.green],
        rules: const GameRules(
          winCondition: WinCondition.quick2,
          consecutiveSixesLimit: 2,
        ),
      );
      expect(controller.state.config.mode, isA<RushMode>());
      expect(controller.state.config.consecutiveSixesLimit, equals(2));

      var state = controller.rollDice(6);
      state = controller.executeMove(state.validMoves.first);
      expect(state.activePlayerColor, equals(PlayerColor.red));

      // Second six hits the limit of 2 -> turn forfeited
      state = controller.rollDice(6);
      expect(state.activePlayerColor, equals(PlayerColor.green));
      expect(state.consecutiveSixesCount, equals(0));
    });
  });

  group('3. Game Mode Configurator & Timer Config', () {
    test('Quick Mode: 1 token to win, 1 token starts unlocked, mandatory kill required', () {
      final controller = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        config: GameConfig.quick(),
        autoExecuteSingleMove: false,
      );

      final redPlayer = controller.state.players[0];
      final greenPlayer = controller.state.players[1];

      // 1 token starts unlocked on the board for each player!
      expect(redPlayer.tokens[0].isOnTrack, isTrue);
      expect((redPlayer.tokens[0].position as BoardPositionTrack).trackIndex, equals(1));
      expect(redPlayer.tokens[1].isInBase, isTrue);

      expect(greenPlayer.tokens[0].isOnTrack, isTrue);
      expect((greenPlayer.tokens[0].position as BoardPositionTrack).trackIndex, equals(14));
      expect(greenPlayer.tokens[1].isInBase, isTrue);

      // Tokens to win is 1
      expect(controller.state.config.tokensToWin, equals(1));
      expect(controller.state.config.mustCaptureBeforeHome, isTrue);

      // When Red brings token 0 to home -> game over immediately
      final winToken = redPlayer.tokens[0].copyWith(
        position: const BoardPosition.homeColumn(columnStep: 4), // step 55
      );
      final testController = LudoGameController(
        initialState: controller.state.copyWith(
          players: [
            redPlayer.copyWith(tokens: [winToken, redPlayer.tokens[1], redPlayer.tokens[2], redPlayer.tokens[3]], hasKilledOpponent: true),
            greenPlayer,
          ],
        ),
        autoExecuteSingleMove: false,
      );

      final rollState = testController.rollDice(1);
      final winMove = rollState.validMoves.first;
      final finalState = testController.executeMove(winMove);

      expect(finalState.isGameOver, isTrue);
      expect(finalState.winner, equals(PlayerColor.red));
    });

    test('Classic Mode: 4 tokens to win, 0 start unlocked, mandatory kill required', () {
      final controller = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        config: GameConfig.classic(),
      );

      final redPlayer = controller.state.players[0];
      expect(controller.state.config.tokensToWin, equals(4));
      expect(controller.state.config.mustCaptureBeforeHome, isTrue);
      expect(redPlayer.tokens.every((t) => t.isInBase), isTrue);
    });

    test('TimerConfig: 12-second turn timeout; 3 strikes hands the seat to a bot', () {
      final controller = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        config: const GameConfig(
          timerConfig: TimerConfig(
            turnTimeout: Duration(seconds: 12),
            maxStrikes: 3,
          ),
        ),
      );

      expect(controller.state.config.timerConfig.turnTimeout, equals(const Duration(seconds: 12)));
      expect(controller.state.config.timerConfig.maxStrikes, equals(3));

      expect(controller.state.config.timerConfig.enabled, isFalse,
          reason: 'the timer is opt-in');

      // Strike 1: recorded against Red, turn unchanged (the caller auto-plays it)
      var state = controller.handleTurnTimeout();
      expect(state.players[0].strikes, equals(1));
      expect(state.players[0].isDisconnected, isFalse);
      expect(state.activePlayerColor, equals(PlayerColor.red));
      expect(state.fsmState, equals(LudoFsmState.waitingForRoll));

      // Strike 2
      state = controller.handleTurnTimeout();
      expect(state.players[0].strikes, equals(2));
      expect(state.players[0].isBotControlled, isFalse);

      // Strike 3 -> seat taken over by a bot
      state = controller.handleTurnTimeout();
      expect(state.players[0].strikes, equals(3));
      expect(state.players[0].isDisconnected, isTrue);
      expect(state.players[0].isBotControlled, isTrue);
      expect(state.players[1].strikes, equals(0), reason: 'other players unaffected');

      // The human takes the seat back: strikes reset, timer applies again
      const engine = LudoEngine();
      final reclaimed = engine.reclaimSeat(state, PlayerColor.red);
      expect(reclaimed.players[0].isBotControlled, isFalse);
      expect(reclaimed.players[0].strikes, equals(0));
      expect(reclaimed.activePlayerColor, equals(state.activePlayerColor));

      // Only taken-over seats can be reclaimed
      expect(identical(engine.reclaimSeat(reclaimed, PlayerColor.red), reclaimed), isTrue);
      final withBot = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
        aiConfig: {PlayerColor.green: true},
      ).state;
      expect(identical(engine.reclaimSeat(withBot, PlayerColor.green), withBot), isTrue);
    });
  });

  group('4. Models & AI Heuristics', () {
    test('Token, BoardPosition, Player, and GameState serialization round-trip cleanly', () {
      final state = GameState.initial(
        colors: [PlayerColor.red, PlayerColor.yellow],
        config: GameConfig.quick(),
      );

      final json = state.toJson();
      final restored = GameState.fromJson(json);

      expect(restored.id, equals(state.id));
      expect(restored.players.length, equals(2));
      expect(restored.config.tokensToWin, equals(1));
      expect(restored.activePlayerColor, equals(PlayerColor.red));
    });

    test('Offline AI Engine heuristic strongly prioritizes capture move (+100)', () {
      final aiEngine = LudoAiEngine();
      final controller = LudoGameController.newGame(
        colors: [PlayerColor.red, PlayerColor.green],
      );
      final state = controller.state;

      const normalMove = Move(
        pawnId: 'red_0',
        playerColor: PlayerColor.red,
        diceRoll: 3,
        fromPosition: BoardPosition.track(trackIndex: 1, relativeStep: 0),
        toPosition: BoardPosition.track(trackIndex: 4, relativeStep: 3),
        fromRelativeStep: 0,
        toRelativeStep: 3,
      );

      const captureMove = Move(
        pawnId: 'red_1',
        playerColor: PlayerColor.red,
        diceRoll: 3,
        fromPosition: BoardPosition.track(trackIndex: 2, relativeStep: 1),
        toPosition: BoardPosition.track(trackIndex: 5, relativeStep: 4),
        fromRelativeStep: 1,
        toRelativeStep: 4,
        isCapture: true,
        capturedPawnId: 'green_0',
      );

      final bestMove = aiEngine.selectBestMove(
        state: state,
        validMoves: [normalMove, captureMove],
      );

      expect(bestMove, equals(captureMove));
    });
  });
}
