import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_flight_gate.dart';

void main() {
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

  test('runs the complete flight inside the operation scope', () async {
    final gate = CloudSyncFlightGate();

    await gate.run((token) async {
      expect(OperationToken.current, same(token));
      await Future<void>.delayed(Duration.zero);
      expect(OperationToken.current, same(token));
    });

    expect(OperationToken.current, isNull);
  });

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
