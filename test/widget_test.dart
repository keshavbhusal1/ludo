import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo/bootstrap.dart';
import 'package:ludo/core/services/haptics_service.dart';
import 'package:ludo/app/app.dart';
import 'package:ludo/features/ludo/data/datasources/ludo_local_data_source.dart';
import 'package:ludo/models/player_color.dart';
import 'package:ludo/features/ludo/presentation/screens/ludo_game_screen.dart';
import 'package:ludo/presentation/widgets/board/ludo_board_widget.dart';
import 'package:ludo/presentation/widgets/dice/animated_dice_widget.dart';
import 'package:ludo/presentation/widgets/dice/full_screen_dice_roll_overlay.dart';
import 'package:ludo/presentation/widgets/hud/move_history_sheet.dart';
import 'package:ludo/presentation/widgets/hud/player_badge_widget.dart';

import 'helpers/in_memory_local_data_source.dart';

void main() {
  // Runs outside testWidgets' fake-async zone: bootstrap awaits a real platform
  // channel reply (SystemChrome) that would never arrive inside it.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await bootstrap();
    sl.unregister<LudoLocalDataSource>();
    sl.registerLazySingleton<LudoLocalDataSource>(() => InMemoryLocalDataSource());
  });

  testWidgets('Ludo game screen loads board, 4 player badges, and single shared dice HUD',
      (WidgetTester tester) async {
    // Set a phone portrait surface size for predictable testing
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LudoApp(
      initialAiConfig: {
        PlayerColor.red: false,
        PlayerColor.green: false,
        PlayerColor.yellow: false,
        PlayerColor.blue: false,
      },
    ));
    // Pump frames to load initial layout
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify root screen and board
    expect(find.byType(LudoGameScreen), findsOneWidget);
    expect(find.byType(LudoBoardWidget), findsOneWidget);

    // Verify 4 compact corner player badges (replaces bulky rectangular stations)
    expect(find.byType(PlayerBadgeWidget), findsNWidgets(4));

    // Verify ONE single shared dice in the bottom HUD
    expect(find.byType(AnimatedDiceWidget), findsOneWidget);

    // Verify ROLL button is present for active human player
    expect(find.text('ROLL'), findsOneWidget);

    // Tap ROLL button to trigger the full-screen dice roll overlay
    await tester.tap(find.text('ROLL'));
    await tester.pump(); // Start overlay animation

    // Verify the FullScreenDiceRollOverlay appears and covers the screen
    expect(find.byType(FullScreenDiceRollOverlay), findsOneWidget);

    // Advance time for the roll animation and settling delay (750ms roll + 250ms settle)
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    // After roll finishes, overlay disappears
    expect(find.byType(FullScreenDiceRollOverlay), findsNothing);
  });

  testWidgets('Undo starts disabled and the history sheet opens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LudoApp(
      initialAiConfig: {
        PlayerColor.red: false,
        PlayerColor.green: false,
        PlayerColor.yellow: false,
        PlayerColor.blue: false,
      },
    ));
    await tester.pump();

    final undo = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo));
    expect(undo.onPressed, isNull);

    await tester.tap(find.byTooltip('Move history'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet slide-in

    expect(find.byType(MoveHistorySheet), findsOneWidget);
    expect(find.text('No moves yet'), findsOneWidget);
  });

  testWidgets('the haptics menu item toggles, updates, and remembers the choice', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => HapticsService.isEnabled = true);

    await tester.pumpWidget(const LudoApp());
    await tester.pump();
    expect(HapticsService.isEnabled, isTrue);

    Future<void> chooseFromMenu(String label) async {
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await chooseFromMenu('Turn haptics off');
    expect(tester.takeException(), isNull, reason: 'setState must not get a Future');
    expect(HapticsService.isEnabled, isFalse);
    expect(find.text('Haptics Off'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(HapticsService.enabledKey), isFalse, reason: 'saved');

    await chooseFromMenu('Turn haptics on');
    expect(tester.takeException(), isNull);
    expect(HapticsService.isEnabled, isTrue);
    expect(prefs.getBool(HapticsService.enabledKey), isTrue);
  });

  testWidgets('small phone: no overflow, full title, one prompt, badges on the board corners',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280); // 360 x 640 logical
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LudoApp());
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'no layout overflow');

    expect(find.text('Ludo · Classic'), findsOneWidget);
    expect(find.text("Red's turn"), findsOneWidget);
    expect(find.textContaining('Tap the dice to roll'), findsOneWidget, reason: 'said once, not twice');

    final board = tester.getRect(find.byType(LudoBoardWidget));
    final rows = find.byType(PlayerBadgeRow);
    expect(rows, findsNWidgets(2));
    for (final row in rows.evaluate()) {
      final rect = tester.getRect(find.byWidget(row.widget));
      expect(rect.width, closeTo(board.width, 1), reason: 'badge rows span the board');
      expect(rect.left, closeTo(board.left, 1));
    }
  });
}
