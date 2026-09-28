import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_flight_gate.dart';

void main() {
  test(
    'manual backup waits for an active lifecycle check and runs once',
    () async {
      final gate = CloudSyncFlightGate();
      final release = Completer<void>();
      final events = <String>[];
      final lifecycle = gate.tryRunLifecycle((_) async {
        events.add('check');
        await release.future;
        events.add('checked');
      });
      final backup = gate.run((token) async {
        expect(OperationToken.current, same(token));
        events.add('backup');
      });
      final completed = expectLater(backup, completes);
      expect(events, ['check']);
      await expectLater(
        gate.run((_) async => events.add('duplicate')),
        throwsA(isA<CloudSyncOperationInProgressException>()),
      );
      expect(await gate.tryRunLifecycle((_) async {}), isFalse);
      release.complete();
      await lifecycle;
      await completed;
      expect(events, ['check', 'checked', 'backup']);
      expect(gate.isBusy, isFalse);
    },
  );

  test('rejects concurrent user operations and skips lifecycle work', () async {
    final gate = CloudSyncFlightGate();
    final started = Completer<void>();
    final release = Completer<void>();
    var runs = 0;

    final first = gate.run((token) async {
      runs++;
      started.complete();
      await release.future;
      await token.checkpoint();
    });
    await started.future;
    final second = gate.run((_) async => runs++);
    await expectLater(
      second,
      throwsA(isA<CloudSyncOperationInProgressException>()),
    );
    expect(await gate.tryRunLifecycle((_) async => runs++), isFalse);
    expect(runs, 1);

    release.complete();
    await first;
    expect(await gate.run((_) async => 42), 42);
  });

  test(
    'failed lifecycle check preserves its error and does not run backup',
    () async {
      final gate = CloudSyncFlightGate();
      final release = Completer<void>();
      final error = StateError('connection check failed');
      var backups = 0;
      final lifecycle = gate.tryRunLifecycle((_) => release.future);
      final backup = gate.run((_) async => backups++);
      final checked = expectLater(lifecycle, throwsA(same(error)));
      final completed = expectLater(backup, throwsA(same(error)));
      release.completeError(error);
      await checked;
      await completed;
      expect(backups, 0);
      expect(gate.isBusy, isFalse);
      await gate.run((_) async => backups++);
      expect(backups, 1);
    },
  );

  test(
    'disconnect cancels the check and waiting backup before cleanup',
    () async {
      final gate = CloudSyncFlightGate();
      final release = Completer<void>();
      late OperationToken checkToken;
      var backups = 0;
      var cleaned = false;
      final lifecycle = gate.tryRunLifecycle((token) async {
        checkToken = token;
        await release.future;
        token.throwIfCancelled();
      });
      final backup = gate.run((_) async => backups++);
      final checked = expectLater(
        lifecycle,
        throwsA(isA<OperationCancelledException>()),
      );
      final completed = expectLater(
        backup,
        throwsA(isA<OperationCancelledException>()),
      );
      final close = gate.cancelAndClose(() async => cleaned = true);
      expect(checkToken.isCancelled, isTrue);
      expect(gate.operation!.isCancelled, isTrue);
      expect(cleaned, isFalse);
      release.complete();
      await close;
      await checked;
      await completed;
      expect(backups, 0);
      expect(cleaned, isTrue);
      expect(gate.isBusy, isFalse);
    },
  );

  test('runs the complete flight inside the operation scope', () async {
    final gate = CloudSyncFlightGate();

    await gate.run((token) async {
      expect(OperationToken.current, same(token));
      await Future<void>.delayed(Duration.zero);
      expect(OperationToken.current, same(token));
    });

    expect(OperationToken.current, isNull);
  });

  test(
    'cancelled waiting backup never starts after the check completes',
    () async {
      final gate = CloudSyncFlightGate();
      final release = Completer<void>();
      var backups = 0;
      final lifecycle = gate.tryRunLifecycle((_) => release.future);
      final backup = gate.run((_) async => backups++);
      final completed = expectLater(
        backup,
        throwsA(isA<OperationCancelledException>()),
      );
      gate.operation!.cancel();
      expect(gate.isBusy, isTrue);
      release.complete();
      expect(await lifecycle, isTrue);
      await completed;
      expect(backups, 0);
      expect(gate.isBusy, isFalse);
    },
  );

  test('close cancels the active operation before cleanup', () async {
    final gate = CloudSyncFlightGate();
    final started = Completer<void>();
    final release = Completer<void>();
    var cleanupSawCancellation = false;

    final first = gate.run((token) async {
      started.complete();
      await release.future;
      await token.checkpoint();
    });
    await started.future;
    final close = gate.cancelAndClose(() async {
      cleanupSawCancellation = gate.operation?.isCancelled ?? true;
    });
    release.complete();
    await close;
    await expectLater(first, throwsA(isA<OperationCancelledException>()));
    expect(cleanupSawCancellation, isTrue);
  });
}
