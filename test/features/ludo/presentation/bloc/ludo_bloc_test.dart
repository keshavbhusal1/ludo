import 'dart:math';

import 'package:bloc_test/bloc_test.dart';
import 'package:fpdart/fpdart.dart' hide State;
import 'package:ludo/core/errors/failures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo/engine/ai/ludo_ai_engine.dart';
import 'package:ludo/engine/ludo_game_engine.dart';
import 'package:ludo/features/ludo/data/datasources/ludo_local_data_source.dart';
import 'package:ludo/features/ludo/data/repositories/ludo_repository_impl.dart';
import 'package:ludo/features/ludo/domain/usecases/clear_saved_game_use_case.dart';
import 'package:ludo/features/ludo/domain/usecases/execute_move_use_case.dart';
import 'package:ludo/features/ludo/domain/usecases/get_saved_game_use_case.dart';
import 'package:ludo/features/ludo/domain/usecases/roll_dice_use_case.dart';
import 'package:ludo/features/ludo/domain/usecases/save_game_use_case.dart';
import 'package:ludo/features/ludo/presentation/bloc/ludo_bloc.dart';
import 'package:ludo/features/ludo/presentation/bloc/ludo_event.dart';
import 'package:ludo/features/ludo/presentation/bloc/ludo_state.dart';
import 'package:ludo/models/board_position.dart';
import 'package:ludo/models/game_config.dart';
import 'package:ludo/models/game_rules.dart';
import 'package:ludo/models/game_state.dart';
import 'package:ludo/models/history_entry.dart';
import 'package:ludo/models/player_color.dart';
import 'package:ludo/models/saved_match.dart';
import 'package:ludo/presentation/themes/board_theme.dart';

import '../../../../helpers/in_memory_local_data_source.dart';

/// Dice stub: `nextInt(6) + 1` always yields [roll].
class _FixedRandom implements Random {
  final int roll;
  _FixedRandom(this.roll);

  @override
  int nextInt(int max) => roll - 1;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

/// Counts dice rolls actually performed by the engine.
class _CountingRollDice extends RollDiceUseCase {
  int calls = 0;
  _CountingRollDice(super.engine, {super.random});

  @override
  Either<Failure, GameState> call(GameState state, {int? forcedRoll}) {
    calls++;
    return super.call(state, forcedRoll: forcedRoll);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const engine = LudoEngine();
  late LudoRepositoryImpl repository;
  late RollDiceUseCase rollDiceUseCase;
  late ExecuteMoveUseCase executeMoveUseCase;
  late GetSavedGameUseCase getSavedGameUseCase;
  late SaveGameUseCase saveGameUseCase;
  late ClearSavedGameUseCase clearSavedGameUseCase;
  late LudoAiEngine aiEngine;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = LudoRepositoryImpl(localDataSource: LudoLocalDataSourceImpl(prefs));
    rollDiceUseCase = RollDiceUseCase(engine);
    executeMoveUseCase = ExecuteMoveUseCase(engine);
    getSavedGameUseCase = GetSavedGameUseCase(repository);
    saveGameUseCase = SaveGameUseCase(repository);
    clearSavedGameUseCase = ClearSavedGameUseCase(repository);
    aiEngine = LudoAiEngine();
  });

  LudoBloc buildBloc() => LudoBloc(
        rollDiceUseCase: rollDiceUseCase,
        executeMoveUseCase: executeMoveUseCase,
        getSavedGameUseCase: getSavedGameUseCase,
        saveGameUseCase: saveGameUseCase,
        clearSavedGameUseCase: clearSavedGameUseCase,
        aiEngine: aiEngine,
      );

  /// Builds a red-vs-green bloc with a fixed dice [roll], starting from the
  /// default new-game state adjusted by [edit].
  LudoBloc buildBlocWithRoll(
    int roll, {
    required bool redIsAi,
    required GameState Function(GameState) edit,
  }) {
    final game = edit(engine.newGame(
      colors: const [PlayerColor.red, PlayerColor.green],
      aiConfig: {PlayerColor.red: redIsAi, PlayerColor.green: false},
    ));
    final bloc = LudoBloc(
      rollDiceUseCase: RollDiceUseCase(engine, random: _FixedRandom(roll)),
      executeMoveUseCase: executeMoveUseCase,
      getSavedGameUseCase: getSavedGameUseCase,
      saveGameUseCase: saveGameUseCase,
      clearSavedGameUseCase: clearSavedGameUseCase,
      aiEngine: aiEngine,
    );
    bloc.emit(LudoActiveState(gameState: game));
    return bloc;
  }

  /// Red has one token on its start square and three in the yard.
  GameState oneRedTokenOut(GameState s) {
    final red = s.players[0];
    final tokens = List.of(red.tokens);
    tokens[0] = tokens[0].copyWith(
      position: const BoardPosition.track(trackIndex: 1, relativeStep: 0),
    );
    return s.copyWith(players: [red.copyWith(tokens: tokens), s.players[1]]);
  }

  /// Red has tokens at steps 0 and 10, so a roll of 3 is a real choice.
  GameState twoRedTokensOut(GameState s) {
    final red = s.players[0];
    final tokens = List.of(red.tokens);
    tokens[0] = tokens[0].copyWith(
      position: const BoardPosition.track(trackIndex: 1, relativeStep: 0),
    );
    tokens[1] = tokens[1].copyWith(
      position: const BoardPosition.track(trackIndex: 11, relativeStep: 10),
    );
    return s.copyWith(players: [red.copyWith(tokens: tokens), s.players[1]]);
  }

  /// Red has three tokens home and one at step 53, so a 6 has no legal move.
  GameState redStuckOnSix(GameState s) {
    final red = s.players[0];
    final tokens = [
      for (final t in red.tokens) t.copyWith(position: const BoardPosition.goal()),
    ];
    tokens[3] = tokens[3].copyWith(
      position: const BoardPosition.homeColumn(columnStep: 2),
    );
    return s.copyWith(players: [red.copyWith(tokens: tokens), s.players[1]]);
  }

