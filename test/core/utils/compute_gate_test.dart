import 'dart:async';
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

    test('keeps default concurrency within processor-safe bounds', () {
      expect(ComputeGate.defaultMaxConcurrentTasks(processorCount: 1), 1);
      expect(ComputeGate.defaultMaxConcurrentTasks(processorCount: 2), 1);
      expect(ComputeGate.defaultMaxConcurrentTasks(processorCount: 8), 3);
    });
  });
}
