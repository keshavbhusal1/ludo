import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/models/game_rules.dart';
import 'package:ludo/models/player_color.dart';
import 'package:ludo/presentation/themes/board_theme.dart';
import 'package:ludo/presentation/widgets/dialogs/game_setup_dialog.dart';

void main() {
  testWidgets('game speed is preselected, changeable, and returned with the rules',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    GameSetupResult? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showDialog<GameSetupResult>(
              context: context,
              builder: (_) => const GameSetupDialog(
                initialConfig: GameSetupResult(
                  colors: [PlayerColor.red, PlayerColor.green],
                  aiConfig: {PlayerColor.red: false, PlayerColor.green: true},
                  rules: GameRules(gameSpeed: 1.5, consecutiveSixesLimit: 2),
                  themeType: BoardThemeType.darkModern,
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Game Speed'), findsOneWidget);
    for (final label in ['1×', '1.5×', '2×']) {
      expect(find.text(label), findsOneWidget);
    }
    // Current speed is highlighted (selected chips use white text)
    expect(tester.widget<Text>(find.text('1.5×')).style?.color, Colors.white);

    await tester.ensureVisible(find.text('2×'));
    await tester.tap(find.text('2×'));
    await tester.pump();
    expect(tester.widget<Text>(find.text('2×')).style?.color, Colors.white);
    expect(tester.widget<Text>(find.text('1.5×')).style?.color, isNot(Colors.white));

    await tester.ensureVisible(find.text('Turn timer (12 s)'));
    await tester.tap(find.text('Turn timer (12 s)'));
    await tester.pump();

    await tester.ensureVisible(find.text('APPLY & START MATCH'));
    await tester.tap(find.text('APPLY & START MATCH'));
    await tester.pumpAndSettle();

    expect(result?.rules.gameSpeed, 2.0);
    expect(result?.rules.turnTimerEnabled, isTrue);
    expect(result?.rules.consecutiveSixesLimit, 2,
        reason: 'settings the dialog does not show must be kept, not reset');
  });
}