  group('LudoBloc bot timing, game speed and stale events', () {
    late _CountingRollDice rolls;

    /// Red-vs-green bloc whose dice always roll 3 (no yard exits: turns just pass).
    LudoBloc buildTimedBloc() {
      rolls = _CountingRollDice(engine, random: _FixedRandom(3));
      return LudoBloc(
        rollDiceUseCase: rolls,
        executeMoveUseCase: ExecuteMoveUseCase(engine),
        getSavedGameUseCase: GetSavedGameUseCase(LudoRepositoryImpl(localDataSource: InMemoryLocalDataSource())),
        saveGameUseCase: SaveGameUseCase(LudoRepositoryImpl(localDataSource: InMemoryLocalDataSource())),
        clearSavedGameUseCase: ClearSavedGameUseCase(LudoRepositoryImpl(localDataSource: InMemoryLocalDataSource())),
        aiEngine: aiEngine,
      );
    }

    LudoStarted start({required bool redIsAi, double speed = 1.0}) => LudoStarted(
          colors: const [PlayerColor.red, PlayerColor.green],
          aiConfig: {PlayerColor.red: redIsAi, PlayerColor.green: true},
          rules: GameRules(gameSpeed: speed),
        );

    Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

    test('restarting while a bot is thinking cancels its pending roll', () async {
      final bloc = buildTimedBloc();
      bloc.add(start(redIsAi: true));
      await wait(50); // red bot is now thinking (600-900ms)

      bloc.add(start(redIsAi: false)); // new match: red is human
      await wait(1100);

      final s = bloc.state as LudoActiveState;
      expect(rolls.calls, 0, reason: 'the old bot must not roll in the new match');
      expect(s.isShowingRollOverlay, isFalse);
      expect(s.gameState.activePlayerColor, PlayerColor.red);
      await bloc.close();
    });

    test('duplicate bot triggers produce a single bot action', () async {
      final bloc = buildTimedBloc();
      bloc.add(start(redIsAi: true));
      bloc.add(const LudoAiTurnTriggered());
      bloc.add(const LudoAiTurnTriggered());

      // Red rolls by 900ms; green can't roll before 900 + 700 settle + 600 think.
      await wait(1300);
      expect(rolls.calls, 1);
      expect((bloc.state as LudoActiveState).gameState.activePlayerColor, PlayerColor.green);
      await bloc.close();
    });

    test('game speed scales bot thinking time', () async {
      final fast = buildTimedBloc();
      fast.add(start(redIsAi: true, speed: 2.0));
      await wait(500); // 600-900ms at 1x -> 300-450ms at 2x
      expect(rolls.calls, 1);
      await fast.close();

      final normal = buildTimedBloc();
      normal.add(start(redIsAi: true));
      await wait(500);
      expect(rolls.calls, 0);
      await normal.close();
    });

    test('closing the bloc cancels pending bot steps', () async {
      final bloc = buildTimedBloc();
      bloc.add(start(redIsAi: true));
      await wait(50);
      await bloc.close();
      await wait(1000);
      expect(rolls.calls, 0);
    });

    test('a dice overlay finishing after a restart is ignored', () async {
      final bloc = buildTimedBloc();
      bloc.add(start(redIsAi: false));
      await wait(20);
      bloc.add(const LudoDiceRollRequested());
      await wait(20);
      expect((bloc.state as LudoActiveState).isShowingRollOverlay, isTrue);

      bloc.add(start(redIsAi: false));
      bloc.add(const LudoDiceRollOverlayCompleted()); // from the old overlay widget
      await wait(20);

      final s = bloc.state as LudoActiveState;
      expect(s.sideEffect, isNull);
      expect(s.gameState.activePlayerColor, PlayerColor.red);
      expect(s.gameState.lastDiceRoll, isNull);
      await bloc.close();
    });

    test('AI thinkingDelay divides by game speed', () {
      final ai = LudoAiEngine(random: _FixedRandom(1)); // nextInt -> 0: minimum delay
      expect(ai.thinkingDelay(minMs: 600, maxMs: 900), const Duration(milliseconds: 600));
      expect(ai.thinkingDelay(minMs: 600, maxMs: 900, gameSpeed: 2.0),
          const Duration(milliseconds: 300));
    });
  });

