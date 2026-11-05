import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/interactive_work_gate.dart';

void main() {
  testWidgets('idle work is serialized in registration order', (tester) async {
    final gate = InteractiveWorkGate.forTesting();
    final firstRelease = Completer<void>();
    final events = <String>[];

    final first = gate.runWhenIdle(
      quietPeriod: Duration.zero,
      action: () async {
        events.add('first-start');
        await firstRelease.future;
        events.add('first-end');
      },
    );
    final second = gate.runWhenIdle(
      quietPeriod: Duration.zero,
      action: () async {
        events.add('second');
      },
    );

    await tester.pump();
    expect(events, ['first-start']);

    firstRelease.complete();
    await first;
    await second;
    expect(events, ['first-start', 'first-end', 'second']);
  });

  testWidgets('higher priority bypasses work registered first', (tester) async {
    final gate = InteractiveWorkGate.forTesting();
    final events = <String>[];
    final maintenance = gate.runWhenIdle(
      quietPeriod: Duration.zero,
      priority: InteractiveWorkPriority.maintenance,
      action: () async => events.add('maintenance'),
    );
    final visible = gate.runWhenIdle(
      quietPeriod: Duration.zero,
      priority: InteractiveWorkPriority.userVisible,
      action: () async => events.add('visible'),
    );

    await tester.pump();
    await visible;
    await maintenance;
    expect(events, ['visible', 'maintenance']);
  });

  testWidgets('each task keeps its own quiet period', (tester) async {
    final gate = InteractiveWorkGate.forTesting();
    final events = <String>[];

    await tester.runAsync(() async {
      gate.markInteraction();
      final longQuiet = gate.runWhenIdle(
        quietPeriod: const Duration(milliseconds: 80),
        priority: InteractiveWorkPriority.userVisible,
        action: () async => events.add('long'),
      );
      final ready = gate.runWhenIdle(
        quietPeriod: Duration.zero,
        priority: InteractiveWorkPriority.maintenance,
        action: () async => events.add('ready'),
      );

      await ready;
      expect(events, ['ready']);
      await longQuiet;
    });
    expect(events, ['ready', 'long']);
  });

  group('a visible window without focus', () {
    tearDown(() {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
    });

    testWidgets('admits work despite recent interaction and animations', (
      tester,
    ) async {
      final gate = InteractiveWorkGate.forTesting();
      final events = <String>[];
      final animation = Ticker((_) {})..start();
      gate.markInteraction();
      unawaited(
        gate.runWhenIdle(
          pollInterval: const Duration(milliseconds: 10),
          priority: InteractiveWorkPriority.userVisible,
          action: () async => events.add('ordinary'),
        ),
      );
      unawaited(
        gate.runWhenIdle(
          pollInterval: const Duration(milliseconds: 10),
          priority: InteractiveWorkPriority.maintenance,
          action: () async => events.add('maintenance'),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      gate.handleLifecycleStateChanged(AppLifecycleState.inactive);
      gate.setWindowFocused(false);
      await tester.pump(const Duration(milliseconds: 50));

      expect(events, ['ordinary', 'maintenance']);
      animation.dispose();
    });

    testWidgets('still waits out input the window itself receives', (
      tester,
    ) async {
      final gate = InteractiveWorkGate.forTesting();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      gate.setWindowFocused(false);

      await tester.runAsync(() async {
        var ran = false;
        // Windows scrolls an inactive window under the cursor.
        gate.markInteraction();
        final stopwatch = Stopwatch()..start();
        final operation = gate.runWhenIdle(
          quietPeriod: const Duration(milliseconds: 80),
          pollInterval: const Duration(milliseconds: 10),
          priority: InteractiveWorkPriority.maintenance,
          action: () async => ran = true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ran, isFalse);

        await operation;
        expect(stopwatch.elapsed, greaterThanOrEqualTo(_minimumDelayFloor));
      });
    });

    testWidgets('still waits for the minimum delay', (tester) async {
      final gate = InteractiveWorkGate.forTesting();
      var ran = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      gate.setWindowFocused(false);

      await tester.runAsync(() async {
        final stopwatch = Stopwatch()..start();
        await gate.runWhenIdle(
          minimumDelay: const Duration(milliseconds: 80),
          pollInterval: const Duration(milliseconds: 10),
          action: () async => ran = true,
        );
        expect(stopwatch.elapsed, greaterThanOrEqualTo(_minimumDelayFloor));
      });
      expect(ran, isTrue);
    });

    testWidgets('still waits while the window is hidden', (tester) async {
      final gate = InteractiveWorkGate.forTesting();
      var ran = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);

      final operation = gate.runWhenIdle(
        quietPeriod: Duration.zero,
        pollInterval: const Duration(milliseconds: 10),
        action: () async => ran = true,
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(ran, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 20));
      await operation;
      expect(ran, isTrue);
    });
  });

  group('returning to the window', () {
    tearDown(() {
      WidgetsBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
    });

    void enter(
      WidgetTester tester,
      InteractiveWorkGate gate,
      List<AppLifecycleState> states,
    ) {
      for (final state in states) {
        tester.binding.handleAppLifecycleStateChanged(state);
        gate.handleLifecycleStateChanged(state);
      }
    }

    testWidgets('regaining focus is not an interaction', (tester) async {
      final gate = InteractiveWorkGate.forTesting();
      var ran = false;
      enter(tester, gate, [AppLifecycleState.inactive]);
      gate.setWindowFocused(false);

      gate.setWindowFocused(true);
      enter(tester, gate, [AppLifecycleState.resumed]);
      unawaited(
        gate.runWhenIdle(
          pollInterval: const Duration(milliseconds: 10),
          action: () async => ran = true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(ran, isTrue);
    });

    testWidgets('coming back from the background defers work like an '
        'interaction', (tester) async {
      final gate = InteractiveWorkGate.forTesting();
      enter(tester, gate, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);

      await tester.runAsync(() async {
        final stopwatch = Stopwatch()..start();
        await gate.runWhenIdle(
          quietPeriod: const Duration(milliseconds: 80),
          pollInterval: const Duration(milliseconds: 10),
          action: () async {},
        );
        expect(stopwatch.elapsed, greaterThanOrEqualTo(_minimumDelayFloor));
      });
    });

    testWidgets('work queued while hidden waits out the return even before '
        'focus comes back', (tester) async {
      final gate = InteractiveWorkGate.forTesting();
      enter(tester, gate, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]);

      await tester.runAsync(() async {
        var ran = false;
        final operation = gate.runWhenIdle(
          quietPeriod: const Duration(milliseconds: 80),
          pollInterval: const Duration(milliseconds: 10),
          priority: InteractiveWorkPriority.maintenance,
          action: () async => ran = true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ran, isFalse);

        // The engine reports the window shown before it reports focus.
        enter(tester, gate, [AppLifecycleState.inactive]);
        final stopwatch = Stopwatch()..start();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(ran, isFalse);

        await operation;
        expect(stopwatch.elapsed, greaterThanOrEqualTo(_minimumDelayFloor));
      });
    });
  });

  testWidgets('idle work waits while the application is backgrounded', (
    tester,
  ) async {
    final gate = InteractiveWorkGate.forTesting();
    var ran = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    final operation = gate.runWhenIdle(
      quietPeriod: Duration.zero,
      pollInterval: const Duration(milliseconds: 10),
      action: () async => ran = true,
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(ran, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 20));
    await operation;
    expect(ran, isTrue);
  });
}

// Timer granularity on Windows can fire a few milliseconds early.
const _minimumDelayFloor = Duration(milliseconds: 60);
