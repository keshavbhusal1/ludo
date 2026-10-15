import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/models/game_rules.dart';
import 'package:ludo/models/player_color.dart';
import 'package:ludo/presentation/themes/board_theme.dart';
import 'package:ludo/presentation/widgets/dialogs/game_setup_dialog.dart';

/// A chip's label inside the option row with [rowKey] (several rows share labels like '3').
Finder chip(String rowKey, String label) =>
    find.descendant(of: find.byKey(Key(rowKey)), matching: find.text(label));

Color? colorOf(WidgetTester tester, Finder finder) => tester.widget<Text>(finder).style?.color;

void main() {
  testWidgets('game speed, timer, and sixes settings are preselected, changeable, and returned',
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
      expect(chip('strike-limit-options', label), findsOneWidget);
    }
    expect(colorOf(tester, chip('strike-limit-options', '3')), Colors.white,
        reason: 'default strike limit preselected');
    await tester.ensureVisible(chip('strike-limit-options', 'Never'));
    await tester.tap(chip('strike-limit-options', 'Never'));
    await tester.pump();

    // Sixes limit: always shown; the match's current value (2) is preselected
    expect(find.text('Sixes in a row before losing the turn'), findsOneWidget);
    for (final label in ['2', '3', '4', 'Off']) {
      expect(chip('sixes-limit-options', label), findsOneWidget);
    }
    expect(colorOf(tester, chip('sixes-limit-options', '2')), Colors.white);
    await tester.ensureVisible(chip('sixes-limit-options', '4'));
    await tester.tap(chip('sixes-limit-options', '4'));
    await tester.pump();
    expect(colorOf(tester, chip('sixes-limit-options', '4')), Colors.white);
    expect(colorOf(tester, chip('sixes-limit-options', '2')), isNot(Colors.white));

    await tester.ensureVisible(find.text('APPLY & START MATCH'));
    await tester.tap(find.text('APPLY & START MATCH'));
    await tester.pumpAndSettle();

    expect(result?.rules.gameSpeed, 2.0);
    expect(result?.rules.turnTimerEnabled, isTrue);
    expect(result?.rules.turnTimeLimitSeconds, 20);
    expect(result?.rules.turnTimerMaxStrikes, 0, reason: 'Never');
    expect(result?.rules.consecutiveSixesLimit, 4);
  });

  testWidgets('existing timer and sixes settings are preselected, even non-standard ones', (tester) async {
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
              consecutiveSixesLimit: 5,
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

    await tester.ensureVisible(chip('strike-limit-options', '4'));
    expect(colorOf(tester, chip('strike-limit-options', '4')), Colors.white);
    expect(chip('strike-limit-options', 'Never'), findsOneWidget);

    await tester.ensureVisible(chip('sixes-limit-options', '5'));
    expect(colorOf(tester, chip('sixes-limit-options', '5')), Colors.white);
    expect(chip('sixes-limit-options', 'Off'), findsOneWidget);
  });
}
