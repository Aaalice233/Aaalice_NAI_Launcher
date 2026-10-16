import 'dart:async';
import 'dart:isolate';

import 'package:fake_async/fake_async.dart';
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

    test('a time limit starts once the permit is granted', () {
      fakeAsync((async) {
        final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
        final holder = Completer<void>();
        gate.run(() => holder.future);
        final task = Completer<int>();
        Object? outcome;
        gate
            .run(() => task.future, timeLimit: const Duration(seconds: 1))
            .then<void>(
              (value) => outcome = value,
              onError: (Object e) => outcome = e,
            );

        async.elapse(const Duration(seconds: 5));
        expect(outcome, isNull);
        expect(gate.debugQueuedTasks, 1);
        holder.complete();
        async.elapse(const Duration(milliseconds: 999));
        expect(outcome, isNull);

        task.complete(7);
        async.flushMicrotasks();
        expect(outcome, 7);
      });
    });

    test('a timed out task returns its permit while it keeps running', () {
      fakeAsync((async) {
        final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);
        final stuck = Completer<void>();
        Object? error;
        gate
            .run(() => stuck.future, timeLimit: const Duration(seconds: 1))
            .catchError((Object e) => error = e);
        var next = false;
        gate.run(() => next = true);

        async.elapse(const Duration(seconds: 1));

        expect(error, isA<TimeoutException>());
        expect(next, isTrue);
        stuck.complete();
      });
    });

    test('runCompute applies its time limit to the compute', () async {
      final gate = ComputeGate.forTesting(maxConcurrentTasks: 1);

      // 零时限在 isolate 启动前就到期
      await expectLater(
        gate.runCompute(_echo, 7, timeLimit: Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
      expect(await gate.runCompute(_echo, 8), 8);
    });

    test('keeps default concurrency within processor-safe bounds', () {
      expect(ComputeGate.defaultMaxConcurrentTasks(processorCount: 1), 1);
      expect(ComputeGate.defaultMaxConcurrentTasks(processorCount: 2), 1);
      expect(ComputeGate.defaultMaxConcurrentTasks(processorCount: 8), 3);
    });
  });
}

int _echo(int value) => value;
