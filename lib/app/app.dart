import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bootstrap.dart';
import '../features/ludo/presentation/bloc/ludo_bloc.dart';
import '../features/ludo/presentation/bloc/ludo_event.dart';
import '../features/ludo/presentation/screens/ludo_game_screen.dart';
import '../models/player_color.dart';
import 'theme/app_theme.dart';

/// Root application widget bootstrapping theme and the global feature BLoC provider.
class LudoApp extends StatelessWidget {
  final Map<PlayerColor, bool>? initialAiConfig;

  const LudoApp({super.key, this.initialAiConfig});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ludo Offline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: BlocProvider<LudoBloc>(
        create: (context) => sl<LudoBloc>()..add(LudoStarted(aiConfig: initialAiConfig)),
        child: const LudoGameScreen(),
      ),
    );
  }
}
