import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/models/player.dart';
import 'package:ludo/models/player_color.dart';
import 'package:ludo/presentation/widgets/dialogs/reclaim_seat_dialog.dart';
import 'package:ludo/presentation/widgets/hud/player_badge_widget.dart';

void main() {
  Player human(PlayerColor c) => Player.initial(color: c);
  Player bot(PlayerColor c) => Player.initial(color: c, isAi: true);
  Player takenOver(PlayerColor c) =>
      Player.initial(color: c).copyWith(strikes: 3, isDisconnected: true);

  Widget host(Widget child, {double width = 400}) => MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: width, child: child)),
        ),
      );

  testWidgets('a human seat has no bot marker', (tester) async {
    await tester.pumpWidget(host(PlayerBadgeWidget(player: human(PlayerColor.red), isActive: false)));
    expect(find.byIcon(Icons.smart_toy), findsNothing);
    expect(find.text('AUTO'), findsNothing);
  });

  testWidgets('a bot seat shows the robot icon but no AUTO tag', (tester) async {
    await tester.pumpWidget(host(PlayerBadgeWidget(player: bot(PlayerColor.red), isActive: false)));
    expect(find.text('Bot Red'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy), findsOneWidget);
    expect(find.text('AUTO'), findsNothing);
    expect(find.bySemanticsLabel('Bot Red, bot, 0 of 4 tokens home'), findsOneWidget);
  });

  testWidgets('a taken-over human seat shows the AUTO tag and why', (tester) async {
    await tester.pumpWidget(host(PlayerBadgeWidget(player: takenOver(PlayerColor.red), isActive: true)));
    expect(find.text('Red'), findsOneWidget);
    expect(find.text('AUTO'), findsOneWidget);
    expect(
      find.byTooltip('Timed out too many times — a bot is playing this seat'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Red, played by a bot after timing out, 0 of 4 tokens home'),
      findsOneWidget,
    );
  });

  testWidgets('worst-case badge pairs fit a 360-wide phone row without overflow', (tester) async {
    // The screen puts two badges per row with 16px side padding: 328px usable.
    // The test font draws every glyph as a full square, far wider than real
    // text, so this is a pessimistic check that names shorten instead of
    // overflowing.
    Widget row(Player left, Player right) => PlayerBadgeRow(
          left: left,
          right: right,
          activeColor: left.color,
        );

    final pairs = [
      (bot(PlayerColor.blue), takenOver(PlayerColor.yellow)),
      (takenOver(PlayerColor.blue), bot(PlayerColor.yellow)),
      (bot(PlayerColor.red), takenOver(PlayerColor.green)),
      (takenOver(PlayerColor.red), bot(PlayerColor.green)),
    ];
    for (final (left, right) in pairs) {
      await tester.pumpWidget(host(row(left, right), width: 328));
      expect(tester.takeException(), isNull, reason: '${left.name} + ${right.name} overflowed');
      // Markers survive shortening
      expect(find.text('AUTO'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
    }
  });

  testWidgets('an absent seat leaves its corner empty', (tester) async {
    await tester.pumpWidget(host(
      PlayerBadgeRow(left: human(PlayerColor.red), right: null, activeColor: PlayerColor.red),
      width: 328,
    ));
    expect(find.byType(PlayerBadgeWidget), findsOneWidget);
  });

  group('reclaiming', () {
    testWidgets('tapping a taken-over badge asks to reclaim that seat', (tester) async {
      final tapped = <PlayerColor>[];
      await tester.pumpWidget(host(PlayerBadgeRow(
        left: human(PlayerColor.red),
        right: takenOver(PlayerColor.green),
        activeColor: PlayerColor.red,
        onReclaim: tapped.add,
      )));

      expect(
        find.byTooltip('A bot is playing this seat after timeouts — tap to take it back'),
        findsOneWidget,
      );
      await tester.tap(find.text('AUTO'));
      await tester.tap(find.text('Red')); // human badge: not reclaimable
      expect(tapped, [PlayerColor.green]);
    });

    testWidgets('bot seats are not reclaimable', (tester) async {
      final tapped = <PlayerColor>[];
      await tester.pumpWidget(host(PlayerBadgeRow(
        left: bot(PlayerColor.red),
        right: null,
        activeColor: PlayerColor.red,
        onReclaim: tapped.add,
      )));
      await tester.tap(find.text('Bot Red'));
      expect(tapped, isEmpty);
    });

    testWidgets('screen readers get a button with a "take back" action', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(PlayerBadgeWidget(
        player: takenOver(PlayerColor.red),
        isActive: false,
        onReclaim: () {},
      )));
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Red, played by a bot after timing out, 0 of 4 tokens home'),
        ),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });

  group('confirm dialog', () {
    Future<bool?> openAndAnswer(WidgetTester tester, String button) async {
      bool? answer;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                answer = await confirmReclaimSeat(context, takenOver(PlayerColor.red)),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text("Take back Red's seat?"), findsOneWidget);
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      return answer;
    }

    testWidgets('Take back confirms', (tester) async {
      expect(await openAndAnswer(tester, 'Take back'), isTrue);
    });

    testWidgets('Cancel declines', (tester) async {
      expect(await openAndAnswer(tester, 'Cancel'), isFalse);
    });
  });
}