  group('LudoBloc turn timer', () {
    late _CountingRollDice rolls;

    /// Snackbar messages in emission order, as the screen's listener sees them.
    late List<String> snackbars;

    /// The store the latest [timedBloc] saves to.
    late InMemoryLocalDataSource store;
    const timeout = Duration(milliseconds: 150);

    Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
    LudoActiveState stateOf(LudoBloc bloc) => bloc.state as LudoActiveState;

    /// Red (human) vs green (bot) with a 150 ms turn timer, adjusted by [edit].
    GameState timedGame(
      GameState Function(GameState) edit, {
      bool timerOn = true,
      int maxStrikes = 3,
    }) =>
        edit(engine.newGame(
          colors: const [PlayerColor.red, PlayerColor.green],
          aiConfig: const {PlayerColor.red: false, PlayerColor.green: true},
          config: GameConfig(
            timerConfig: TimerConfig(
              enabled: timerOn,
              turnTimeout: timeout,
              maxStrikes: maxStrikes,
            ),
          ),
        ));

    LudoBloc timedBloc(GameState game, {int roll = 3}) {
      rolls = _CountingRollDice(engine, random: _FixedRandom(roll));
      store = InMemoryLocalDataSource();
      final repo = LudoRepositoryImpl(localDataSource: store);
      final bloc = LudoBloc(
        rollDiceUseCase: rolls,
        executeMoveUseCase: ExecuteMoveUseCase(engine),
        getSavedGameUseCase: GetSavedGameUseCase(repo),
        saveGameUseCase: SaveGameUseCase(repo),
        clearSavedGameUseCase: ClearSavedGameUseCase(repo),
        aiEngine: aiEngine,
      );
      snackbars = [];
      bloc.stream.listen((s) {
        final effect = s is LudoActiveState ? s.sideEffect : null;
        if (effect is LudoSnackbarEffect) snackbars.add(effect.message);
      });
      bloc.emit(LudoActiveState(gameState: game));
      // Any event re-evaluates the timer; this one changes nothing else
      bloc.add(const LudoAppLifecycleChanged(isForeground: true));
      return bloc;
    }

    test('is off by default: no deadline and nothing happens', () async {
      final bloc = timedBloc(timedGame(oneRedTokenOut, timerOn: false));
      await wait(300);
      expect(stateOf(bloc).turnDeadline, isNull);
      expect(rolls.calls, 0);
      expect(stateOf(bloc).gameState.players[0].strikes, 0);
      await bloc.close();
    });

    test('publishes a deadline for the countdown when a human turn starts', () async {
      final bloc = timedBloc(timedGame(oneRedTokenOut));
      await wait(20);
      final deadline = stateOf(bloc).turnDeadline;
      expect(deadline, isNotNull);
      expect(deadline!.difference(DateTime.now()).inMilliseconds, inInclusiveRange(0, 150));
      await bloc.close();
    });

    test('timeout before rolling: a strike, then the bot rolls and moves for them', () async {
      final bloc = timedBloc(timedGame(oneRedTokenOut));
      await wait(250);

      final s = stateOf(bloc);
      expect(rolls.calls, 1);
      expect(s.gameState.players[0].strikes, 1);
      expect(s.gameState.players[0].isBotControlled, isFalse);
      expect(s.animatingMove?.pawnId, 'red_0', reason: 'the roll was not wasted');
      expect(s.turnDeadline, isNull);
      expect(snackbars, contains(contains('ran out of time (strike 1/3)')));
      await bloc.close();
    });

    test('timeout while choosing a token auto-plays the best move without re-rolling', () async {
      final bloc = timedBloc(timedGame(twoRedTokensOut));
      bloc.add(const LudoDiceRollRequested());
      await wait(20);
      bloc.add(const LudoDiceRollOverlayCompleted());
      await wait(20);
      expect(stateOf(bloc).gameState.validMoves, hasLength(2));
      expect(stateOf(bloc).turnDeadline, isNotNull, reason: 'choosing is timed too');

      await wait(250);
      final s = stateOf(bloc);
      expect(rolls.calls, 1);
      expect(s.gameState.players[0].strikes, 1);
      expect(s.animatingMove, isNotNull);
      await bloc.close();
    });

    test('acting in time cancels the timer (no strike while the dice tumble)', () async {
      final bloc = timedBloc(timedGame(oneRedTokenOut));
      await wait(20);
      bloc.add(const LudoDiceRollRequested()); // overlay now showing
      await wait(300);

      final s = stateOf(bloc);
      expect(s.isShowingRollOverlay, isTrue);
      expect(s.turnDeadline, isNull);
      expect(s.gameState.players[0].strikes, 0);
      await bloc.close();
    });

    test('the third timeout hands the seat to a bot', () async {
      final bloc = timedBloc(timedGame((g) {
        final red = oneRedTokenOut(g).players[0].copyWith(strikes: 2);
        return g.copyWith(players: [red, g.players[1]]);
      }));
      await wait(250);

      final s = stateOf(bloc);
      final red = s.gameState.players[0];
      expect(red.strikes, 3);
      expect(red.isBotControlled, isTrue);
      expect(red.isAi, isFalse, reason: 'still a human seat; restarting gives it back');
      expect(snackbars, contains(contains('a bot takes over')));
      await bloc.close();
    });

    test('a bot-controlled seat is played by the bot with no timer', () async {
      final bloc = timedBloc(timedGame((g) {
        final red = g.players[0].copyWith(strikes: 3, isDisconnected: true);
        return g.copyWith(players: [red, g.players[1]]);
      }));
      // Nudge the bot loop the way a turn change would
      bloc.add(const LudoAiTurnTriggered());
      await wait(20);
      expect(stateOf(bloc).turnDeadline, isNull);

      await wait(1000); // bot thinks 600-900 ms, then rolls
      expect(rolls.calls, 1);
      expect(stateOf(bloc).gameState.players[0].strikes, 3, reason: 'bots take no strikes');
      await bloc.close();
    });

    test('the timer pauses in the background and restarts in full on return', () async {
      final bloc = timedBloc(timedGame(oneRedTokenOut));
      await wait(20);
      bloc.add(const LudoAppLifecycleChanged(isForeground: false));
      await wait(300);
      expect(stateOf(bloc).turnDeadline, isNull);
      expect(stateOf(bloc).gameState.players[0].strikes, 0);
      expect(rolls.calls, 0);

      bloc.add(const LudoAppLifecycleChanged(isForeground: true));
      await wait(20);
      final deadline = stateOf(bloc).turnDeadline;
      expect(deadline, isNotNull);
      expect(deadline!.difference(DateTime.now()).inMilliseconds, greaterThan(100));
      await bloc.close();
    });

    test('a strike limit of 1 hands the seat over on the first timeout', () async {
      final bloc = timedBloc(timedGame(oneRedTokenOut, maxStrikes: 1));
      await wait(250);
      expect(stateOf(bloc).gameState.players[0].isBotControlled, isTrue);
      expect(snackbars, contains('Red timed out once — a bot takes over'));
      await bloc.close();
    });

    test('with no strike limit a timeout auto-plays but never takes the seat', () async {
      final bloc = timedBloc(timedGame((g) {
        final red = oneRedTokenOut(g).players[0].copyWith(strikes: 9);
        return g.copyWith(players: [red, g.players[1]]);
      }, maxStrikes: 0));
      await wait(250);

      final red = stateOf(bloc).gameState.players[0];
      expect(red.strikes, 10);
      expect(red.isBotControlled, isFalse);
      expect(stateOf(bloc).animatingMove, isNotNull, reason: 'the turn was still auto-played');
      expect(snackbars, contains('Red ran out of time — auto-playing'));
      await bloc.close();
    });

    test('a timeout strike is not undone', () async {
      // Both human, 300 ms timer: margins for red's quick pick and the undo
      final game = twoRedTokensOut(engine.newGame(
        colors: const [PlayerColor.red, PlayerColor.green],
        aiConfig: const {PlayerColor.red: false, PlayerColor.green: false},
        config: const GameConfig(
          timerConfig: TimerConfig(enabled: true, turnTimeout: Duration(milliseconds: 300)),
        ),
      ));
      final bloc = timedBloc(game);
      bloc.add(const LudoDiceRollRequested());
      await wait(20);
      bloc.add(const LudoDiceRollOverlayCompleted()); // red's choice: undo point
      await wait(20);
      final move = stateOf(bloc).gameState.validMoves.first;
      bloc.add(LudoMoveSelected(move));
      await wait(10);
      bloc.add(LudoMoveAnimationCompleted(move));

      await wait(420); // green times out (~300 ms): strike, auto-roll, turn passes
      expect(stateOf(bloc).gameState.players[1].strikes, 1);
      expect(stateOf(bloc).gameState.activePlayerColor, PlayerColor.red);

      bloc.add(const LudoUndoRequested());
      await wait(20);
      final s = stateOf(bloc);
      expect(s.gameState.turnPhase, TurnPhase.awaitingPawnSelection, reason: "back at red's choice");
      expect(s.gameState.players[1].strikes, 1, reason: "green's strike stands");
      expect(identical(s.undoStack.last.state, s.gameState), isTrue);
      expect(s.canUndo, isFalse, reason: 'already at the only choice point');
      await bloc.close();
    });

    /// Red's seat was taken over by a bot after 3 timeouts.
    GameState redTakenOver(GameState g) {
      final red = g.players[0].copyWith(strikes: 3, isDisconnected: true);
      return g.copyWith(players: [red, g.players[1]]);
    }

    test('reclaiming on your turn cancels the thinking bot; you roll yourself', () async {
      final bloc = timedBloc(timedGame((g) => redTakenOver(oneRedTokenOut(g)), timerOn: false));
      bloc.add(const LudoAiTurnTriggered()); // bot starts thinking (600-900 ms)
      await wait(50);
      bloc.add(const LudoSeatReclaimed(PlayerColor.red));
      await wait(1000);

      final red = stateOf(bloc).gameState.players[0];
      expect(rolls.calls, 0, reason: "the bot's pending roll was cancelled");
      expect(red.isBotControlled, isFalse);
      expect(red.strikes, 0);
      expect(stateOf(bloc).gameState.turnPhase, TurnPhase.awaitingRoll);
      expect(snackbars, contains('Red is back in control'));
      expect(store.saved?.game.players[0].isBotControlled, isFalse, reason: 'autosaved');
      await bloc.close();
    });

    test('reclaiming while the bot is about to pick keeps the same roll for you', () async {
      final bloc = timedBloc(timedGame(
        (g) => engine.rollDice(redTakenOver(twoRedTokensOut(g)), 3),
        timerOn: false,
      ));
      bloc.add(const LudoAiTurnTriggered()); // bot will pick in 450-750 ms
      await wait(50);
      bloc.add(const LudoSeatReclaimed(PlayerColor.red));
      await wait(900);

      final s = stateOf(bloc);
      expect(s.animatingMove, isNull, reason: 'the bot did not move');
      expect(s.gameState.turnPhase, TurnPhase.awaitingPawnSelection);
      expect(s.gameState.lastDiceRoll, 3);
      expect(s.gameState.validMoves, hasLength(2));
      await bloc.close();
    });

    test('reclaiming restarts the turn timer for the returning human', () async {
      final bloc = timedBloc(timedGame((g) => redTakenOver(oneRedTokenOut(g))));
      await wait(20);
      expect(stateOf(bloc).turnDeadline, isNull, reason: 'bots are not timed');

      bloc.add(const LudoSeatReclaimed(PlayerColor.red));
      await wait(20);
      expect(stateOf(bloc).turnDeadline, isNotNull);
      await bloc.close();
    });

    test("reclaiming off-turn leaves another bot's turn alone", () async {
      final bloc = timedBloc(timedGame(
        (g) => redTakenOver(g).copyWith(activePlayerIndex: 1), // green bot to roll
        timerOn: false,
      ));
      bloc.add(const LudoAiTurnTriggered());
      await wait(50);
      bloc.add(const LudoSeatReclaimed(PlayerColor.red));
      await wait(1000);

      expect(rolls.calls, 1, reason: 'green still rolled');
      expect(stateOf(bloc).gameState.players[0].isBotControlled, isFalse);
      await bloc.close();
    });

    test('a seat that was a bot from the start cannot be reclaimed', () async {
      final bloc = timedBloc(timedGame((g) => g, timerOn: false));
      await wait(20);
      final before = stateOf(bloc).gameState;

      bloc.add(const LudoSeatReclaimed(PlayerColor.green));
      await wait(20);
      expect(identical(stateOf(bloc).gameState, before), isTrue);
      expect(stateOf(bloc).gameState.players[1].isBotControlled, isTrue);
      expect(snackbars, isEmpty);
      await bloc.close();
    });

    test('the chosen time limit is used and survives a restart', () async {
      int secondsLeft(LudoBloc b) =>
          (stateOf(b).turnDeadline!.difference(DateTime.now()).inMilliseconds / 1000).ceil();

      final bloc = buildBloc();
      bloc.add(const LudoStarted(
        colors: [PlayerColor.red, PlayerColor.green],
        aiConfig: {PlayerColor.red: false, PlayerColor.green: true},
        rules: GameRules(turnTimerEnabled: true, turnTimeLimitSeconds: 20),
      ));
      await wait(20);
      expect(secondsLeft(bloc), 20);

      bloc.add(const LudoMatchRestarted());
      await wait(20);
      expect(stateOf(bloc).gameState.config.timerConfig.enabled, isTrue);
      expect(stateOf(bloc).gameState.config.timerConfig.turnTimeout, const Duration(seconds: 20));
      expect(secondsLeft(bloc), 20);
      await bloc.close();
    });
  });

