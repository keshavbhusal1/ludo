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

    // Time per turn and the strike limit only appear once the timer is on
    expect(find.text('Time per turn'), findsNothing);
    expect(find.text('Timeouts before a bot takes over'), findsNothing);
    await tester.ensureVisible(find.text('Turn timer'));
    await tester.tap(find.text('Turn timer'));
    await tester.pump();

    expect(find.text('Time per turn'), findsOneWidget);
    for (final label in ['8 s', '12 s', '20 s', '30 s']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.widget<Text>(find.text('12 s')).style?.color, Colors.white,
        reason: 'default limit preselected');
    await tester.ensureVisible(find.text('20 s'));
    await tester.tap(find.text('20 s'));
    await tester.pump();

    expect(find.text('Timeouts before a bot takes over'), findsOneWidget);
    for (final label in ['1', '3', '5', 'Never']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.widget<Text>(find.text('3')).style?.color, Colors.white,
        reason: 'default strike limit preselected');
    await tester.ensureVisible(find.text('Never'));
    await tester.tap(find.text('Never'));
    await tester.pump();

    await tester.ensureVisible(find.text('APPLY & START MATCH'));
    await tester.tap(find.text('APPLY & START MATCH'));
    await tester.pumpAndSettle();

    expect(result?.rules.gameSpeed, 2.0);
    expect(result?.rules.turnTimerEnabled, isTrue);
    expect(result?.rules.turnTimeLimitSeconds, 20);
    expect(result?.rules.turnTimerMaxStrikes, 0, reason: 'Never');
    expect(result?.rules.consecutiveSixesLimit, 2,
        reason: 'settings the dialog does not show must be kept, not reset');
  });

  testWidgets('existing timer settings are preselected, even non-standard ones', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: GameSetupDialog(
          initialConfig: GameSetupResult(
            colors: [PlayerColor.red, PlayerColor.green],
            aiConfig: {PlayerColor.red: false, PlayerColor.green: true},
            rules: GameRules(
              turnTimerEnabled: true,
              turnTimeLimitSeconds: 45,
              turnTimerMaxStrikes: 4,
            ),
            themeType: BoardThemeType.darkModern,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('45 s'));
    expect(tester.widget<Text>(find.text('45 s')).style?.color, Colors.white);
    expect(find.text('30 s'), findsOneWidget, reason: 'standard options still offered');

    await tester.ensureVisible(find.text('4'));
    expect(tester.widget<Text>(find.text('4')).style?.color, Colors.white);
    expect(find.text('Never'), findsOneWidget);
  });
}
