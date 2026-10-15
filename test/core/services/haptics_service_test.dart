import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo/core/services/haptics_service.dart';
import 'package:ludo/models/board_position.dart';
import 'package:ludo/models/move.dart';
import 'package:ludo/models/player_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// HapticFeedback types sent over the platform channel, e.g. 'HapticFeedbackType.heavyImpact'.
  late List<Object?> sent;

  setUp(() {
    sent = [];
    HapticsService.isEnabled = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') sent.add(call.arguments);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Move move({bool capture = false, bool home = false}) => Move(
        tokenId: 'red_0',
        playerColor: PlayerColor.red,
        diceRoll: 3,
        fromPosition: const BoardPosition.track(trackIndex: 1, relativeStep: 0),
        toPosition: home
            ? const BoardPosition.goal()
            : const BoardPosition.track(trackIndex: 4, relativeStep: 3),
        fromRelativeStep: home ? 53 : 0,
        toRelativeStep: home ? 56 : 3,
        isCapture: capture,
        capturedTokenId: capture ? 'green_0' : null,
        isReachingHome: home,
      );

  test('a capture landing gives a heavy impact', () async {
    HapticsService.moveLanded(move(capture: true));
    await pumpEventQueue();
    expect(sent, ['HapticFeedbackType.heavyImpact']);
  });

  test('a token reaching home gives a medium impact', () async {
    HapticsService.moveLanded(move(home: true));
    await pumpEventQueue();
    expect(sent, ['HapticFeedbackType.mediumImpact']);
  });

  test('an ordinary move adds nothing beyond its hop', () async {
    HapticsService.moveLanded(move());
    await pumpEventQueue();
    expect(sent, isEmpty);
  });

  test('nothing fires while haptics are switched off', () async {
    HapticsService.isEnabled = false;
    HapticsService.moveLanded(move(capture: true));
    HapticsService.moveLanded(move(home: true));
    await pumpEventQueue();
    expect(sent, isEmpty);
  });

  group('saved setting', () {
    test('defaults to on when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      HapticsService.isEnabled = false;
      HapticsService.loadFrom(await SharedPreferences.getInstance());
      expect(HapticsService.isEnabled, isTrue);
    });

    test('switching off is remembered on the next launch', () async {
      SharedPreferences.setMockInitialValues({});
      HapticsService.loadFrom(await SharedPreferences.getInstance());
      await HapticsService.setEnabled(false);

      // "Relaunch": reset the in-memory flag and reload from storage
      HapticsService.isEnabled = true;
      HapticsService.loadFrom(await SharedPreferences.getInstance());
      expect(HapticsService.isEnabled, isFalse);

      await HapticsService.setEnabled(true);
      HapticsService.loadFrom(await SharedPreferences.getInstance());
      expect(HapticsService.isEnabled, isTrue);
    });
  });
}