  group('LudoBloc undo and move history', () {
    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

    LudoActiveState stateOf(LudoBloc bloc) => bloc.state as LudoActiveState;

    Future<void> humanRoll(LudoBloc bloc) async {
      bloc.add(const LudoDiceRollRequested());
      await settle();
      bloc.add(const LudoDiceRollOverlayCompleted());
      await settle();
    }

    /// Selects [pawnId]'s move and finishes its animation, as the screen would.
    Future<void> play(LudoBloc bloc, String pawnId) async {
      final move = stateOf(bloc).gameState.validMoves.firstWhere((m) => m.pawnId == pawnId);
      bloc.add(LudoMoveSelected(move));
      await settle();
      bloc.add(LudoMoveAnimationCompleted(move));
      await settle();
    }

    test('undo rewinds to the last token choice with the same dice, then allows a different pick', () async {
      final bloc = buildBlocWithRoll(3, redIsAi: false, edit: twoRedTokensOut);

      await humanRoll(bloc); // red: 2 choices -> undo point
      expect(stateOf(bloc).undoStack, hasLength(1));
      expect(stateOf(bloc).canUndo, isFalse, reason: 'already at the only choice point');

      await play(bloc, 'red_0');
      await humanRoll(bloc); // green: all in yard, turn passes back to red
      expect(stateOf(bloc).history.map((e) => e.outcome),
          [TurnOutcome.moved, TurnOutcome.noMoves]);
      expect(stateOf(bloc).canUndo, isTrue);

      bloc.add(const LudoUndoRequested());
      await settle();
      final undone = stateOf(bloc);
      expect(undone.gameState.activePlayerColor, PlayerColor.red);
      expect(undone.gameState.turnPhase, TurnPhase.awaitingPawnSelection);
      expect(undone.gameState.lastDiceRoll, 3, reason: 'same dice, no re-roll');
      expect(undone.gameState.players[0].tokens[0].relativeStep, 0);
      expect(undone.history, isEmpty);
      expect(undone.canUndo, isFalse);

      await play(bloc, 'red_1'); // pick the other token this time
      final after = stateOf(bloc);
      expect(after.gameState.players[0].tokens[0].relativeStep, 0);
      expect(after.gameState.players[0].tokens[1].relativeStep, 13);
      expect(after.history.single.move?.pawnId, 'red_1');
      expect(after.canUndo, isTrue, reason: 'can come back to the same choice again');
      await bloc.close();
    });

    test('repeated undo steps back through earlier choices', () async {
      final bloc = buildBlocWithRoll(3, redIsAi: false, edit: twoRedTokensOut);

      await humanRoll(bloc); // choice P1
      await play(bloc, 'red_0');
      await humanRoll(bloc); // green passes
      await humanRoll(bloc); // red: choice P2
      expect(stateOf(bloc).undoStack, hasLength(2));
      await play(bloc, 'red_0');
      expect(stateOf(bloc).history, hasLength(3));

      bloc.add(const LudoUndoRequested());
      await settle();
      expect(stateOf(bloc).history, hasLength(2));
      expect(stateOf(bloc).gameState.players[0].tokens[0].relativeStep, 3);

      bloc.add(const LudoUndoRequested());
      await settle();
      expect(stateOf(bloc).history, isEmpty);
      expect(stateOf(bloc).gameState.players[0].tokens[0].relativeStep, 0);
      expect(stateOf(bloc).undoStack, hasLength(1));
      await bloc.close();
    });

    test('undo cancels a bot that is about to act and rewinds its turn', () async {
      final rolls = _CountingRollDice(engine, random: _FixedRandom(3));
      final bloc = LudoBloc(
        rollDiceUseCase: rolls,
        executeMoveUseCase: executeMoveUseCase,
        getSavedGameUseCase: getSavedGameUseCase,
        saveGameUseCase: saveGameUseCase,
        clearSavedGameUseCase: clearSavedGameUseCase,
        aiEngine: aiEngine,
      );
      bloc.emit(LudoActiveState(
        gameState: twoRedTokensOut(engine.newGame(
          colors: const [PlayerColor.red, PlayerColor.green],
          aiConfig: const {PlayerColor.red: false, PlayerColor.green: true},
        )),
      ));

      await humanRoll(bloc);
      await play(bloc, 'red_0'); // green bot starts thinking (600-900ms)
      expect(rolls.calls, 1);

      bloc.add(const LudoUndoRequested());
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(rolls.calls, 1, reason: 'the bot must not roll after undo');
      expect(stateOf(bloc).gameState.activePlayerColor, PlayerColor.red);
      expect(stateOf(bloc).gameState.turnPhase, TurnPhase.awaitingPawnSelection);
      await bloc.close();
    });

    test('a forced single move is not an undo point', () async {
      final bloc = buildBlocWithRoll(3, redIsAi: false, edit: oneRedTokenOut);
      await humanRoll(bloc);
      expect(stateOf(bloc).gameState.validMoves, hasLength(1));
      expect(stateOf(bloc).undoStack, isEmpty);
      await bloc.close();
    });

    test('undo is unavailable while dice tumble or a pawn animates', () async {
      final bloc = buildBlocWithRoll(3, redIsAi: false, edit: twoRedTokensOut);
      await humanRoll(bloc);
      await play(bloc, 'red_0');
      expect(stateOf(bloc).canUndo, isTrue);

      bloc.add(const LudoDiceRollRequested()); // green's overlay now showing
      await settle();
      expect(stateOf(bloc).isShowingRollOverlay, isTrue);
      expect(stateOf(bloc).canUndo, isFalse);

      bloc.add(const LudoUndoRequested());
      await settle();
      expect(stateOf(bloc).gameState.activePlayerColor, PlayerColor.green, reason: 'ignored');
      await bloc.close();
    });

    test('history and undo survive closing the app and resuming', () async {
      // Saves go through the real shared_preferences JSON store (mocked prefs)
      final first = buildBlocWithRoll(3, redIsAi: false, edit: twoRedTokensOut);
      await humanRoll(first); // red choice
      await play(first, 'red_0');
      await humanRoll(first); // green passes
      await first.close();

      final second = buildBloc();
      second.add(const LudoStarted(
        colors: [PlayerColor.red, PlayerColor.green],
        aiConfig: {PlayerColor.red: false, PlayerColor.green: false},
      ));
      await settle();
      second.add(const LudoSavedMatchResumed());
      await settle();

      final resumed = stateOf(second);
      expect(resumed.history.map((e) => e.outcome), [TurnOutcome.moved, TurnOutcome.noMoves]);
      expect(resumed.gameState.players[0].tokens[0].relativeStep, 3);
      expect(resumed.canUndo, isTrue);

      second.add(const LudoUndoRequested());
      await settle();
      final undone = stateOf(second);
      expect(undone.gameState.turnPhase, TurnPhase.awaitingPawnSelection);
      expect(undone.gameState.lastDiceRoll, 3);
      expect(undone.gameState.players[0].tokens[0].relativeStep, 0);
      expect(undone.history, isEmpty);
      expect(undone.canUndo, isFalse);
      await second.close();
    });

    test('resuming at a choice point offers the choice, not a no-op undo', () async {
      final first = buildBlocWithRoll(3, redIsAi: false, edit: twoRedTokensOut);
      await humanRoll(first); // saved while red is choosing
      await first.close();

      final second = buildBloc();
      second.add(const LudoStarted(
        colors: [PlayerColor.red, PlayerColor.green],
        aiConfig: {PlayerColor.red: false, PlayerColor.green: false},
      ));
      await settle();
      second.add(const LudoSavedMatchResumed());
      await settle();

      final resumed = stateOf(second);
      expect(resumed.gameState.turnPhase, TurnPhase.awaitingPawnSelection);
      expect(resumed.gameState.validMoves, hasLength(2));
      expect(resumed.undoStack, hasLength(1));
      expect(resumed.canUndo, isFalse);
      await second.close();
    });

    test('undoing to a choice for a seat a bot has since taken over lets the bot choose', () async {
      final bloc = buildBlocWithRoll(3, redIsAi: false, edit: twoRedTokensOut);
      await humanRoll(bloc); // red's choice: undo point
      await play(bloc, 'red_0');
      await humanRoll(bloc); // green passes back to red

      // Red's seat is taken over after the undo point
      final now = stateOf(bloc);
      bloc.emit(now.copyWith(
        gameState: now.gameState.copyWith(players: [
          now.gameState.players[0].copyWith(strikes: 3, isDisconnected: true),
          now.gameState.players[1],
        ]),
      ));

      bloc.add(const LudoUndoRequested());
      await settle();
      expect(stateOf(bloc).gameState.players[0].isBotControlled, isTrue);
      expect((stateOf(bloc).sideEffect as LudoSnackbarEffect).message,
          'Undone — a bot is choosing for Red');

      await Future<void>.delayed(const Duration(milliseconds: 900)); // bot thinks 450-750 ms
      expect(stateOf(bloc).animatingMove, isNotNull, reason: 'the bot picked a token');
      await bloc.close();
    });

    test('history logs captures with the victim and sixes penalties', () async {
      // Red at step 0 rolls 4 onto track index 5, where a green token sits
      final bloc = buildBlocWithRoll(4, redIsAi: false, edit: (s) {
        final withRed = twoRedTokensOut(s);
        final green = withRed.players[1];
        final greenTokens = List.of(green.tokens);
        greenTokens[0] = greenTokens[0].copyWith(
          position: const BoardPosition.track(trackIndex: 5, relativeStep: 43),
        );
        return withRed.copyWith(players: [withRed.players[0], green.copyWith(tokens: greenTokens)]);
      });
      await humanRoll(bloc);
      await play(bloc, 'red_0');

      final entry = stateOf(bloc).history.single;
      expect(entry.move?.isCapture, isTrue);
      expect(entry.capturedPlayerName, 'Green');
      expect(entry.description, "rolled 4 — captured Green's token");
      await bloc.close();
    });
  });

