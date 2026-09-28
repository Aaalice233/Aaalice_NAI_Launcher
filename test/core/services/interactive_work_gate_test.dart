import 'dart:async';

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

  testWidgets('idle work waits while the desktop window is unfocused', (
    tester,
  ) async {
    final gate = InteractiveWorkGate.forTesting();
    var ran = false;
    gate.setWindowFocused(false);

    final operation = gate.runWhenIdle(
      quietPeriod: Duration.zero,
      pollInterval: const Duration(milliseconds: 10),
      action: () async => ran = true,
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(ran, isFalse);

    gate.setWindowFocused(true);
    await tester.pump(const Duration(milliseconds: 20));
    await operation;
    expect(ran, isTrue);
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
