import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/core/errors/failures.dart';
import 'package:ludo/engine/ludo_game_engine.dart';
import 'package:ludo/features/ludo/data/datasources/ludo_local_data_source.dart';
import 'package:ludo/features/ludo/data/repositories/ludo_repository_impl.dart';
import 'package:ludo/models/board_position.dart';
import 'package:ludo/models/game_config.dart';
import 'package:ludo/models/game_state.dart';
import 'package:ludo/models/history_entry.dart';
import 'package:ludo/models/player_color.dart';
import 'package:ludo/models/saved_match.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const engine = LudoEngine();
  final game = GameState.initial(
    colors: const [PlayerColor.red, PlayerColor.green],
    aiConfig: const {PlayerColor.green: true},
    gameId: 'saved_match',
  );

  /// Red has two tokens out, so a roll of 3 is a choice between them.
  GameState redChoosing() {
    final red = game.players[0];
    final tokens = List.of(red.tokens);
    tokens[0] = tokens[0].copyWith(
      position: const BoardPosition.track(trackIndex: 1, relativeStep: 0),
    );
    tokens[1] = tokens[1].copyWith(
      position: const BoardPosition.track(trackIndex: 11, relativeStep: 10),
    );
    return engine.rollDice(
      game.copyWith(players: [red.copyWith(tokens: tokens), game.players[1]]),
      3,
    );
  }

  HistoryEntry movedEntry(GameState choosing) => HistoryEntry(
        color: PlayerColor.red,
        playerName: 'Red',
        roll: 3,
        outcome: TurnOutcome.moved,
        move: choosing.validMoves.first,
      );

  Future<LudoLocalDataSourceImpl> dataSourceWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return LudoLocalDataSourceImpl(await SharedPreferences.getInstance());
  }

  test('returns null when nothing is saved', () async {
    final ds = await dataSourceWith({});
    expect(await ds.loadGame(), isNull);
  });

  test('save then load round-trips the match', () async {
    final ds = await dataSourceWith({});
    await ds.saveGame(SavedMatch(game: game));

    final loaded = await ds.loadGame();
    expect(loaded?.game.id, 'saved_match');
    expect(loaded?.game.players.map((p) => p.color), [PlayerColor.red, PlayerColor.green]);
    expect(loaded?.game.players[1].isAi, isTrue);
  });

  test('clear removes the save', () async {
    final ds = await dataSourceWith({});
    await ds.saveGame(SavedMatch(game: game));
    await ds.clearSavedGame();
    expect(await ds.loadGame(), isNull);
  });

  test('corrupt save surfaces as a StorageFailure instead of being swallowed', () async {
    final ds = await dataSourceWith({LudoLocalDataSourceImpl.autosaveKey: '{not json'});
    final repo = LudoRepositoryImpl(localDataSource: ds);

    final result = await repo.getSavedGame();
    expect(result.isLeft(), isTrue);
    result.fold((f) => expect(f, isA<StorageFailure>()), (_) {});
  });

  group('history and undo persistence', () {
    test('history and undo points survive a save/load round-trip', () async {
      final choosing = redChoosing();
      final played = engine.executeMove(choosing, choosing.validMoves.first);
      final match = SavedMatch(
        game: played,
        history: [movedEntry(choosing)],
        undoStack: [UndoPoint(state: choosing, historyLength: 0)],
      );

      final ds = await dataSourceWith({});
      await ds.saveGame(match);
      final loaded = (await ds.loadGame())!;

      expect(loaded.history.single.outcome, TurnOutcome.moved);
      expect(loaded.history.single.move?.pawnId, choosing.validMoves.first.pawnId);
      expect(loaded.history.single.description, 'rolled 3 — moved a token 3 spaces');
      expect(loaded.undoStack.single.historyLength, 0);
      expect(loaded.undoStack.single.state.validMoves, hasLength(2));
      expect(loaded.undoStack.single.state.validMoves.first.trajectory, isNotEmpty,
          reason: 'restored choices still need their animation paths');
      expect(loaded.game.players[0].tokens[0].relativeStep, 3);
    });

    test('a game sitting at its latest undo point loads as that same object', () async {
      // Undo relies on identity to know it is already at this choice
      final choosing = redChoosing();
      final match = SavedMatch(
        game: choosing,
        undoStack: [UndoPoint(state: choosing, historyLength: 0)],
      );

      final json = match.toJson();
      expect(json.containsKey('game'), isFalse, reason: 'stored once, not twice');

      final loaded = SavedMatch.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(identical(loaded.game, loaded.undoStack.last.state), isTrue);
    });

    test('only the most recent undo points are persisted', () {
      final choosing = redChoosing();
      final points = [
        for (var i = 0; i < 25; i++) UndoPoint(state: choosing, historyLength: i),
      ];
      final match = SavedMatch(game: game, undoStack: points);

      final loaded = SavedMatch.fromJson(
        jsonDecode(jsonEncode(match.toJson())) as Map<String, dynamic>,
      );
      expect(loaded.undoStack, hasLength(SavedMatch.maxPersistedUndoPoints));
      expect(loaded.undoStack.first.historyLength, 25 - SavedMatch.maxPersistedUndoPoints);
      expect(loaded.undoStack.last.historyLength, 24);
    });

    test('history moves are stored without their animation path', () {
      final choosing = redChoosing();
      final json = movedEntry(choosing).toJson();
      expect((json['move'] as Map).containsKey('trajectory'), isFalse);
    });

    test('a version 1 save (bare GameState) still loads, with empty history', () async {
      final ds = await dataSourceWith({
        LudoLocalDataSourceImpl.autosaveKey: jsonEncode(game.toJson()),
      });

      final loaded = (await ds.loadGame())!;
      expect(loaded.game.id, 'saved_match');
      expect(loaded.history, isEmpty);
      expect(loaded.undoStack, isEmpty);
    });

    test('pre-v3 saves load with the turn timer off (it was never enforced then)', () async {
      // Older code wrote timerConfig.enabled = true by default
      final legacyTimed = game.copyWith(
        config: game.config.copyWith(timerConfig: const TimerConfig(enabled: true)),
      );
      final choosing = redChoosing().copyWith(config: legacyTimed.config);
      final v2 = SavedMatch(
        game: choosing,
        undoStack: [UndoPoint(state: choosing, historyLength: 0)],
      ).toJson()
        ..['format'] = 2;

      final fromV2 = SavedMatch.fromJson(jsonDecode(jsonEncode(v2)) as Map<String, dynamic>);
      expect(fromV2.game.config.timerConfig.enabled, isFalse);
      expect(fromV2.undoStack.single.state.config.timerConfig.enabled, isFalse);
      expect(identical(fromV2.game, fromV2.undoStack.last.state), isTrue);

      final fromV1 = SavedMatch.fromJson(
        jsonDecode(jsonEncode(legacyTimed.toJson())) as Map<String, dynamic>,
      );
      expect(fromV1.game.config.timerConfig.enabled, isFalse);
    });

    test('current saves keep an enabled timer', () {
      final timed = game.copyWith(
        config: game.config.copyWith(timerConfig: const TimerConfig(enabled: true)),
      );
      final loaded = SavedMatch.fromJson(
        jsonDecode(jsonEncode(SavedMatch(game: timed).toJson())) as Map<String, dynamic>,
      );
      expect(loaded.game.config.timerConfig.enabled, isTrue);
    });

    test('a save from a newer app version is reported, not misread', () async {
      final ds = await dataSourceWith({
        LudoLocalDataSourceImpl.autosaveKey: jsonEncode({'format': 99}),
      });
      final result = await LudoRepositoryImpl(localDataSource: ds).getSavedGame();
      expect(result.isLeft(), isTrue);
    });
  });
}
