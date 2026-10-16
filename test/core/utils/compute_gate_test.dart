import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';

void main() {
  group('ComputeGate', () {
    test('limits concurrent work', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      var activeTasks = 0;
      var maxActiveTasks = 0;

      final Future<void> first = gate.run(() async {
        activeTasks++;
        maxActiveTasks =
            activeTasks > maxActiveTasks ? activeTasks : maxActiveTasks;
        firstStarted.complete();
        await releaseFirst.future;
        activeTasks--;
      });

      await firstStarted.future;

      final Future<void> second = gate.run(() async {
        activeTasks++;
        maxActiveTasks =
            activeTasks > maxActiveTasks ? activeTasks : maxActiveTasks;
        activeTasks--;
      });

      await Future<void>.delayed(Duration.zero);
      expect(maxActiveTasks, 1);

      releaseFirst.complete();
      await Future.wait([first, second]);

      expect(maxActiveTasks, 1);
    });

    test('names the isolate it runs work in', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);

      final name = await gate.runIsolate(
        () => Isolate.current.debugName,
        debugName: 'compute-gate-probe',
      );

      expect(name, 'compute-gate-probe');
    });

    test('time limits ignore the time spent waiting for a permit', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
      final occupied = gate.run(
        () => Future<void>.delayed(const Duration(milliseconds: 1500)),
      );

      final value = await gate.runCompute(
        _echo,
        7,
        timeLimit: const Duration(milliseconds: 1000),
      );

      expect(value, 7);
      await occupied;
    });

    test('a timed out compute returns its permit right away', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
      final clock = Stopwatch()..start();

      await expectLater(
        gate.runCompute(
          _sleepThenEcho,
          800,
          timeLimit: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await gate.run(() {});

      expect(clock.elapsed, lessThan(const Duration(milliseconds: 700)));
      // compute 无法中止，等后台 isolate 自行结束再离开用例
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });

    test('keeps default concurrency within processor-safe bounds', () {
      expect(ComputeGate.defaultMaxConcurrentTasks(processorCount: 1), 1);
      expect(ComputeGate.defaultMaxConcurrentTasks(processorCount: 2), 1);
      expect(ComputeGate.defaultMaxConcurrentTasks(processorCount: 8), 3);
    });
  });
}

int _echo(int value) => value;

int _sleepThenEcho(int milliseconds) {
  sleep(Duration(milliseconds: milliseconds));
  return milliseconds;
}
