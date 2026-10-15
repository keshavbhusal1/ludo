import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/engine/ai/ludo_ai_engine.dart';
import 'package:ludo/engine/ludo_game_controller.dart';
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
import 'package:ludo/models/player_color.dart';
import 'package:ludo/presentation/themes/board_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LudoGameController controller;
  late LudoRepositoryImpl repository;
  late RollDiceUseCase rollDiceUseCase;
  late ExecuteMoveUseCase executeMoveUseCase;
  late GetSavedGameUseCase getSavedGameUseCase;
  late SaveGameUseCase saveGameUseCase;
  late ClearSavedGameUseCase clearSavedGameUseCase;
  late LudoAiEngine aiEngine;

  setUp(() {
    controller = LudoGameController.newGame(
      colors: const [
        PlayerColor.red,
        PlayerColor.green,
        PlayerColor.yellow,
        PlayerColor.blue,
      ],
    );
    repository = const LudoRepositoryImpl(localDataSource: LudoLocalDataSourceImpl());
    rollDiceUseCase = RollDiceUseCase(controller);
    executeMoveUseCase = ExecuteMoveUseCase(controller);
    getSavedGameUseCase = GetSavedGameUseCase(repository);
    saveGameUseCase = SaveGameUseCase(repository);
    clearSavedGameUseCase = ClearSavedGameUseCase(repository);
    aiEngine = LudoAiEngine();
  });

  LudoBloc buildBloc() => LudoBloc(
        controller: controller,
        rollDiceUseCase: rollDiceUseCase,
        executeMoveUseCase: executeMoveUseCase,
        getSavedGameUseCase: getSavedGameUseCase,
        saveGameUseCase: saveGameUseCase,
        clearSavedGameUseCase: clearSavedGameUseCase,
        aiEngine: aiEngine,
      );

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
      seed: () {
        controller.startNewGame(colors: const [PlayerColor.red, PlayerColor.green]);
        return LudoActiveState(gameState: controller.state);
      },
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
      seed: () {
        controller.startNewGame(
          colors: const [PlayerColor.red, PlayerColor.green],
          aiConfig: const {PlayerColor.red: false, PlayerColor.green: true},
        );
        return LudoActiveState(gameState: controller.state);
      },
      act: (bloc) => bloc.add(const LudoDiceRollRequested()),
      expect: () => [
        isA<LudoActiveState>()
            .having((s) => s.isShowingRollOverlay, 'showing overlay', true)
            .having((s) => s.rollerPlayer?.color, 'roller color', PlayerColor.red),
      ],
    );
  });
}