  group('LudoBloc owns its state', () {
    test('two blocs sharing the same use cases keep independent matches', () async {
      // Mirrors DI: one engine and use-case set shared by every bloc instance.
      final store = InMemoryLocalDataSource();
      final repo = LudoRepositoryImpl(localDataSource: store);
      LudoBloc make() => LudoBloc(
            rollDiceUseCase: RollDiceUseCase(engine, random: _FixedRandom(6)),
            executeMoveUseCase: ExecuteMoveUseCase(engine),
            getSavedGameUseCase: GetSavedGameUseCase(repo),
            saveGameUseCase: SaveGameUseCase(repo),
            clearSavedGameUseCase: ClearSavedGameUseCase(repo),
            aiEngine: aiEngine,
          );
      final a = make();
      final b = make();
      const humans = {PlayerColor.red: false, PlayerColor.green: false};

      a.add(const LudoStarted(colors: [PlayerColor.red, PlayerColor.green], aiConfig: humans));
      b.add(const LudoStarted(
        colors: [PlayerColor.yellow, PlayerColor.blue],
        aiConfig: {PlayerColor.yellow: false, PlayerColor.blue: false},
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      a.add(const LudoDiceRollRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      a.add(const LudoDiceRollOverlayCompleted());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sa = (a.state as LudoActiveState).gameState;
      final sb = (b.state as LudoActiveState).gameState;
      expect(sa.lastDiceRoll, 6);
      expect(sa.turnPhase, TurnPhase.awaitingPawnSelection);
      expect(sb.players.map((p) => p.color), [PlayerColor.yellow, PlayerColor.blue]);
      expect(sb.lastDiceRoll, isNull);
      expect(sb.turnPhase, TurnPhase.awaitingRoll);
      await a.close();
      await b.close();
    });

    test('engine operations are pure: same input, same output, input untouched', () {
      final game = engine.newGame(colors: const [PlayerColor.red, PlayerColor.green], gameId: 'g');
      final before = game.toJson().toString();

      final r1 = engine.rollDice(game, 6);
      final r2 = engine.rollDice(game, 6);
      expect(r1.toJson().toString(), r2.toJson().toString());

      final m1 = engine.executeMove(r1, r1.validMoves.first);
      final m2 = engine.executeMove(r1, r1.validMoves.first);
      expect(m1.toJson().toString(), m2.toJson().toString());

      expect(game.toJson().toString(), before);
      expect(r1.validMoves, isNotEmpty, reason: 'executeMove must not alter its input');
    });

    test('engine rejects a move that is not legal in the given state', () {
      final game = engine.newGame(colors: const [PlayerColor.red, PlayerColor.green]);
      final rolled = engine.rollDice(game, 6);
      final move = rolled.validMoves.first;
      // Same move against the pre-roll state: not legal there
      expect(identical(engine.executeMove(game, move), game), isTrue);
      expect(ExecuteMoveUseCase(engine)(game, move).isLeft(), isTrue);
    });
  });

  group('LudoBloc saved-match banner', () {
    final savedMatch = GameState.initial(
      colors: const [PlayerColor.red, PlayerColor.green],
      gameId: 'saved_match',
    );

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

    /// Bloc over a fixed roll of 3 (no yard exits, so turns just pass) and [store].
    LudoBloc buildBlocWithStore(InMemoryLocalDataSource store) {
      final repo = LudoRepositoryImpl(localDataSource: store);
      return LudoBloc(
        rollDiceUseCase: RollDiceUseCase(engine, random: _FixedRandom(3)),
        executeMoveUseCase: ExecuteMoveUseCase(engine),
        getSavedGameUseCase: GetSavedGameUseCase(repo),
        saveGameUseCase: SaveGameUseCase(repo),
        clearSavedGameUseCase: ClearSavedGameUseCase(repo),
        aiEngine: aiEngine,
      );
    }

    Future<void> startAndRollOnce(LudoBloc bloc) async {
      bloc.add(const LudoStarted(
        colors: [PlayerColor.red, PlayerColor.green],
        aiConfig: {PlayerColor.red: false, PlayerColor.green: false},
      ));
      await settle();
      expect((bloc.state as LudoActiveState).hasSavedGameBanner, isTrue);

      bloc.add(const LudoDiceRollRequested());
      await settle();
      bloc.add(const LudoDiceRollOverlayCompleted());
      await settle();
    }

    test('playing while the banner is up does not overwrite the stored match', () async {
      final store = InMemoryLocalDataSource(SavedMatch(game: savedMatch));
      final bloc = buildBlocWithStore(store);

      await startAndRollOnce(bloc);
      final s = bloc.state as LudoActiveState;
      expect(s.gameState.activePlayerColor, PlayerColor.green, reason: 'the roll was played');
      expect(store.saveCount, 0);
      expect(store.saved?.game.id, 'saved_match');
      await bloc.close();
    });

    test('RESUME after playing restores the stored match, not the new one', () async {
      final store = InMemoryLocalDataSource(SavedMatch(game: savedMatch));
      final bloc = buildBlocWithStore(store);

      await startAndRollOnce(bloc);
      bloc.add(const LudoSavedMatchResumed());
      await settle();

      final s = bloc.state as LudoActiveState;
      expect(s.gameState.id, 'saved_match');
      expect(s.gameState.activePlayerColor, PlayerColor.red);
      expect(s.hasSavedGameBanner, isFalse);
      expect(s.history, isEmpty, reason: "the new game's turns don't belong to the resumed match");
      expect(s.undoStack, isEmpty);
      await bloc.close();
    });

    test('dismissing the banner hands the autosave slot to the current match', () async {
      final store = InMemoryLocalDataSource(SavedMatch(game: savedMatch));
      final bloc = buildBlocWithStore(store);

      await startAndRollOnce(bloc);
      final currentId = (bloc.state as LudoActiveState).gameState.id;
      bloc.add(const LudoSavedMatchBannerDismissed());
      await settle();

      expect((bloc.state as LudoActiveState).hasSavedGameBanner, isFalse);
      expect(store.saved?.game.id, currentId);
      expect(store.saved?.game.activePlayerColor, PlayerColor.green);

      // Later turns keep autosaving normally
      final savesBefore = store.saveCount;
      bloc.add(const LudoDiceRollRequested());
      await settle();
      bloc.add(const LudoDiceRollOverlayCompleted());
      await settle();
      expect(store.saveCount, greaterThan(savesBefore));
      await bloc.close();
    });

    test('no banner and normal autosave when there is no stored match', () async {
      final store = InMemoryLocalDataSource();
      final bloc = buildBlocWithStore(store);

      bloc.add(const LudoStarted(
        colors: [PlayerColor.red, PlayerColor.green],
        aiConfig: {PlayerColor.red: false, PlayerColor.green: false},
      ));
      await settle();
      expect((bloc.state as LudoActiveState).hasSavedGameBanner, isFalse);

      bloc.add(const LudoDiceRollRequested());
      await settle();
      bloc.add(const LudoDiceRollOverlayCompleted());
      await settle();
      expect(store.saved?.game.id, (bloc.state as LudoActiveState).gameState.id);
      await bloc.close();
    });
  });

  group('LudoBloc forced moves and sixes', () {
    blocTest<LudoBloc, LudoState>(
      'ignores an animation-completed event for a move it is not animating',
      build: () => buildBlocWithRoll(3, redIsAi: false, edit: oneRedTokenOut),
      act: (bloc) async {
        bloc.add(const LudoDiceRollRequested());
        await Future<void>.delayed(Duration.zero);
        // Stale completion arrives before the bloc ever started animating this move
        final move = (bloc.state as LudoActiveState).pendingRoll!.validMoves.single;
        bloc.add(LudoMoveAnimationCompleted(move));
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        final s = bloc.state as LudoActiveState;
        expect(s.gameState.players[0].tokens[0].relativeStep, 0);
        expect(s.pendingRoll?.turnPhase, TurnPhase.awaitingPawnSelection);
      },
    );

    test('engine leaves a single legal move to the caller so it can animate', () {
      final game = oneRedTokenOut(engine.newGame(
        colors: const [PlayerColor.red, PlayerColor.green],
      ));
      final rolled = engine.rollDice(game, 3);
      expect(rolled.turnPhase, TurnPhase.awaitingPawnSelection);
      expect(rolled.validMoves, hasLength(1));
      expect(rolled.players[0].tokens[0].relativeStep, 0);
    });

    blocTest<LudoBloc, LudoState>(
      'human single forced move is offered, then animated instead of jumping',
      build: () => buildBlocWithRoll(3, redIsAi: false, edit: oneRedTokenOut),
      act: (bloc) async {
        bloc.add(const LudoDiceRollRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const LudoDiceRollOverlayCompleted());
      },
      wait: const Duration(milliseconds: 400),
      expect: () => [
        isA<LudoActiveState>()
            .having((s) => s.isShowingRollOverlay, 'overlay', true)
            .having((s) => s.gameState.lastDiceRoll, 'roll not revealed yet', isNull),
        isA<LudoActiveState>()
            .having((s) => s.gameState.turnPhase, 'phase', TurnPhase.awaitingPawnSelection)
            .having((s) => s.gameState.validMoves.length, 'moves', 1)
            .having((s) => s.gameState.players[0].tokens[0].relativeStep, 'not moved yet', 0),
        isA<LudoActiveState>()
            .having((s) => s.animatingMove?.toRelativeStep, 'animating to', 3),
      ],
    );

    blocTest<LudoBloc, LudoState>(
      'bot single forced move goes through the animation path',
      build: () => buildBlocWithRoll(3, redIsAi: true, edit: oneRedTokenOut),
      act: (bloc) => bloc.add(const LudoDiceRollRequested()),
      wait: const Duration(milliseconds: 1500),
      verify: (bloc) {
        final s = bloc.state as LudoActiveState;
        expect(s.animatingMove?.pawnId, 'red_0');
        expect(s.animatingMove?.toRelativeStep, 3);
        // Engine hasn't applied it yet: the pawn moves only after the animation completes
        expect(s.gameState.players[0].tokens[0].relativeStep, 0);
      },
    );

    blocTest<LudoBloc, LudoState>(
      'a six with no legal moves reports no moves, not the three-sixes penalty',
      build: () => buildBlocWithRoll(6, redIsAi: false, edit: redStuckOnSix),
      act: (bloc) async {
        bloc.add(const LudoDiceRollRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const LudoDiceRollOverlayCompleted());
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        final s = bloc.state as LudoActiveState;
        final effect = s.sideEffect as LudoSnackbarEffect;
        expect(effect.message, contains('No moves available'));
        expect(s.gameState.activePlayerColor, PlayerColor.green);
        expect(s.gameState.consecutiveSixesCount, 0);
        expect(s.history.single.outcome, TurnOutcome.noMoves);
      },
    );

    blocTest<LudoBloc, LudoState>(
      'the penalty message follows the configured limit',
      build: () => buildBlocWithRoll(
        6,
        redIsAi: false,
        edit: (s) => s.copyWith(
          config: s.config.copyWith(consecutiveSixesLimit: 2),
          consecutiveSixesCount: 1,
        ),
      ),
      act: (bloc) async {
        bloc.add(const LudoDiceRollRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const LudoDiceRollOverlayCompleted());
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        final s = bloc.state as LudoActiveState;
        expect((s.sideEffect as LudoSnackbarEffect).message, startsWith('Two 6s penalty!'));
        expect(s.gameState.activePlayerColor, PlayerColor.green);
      },
    );

    blocTest<LudoBloc, LudoState>(
      'with no sixes limit, a sixth six in a row is no penalty',
      build: () => buildBlocWithRoll(
        6,
        redIsAi: false,
        edit: (s) => s.copyWith(
          config: s.config.copyWith(consecutiveSixesLimit: 0),
          consecutiveSixesCount: 5,
        ),
      ),
      act: (bloc) async {
        bloc.add(const LudoDiceRollRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const LudoDiceRollOverlayCompleted());
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        final s = bloc.state as LudoActiveState;
        expect(s.sideEffect, isNot(isA<LudoSnackbarEffect>()));
        expect(s.gameState.activePlayerColor, PlayerColor.red);
        expect(s.gameState.turnPhase, TurnPhase.awaitingPawnSelection);
        expect(s.history, isEmpty, reason: 'no penalty entry');
      },
    );

    blocTest<LudoBloc, LudoState>(
      'third consecutive six shows the penalty snackbar',
      build: () => buildBlocWithRoll(
        6,
        redIsAi: false,
        edit: (s) => s.copyWith(consecutiveSixesCount: 2),
      ),
      act: (bloc) async {
        bloc.add(const LudoDiceRollRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const LudoDiceRollOverlayCompleted());
      },
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        final s = bloc.state as LudoActiveState;
        final effect = s.sideEffect as LudoSnackbarEffect;
        expect(effect.message, contains('Three 6s penalty'));
        expect(s.gameState.activePlayerColor, PlayerColor.green);
        expect(s.history.single.outcome, TurnOutcome.sixesPenalty);
      },
    );
  });

  group('LudoBloc', () {
    test('initial state is LudoInitial', () {
      final bloc = buildBloc();
      expect(bloc.state, isA<LudoInitial>());
      bloc.close();
    });

    blocTest<LudoBloc, LudoState>(
      'emits LudoActiveState when LudoStarted is dispatched',
      build: buildBloc,
      act: (bloc) => bloc.add(const LudoStarted(
        aiConfig: {
          PlayerColor.red: false,
          PlayerColor.green: false,
          PlayerColor.yellow: false,
          PlayerColor.blue: false,
        },
      )),
      expect: () => [
        isA<LudoActiveState>()
            .having((s) => s.gameState.players.length, 'players count', 4)
            .having((s) => s.gameState.activePlayer.color, 'active player', PlayerColor.red)
            .having((s) => s.isShowingRollOverlay, 'overlay hidden', false),
      ],
    );

    blocTest<LudoBloc, LudoState>(
      'emits updated theme when LudoThemeChanged is dispatched',
      build: buildBloc,
      seed: () => LudoActiveState(
        gameState: engine.newGame(colors: const [PlayerColor.red, PlayerColor.green]),
      ),
      act: (bloc) => bloc.add(const LudoThemeChanged(BoardThemeType.classicWood)),
      expect: () => [
        isA<LudoActiveState>().having(
          (s) => s.themeType,
          'theme type',
          BoardThemeType.classicWood,
        ),
      ],
    );

    blocTest<LudoBloc, LudoState>(
      'emits rolling overlay true for human player on LudoDiceRollRequested',
      build: buildBloc,
      seed: () => LudoActiveState(
        gameState: engine.newGame(
          colors: const [PlayerColor.red, PlayerColor.green],
          aiConfig: const {PlayerColor.red: false, PlayerColor.green: true},
        ),
      ),
      act: (bloc) => bloc.add(const LudoDiceRollRequested()),
      expect: () => [
        isA<LudoActiveState>()
            .having((s) => s.isShowingRollOverlay, 'showing overlay', true)
            .having((s) => s.rollerPlayer?.color, 'roller color', PlayerColor.red),
      ],
    );
  });
}
