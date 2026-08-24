import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/gallery/deferred_scan_work.dart';

void main() {
  test('replays the latest deferred work when scanning completes', () async {
    final signals = StreamController<void>.broadcast();
    var isScanning = true;
    final completed = Completer<void>();
    final executed = <int>[];
    final deferred = DeferredScanWork<int>(
      isBlocked: () => isScanning,
      resumeSignals: signals.stream,
      run: (work) async {
        executed.add(work);
        completed.complete();
      },
    );
    addTearDown(() async {
      await deferred.dispose();
      await signals.close();
    });

    deferred.schedule(1);
    deferred.schedule(2);
    expect(executed, isEmpty);

    isScanning = false;
    signals.add(null);
    await completed.future.timeout(const Duration(seconds: 1));

    expect(executed, [2]);
  });

  test('closes the completion-before-subscription race', () async {
    final signals = StreamController<void>.broadcast();
    var checks = 0;
    final completed = Completer<void>();
    final deferred = DeferredScanWork<int>(
      isBlocked: () => checks++ == 0,
      resumeSignals: signals.stream,
      run: (_) async => completed.complete(),
    );
    addTearDown(() async {
      await deferred.dispose();
      await signals.close();
    });

    deferred.schedule(1);
    await completed.future.timeout(const Duration(seconds: 1));
  });
}
