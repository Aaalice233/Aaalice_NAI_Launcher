import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/app_background_return.dart';

const _focusSwitch = [AppLifecycleState.inactive, AppLifecycleState.resumed];

const _minimizeAndRestore = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

const _androidBackground = [
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
  AppLifecycleState.hidden,
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

void main() {
  List<bool> feed(
    AppBackgroundReturnTracker tracker,
    List<AppLifecycleState> states,
  ) => [for (final state in states) tracker.returnedToView(state)];

  test('switching window focus is not a return from the background', () {
    final tracker = AppBackgroundReturnTracker();

    for (var round = 0; round < 3; round++) {
      expect(feed(tracker, _focusSwitch), everyElement(isFalse));
    }
  });

  test('a hidden or paused window reports one return once it is visible '
      'again, before it regains focus', () {
    for (final sequence in [_minimizeAndRestore, _androidBackground]) {
      final tracker = AppBackgroundReturnTracker();

      expect(feed(tracker, sequence), [
        for (var i = 0; i < sequence.length - 2; i++) isFalse,
        isTrue,
        isFalse,
      ]);
      expect(feed(tracker, _focusSwitch), everyElement(isFalse));
    }
  });
}
