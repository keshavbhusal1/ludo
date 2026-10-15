import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/presentation/widgets/hud/turn_countdown.dart';

void main() {
  const warnRed = Color(0xFFF87171);
  const normal = Color(0xFF43A047);

  test('the warning covers the last third of the turn', () {
    int warnFrom(int secs) => TurnCountdown.warnFromSeconds(Duration(seconds: secs));
    expect(warnFrom(8), 3);
    expect(warnFrom(12), 4, reason: 'unchanged for the default limit');
    expect(warnFrom(20), 7);
    expect(warnFrom(30), 10);
    expect(warnFrom(1), 1, reason: 'never below 1 s');
  });

  /// The chip's text color with [secondsLeft] remaining of a [limitSeconds] turn.
  Future<Color?> chipColor(WidgetTester tester, {required int limitSeconds, required int secondsLeft}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TurnCountdown(
          // A little under the whole second so the display reads exactly secondsLeft
          deadline: DateTime.now().add(Duration(milliseconds: secondsLeft * 1000 - 300)),
          limit: Duration(seconds: limitSeconds),
          color: normal,
        ),
      ),
    ));
    final color = tester.widget<Text>(find.text('${secondsLeft}s')).style?.color;
    await tester.pumpWidget(const SizedBox()); // dispose the ticker
    return color;
  }

  testWidgets('short limit: 4 s left of 8 is not yet a warning, 3 s is', (tester) async {
    expect(await chipColor(tester, limitSeconds: 8, secondsLeft: 4), normal);
    expect(await chipColor(tester, limitSeconds: 8, secondsLeft: 3), warnRed);
  });

  testWidgets('long limit: the warning starts at 10 s left of 30', (tester) async {
    expect(await chipColor(tester, limitSeconds: 30, secondsLeft: 11), normal);
    expect(await chipColor(tester, limitSeconds: 30, secondsLeft: 10), warnRed);
  });

  testWidgets('default limit keeps the warning at 4 s', (tester) async {
    expect(await chipColor(tester, limitSeconds: 12, secondsLeft: 5), normal);
    expect(await chipColor(tester, limitSeconds: 12, secondsLeft: 4), warnRed);
  });
}
