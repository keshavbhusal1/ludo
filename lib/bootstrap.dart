import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'engine/ai/ludo_ai_engine.dart';
import 'engine/ludo_game_controller.dart';
import 'features/ludo/data/datasources/ludo_local_data_source.dart';
import 'features/ludo/data/repositories/ludo_repository_impl.dart';
import 'features/ludo/domain/repositories/ludo_repository.dart';
import 'features/ludo/domain/usecases/clear_saved_game_use_case.dart';
import 'features/ludo/domain/usecases/execute_move_use_case.dart';
import 'features/ludo/domain/usecases/get_saved_game_use_case.dart';
import 'features/ludo/domain/usecases/roll_dice_use_case.dart';
import 'features/ludo/domain/usecases/save_game_use_case.dart';
import 'features/ludo/presentation/bloc/ludo_bloc.dart';
import 'models/player_color.dart';

/// Global service locator instance.
final sl = GetIt.instance;

/// Application bootstrap setting up DI singletons, screen orientations, and services.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (!sl.isRegistered<LudoLocalDataSource>()) {
    // Data Sources
    sl.registerLazySingleton<LudoLocalDataSource>(
      () => const LudoLocalDataSourceImpl(),
    );

    // Repositories
    sl.registerLazySingleton<LudoRepository>(
      () => LudoRepositoryImpl(localDataSource: sl()),
    );

    // Engine & Controllers
    sl.registerLazySingleton<LudoGameController>(
      () => LudoGameController.newGame(
        colors: const [
          PlayerColor.red,
          PlayerColor.green,
          PlayerColor.yellow,
          PlayerColor.blue,
        ],
        // The BLoC plays forced moves itself so they get animations and side effects.
        autoExecuteSingleMove: false,
      ),
    );
    sl.registerLazySingleton<LudoAiEngine>(
      () => LudoAiEngine(),
    );

    // Domain Use Cases
    sl.registerLazySingleton<RollDiceUseCase>(
      () => RollDiceUseCase(sl()),
    );
    sl.registerLazySingleton<ExecuteMoveUseCase>(
      () => ExecuteMoveUseCase(sl()),
    );
    sl.registerLazySingleton<GetSavedGameUseCase>(
      () => GetSavedGameUseCase(sl()),
    );
    sl.registerLazySingleton<SaveGameUseCase>(
      () => SaveGameUseCase(sl()),
    );
    sl.registerLazySingleton<ClearSavedGameUseCase>(
      () => ClearSavedGameUseCase(sl()),
    );

    // Presentation BLoC (Factory for fresh instances per match session)
    sl.registerFactory<LudoBloc>(
      () => LudoBloc(
        controller: sl(),
        rollDiceUseCase: sl(),
        executeMoveUseCase: sl(),
        getSavedGameUseCase: sl(),
        saveGameUseCase: sl(),
        clearSavedGameUseCase: sl(),
        aiEngine: sl(),
      ),
    );
  }
}
