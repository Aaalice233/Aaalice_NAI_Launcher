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

  test('reports leaving the screen once and returning once', () {
    final tracker = AppBackgroundReturnTracker();

    expect(
      [for (final state in _androidBackground) tracker.observe(state)],
      [
        AppVisibilityChange.unchanged,
        AppVisibilityChange.leftView,
        AppVisibilityChange.unchanged,
        AppVisibilityChange.unchanged,
        AppVisibilityChange.returnedToView,
        AppVisibilityChange.unchanged,
      ],
    );
    expect(tracker.isVisible, isTrue);
  });

  test('a tracker created while hidden reports the first visible state as a '
      'return', () {
    final tracker = AppBackgroundReturnTracker(
      initialState: AppLifecycleState.hidden,
    );

    expect(tracker.isVisible, isFalse);
    expect(
      tracker.observe(AppLifecycleState.paused),
      AppVisibilityChange.unchanged,
    );
    expect(
      tracker.observe(AppLifecycleState.inactive),
      AppVisibilityChange.returnedToView,
    );
  });

  testWidgets('the listener only calls back after the window left the screen', (
    tester,
  ) async {
    var returns = 0;
    final listener = AppBackgroundReturnListener(onReturn: () => returns++);
    addTearDown(listener.dispose);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );

    void enter(List<AppLifecycleState> states) {
      for (final state in states) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    }

    enter(_focusSwitch);
    enter(_focusSwitch);
    expect(returns, 0);

    enter(_minimizeAndRestore);
    expect(returns, 1);

    enter(_focusSwitch);
    expect(returns, 1);
  });

  testWidgets('a listener mounted while hidden reports the first return', (
    tester,
  ) async {
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    var returns = 0;
    final listener = AppBackgroundReturnListener(onReturn: () => returns++);
    addTearDown(() {
      listener.dispose();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(returns, 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(returns, 1);
  });
}
