import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/bootstrap.dart';
import 'package:ludo/app/app.dart';
import 'package:ludo/models/player_color.dart';
import 'package:ludo/presentation/screens/ludo_game_screen.dart';
import 'package:ludo/presentation/widgets/board/ludo_board_widget.dart';
import 'package:ludo/presentation/widgets/dice/animated_dice_widget.dart';
import 'package:ludo/presentation/widgets/dice/full_screen_dice_roll_overlay.dart';
import 'package:ludo/presentation/widgets/hud/player_badge_widget.dart';

void main() {
  testWidgets('Ludo game screen loads board, 4 player badges, and single shared dice HUD',
      (WidgetTester tester) async {
    await bootstrap();

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
}
