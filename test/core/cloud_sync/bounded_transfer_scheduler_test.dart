import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/bounded_transfer_scheduler.dart';
import 'package:nai_launcher/core/cloud_sync/operation.dart';

void main() {
  for (final limits in const [
    androidCloudTransferLimits,
    desktopCloudTransferLimits,
  ]) {
    test(
      '${limits.profile.name} profile respects production object limits',
      () async {
        const itemBytes = maxCloudTransferItemBytes;
        final gate = Completer<void>();
        var peakItems = 0;
        var peakReservedBytes = 0;
        final scheduler = BoundedTransferScheduler(
          maxConcurrentItems: limits.maxConcurrentItems,
          maxBytesInFlight: limits.maxBytesInFlight,
        );

        final future = scheduler.run<int, void>(
          items: [
            for (var index = 0; index < 8; index++)
              const BoundedTransferItem(value: 0, bytes: itemBytes),
          ],
          token: OperationToken(),
          transfer: (_) => gate.future,
          onReservationChanged: (activeItems, reservedBytes) {
            if (activeItems > peakItems) peakItems = activeItems;
            if (reservedBytes > peakReservedBytes) {
              peakReservedBytes = reservedBytes;
            }
          },
        );
        await Future<void>.delayed(Duration.zero);

        expect(peakItems, limits.maxConcurrentItems);
        expect(
          peakReservedBytes,
          limits.maxConcurrentItems * maxCloudTransferItemBytes,
        );
        expect(peakReservedBytes, lessThanOrEqualTo(limits.maxBytesInFlight));
        gate.complete();
        await future;
      },
    );
  }

  test(
    'dynamically bounds item and byte concurrency and orders results',
    () async {
      const scheduler = BoundedTransferScheduler(
        maxConcurrentItems: 3,
        maxBytesInFlight: 8,
        maxItemBytes: 10,
      );
      var active = 0;
      var activeBytes = 0;
      var peakActive = 0;
      var peakBytes = 0;
      final started = <int>[];
      final sizes = [6, 2, 2, 5, 1];

      final results = await scheduler.run<int, String>(
        items: [
          for (var index = 0; index < sizes.length; index++)
            BoundedTransferItem(value: index, bytes: sizes[index]),
        ],
        token: OperationToken(),
        transfer: (index) async {
          started.add(index);
          active++;
          activeBytes += sizes[index];
          peakActive = active > peakActive ? active : peakActive;
          peakBytes = activeBytes > peakBytes ? activeBytes : peakBytes;
          await Future<void>.delayed(
            Duration(milliseconds: index == 0 ? 15 : 2),
          );
          active--;
          activeBytes -= sizes[index];
          return 'result-$index';
        },
      );

      expect(started, [0, 1, 2, 3, 4]);
      expect(results, [
        'result-0',
        'result-1',
        'result-2',
        'result-3',
        'result-4',
      ]);
      expect(peakActive, lessThanOrEqualTo(3));
      expect(peakBytes, lessThanOrEqualTo(8));
    },
  );

  test('rejects an item that exceeds the in-flight byte budget', () async {
    const scheduler = BoundedTransferScheduler(
      maxConcurrentItems: 1,
      maxBytesInFlight: 8,
      maxItemBytes: 10,
    );

    await expectLater(
      scheduler.run<int, void>(
        items: const [BoundedTransferItem(value: 0, bytes: 9)],
        token: OperationToken(),
        transfer: (_) async {},
      ),
      throwsArgumentError,
    );
  });

  test('cancellation prevents queued transfers from starting', () async {
    const scheduler = BoundedTransferScheduler(maxConcurrentItems: 2);
    final token = OperationToken();
    final gate = Completer<void>();
    var started = 0;
    final future = scheduler.run<int, void>(
      items: [
        for (var index = 0; index < 5; index++)
          BoundedTransferItem(value: index, bytes: 1),
      ],
      token: token,
      transfer: (_) async {
        started++;
        await gate.future;
      },
    );
    await Future<void>.delayed(Duration.zero);
    token.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    gate.complete();

    await expectLater(future, throwsA(isA<OperationCancelledException>()));
    expect(started, 2);
  });

  test('failure stops queued work and waits for started transfers', () async {
    const scheduler = BoundedTransferScheduler(maxConcurrentItems: 2);
    final gate = Completer<void>();
    var started = 0;
    var secondFinished = false;
    final future = scheduler.run<int, void>(
      items: [
        for (var index = 0; index < 4; index++)
          BoundedTransferItem(value: index, bytes: 1),
      ],
      token: OperationToken(),
      transfer: (index) async {
        started++;
        if (index == 0) throw StateError('original');
        await gate.future;
        secondFinished = true;
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(started, 2);
    expect(secondFinished, isFalse);
    gate.complete();

    await expectLater(
      future,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'original',
        ),
      ),
    );
    expect(secondFinished, isTrue);
    expect(started, 2);
  });
}
