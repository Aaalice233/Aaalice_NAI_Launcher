import 'dart:async';
import 'dart:io';

import 'models.dart';
import 'operation.dart';

const defaultCloudTransferBytesInFlight = 16 * 1024 * 1024;
const desktopCloudTransferBytesInFlight = 32 * 1024 * 1024;
const maxCloudTransferItemBytes = maxCloudObjectBytes;

enum CloudTransferProfile { android, desktop }

class CloudTransferLimits {
  const CloudTransferLimits({
    required this.profile,
    required this.maxConcurrentItems,
    required this.maxBytesInFlight,
  });

  final CloudTransferProfile profile;
  final int maxConcurrentItems;
  final int maxBytesInFlight;
}

const androidCloudTransferLimits = CloudTransferLimits(
  profile: CloudTransferProfile.android,
  maxConcurrentItems: 2,
  maxBytesInFlight: defaultCloudTransferBytesInFlight,
);
const desktopCloudTransferLimits = CloudTransferLimits(
  profile: CloudTransferProfile.desktop,
  maxConcurrentItems: 4,
  maxBytesInFlight: desktopCloudTransferBytesInFlight,
);

CloudTransferLimits cloudTransferLimitsForProfile(
  CloudTransferProfile profile,
) => switch (profile) {
  CloudTransferProfile.android => androidCloudTransferLimits,
  CloudTransferProfile.desktop => desktopCloudTransferLimits,
};

CloudTransferLimits get cloudTransferPlatformLimits =>
    cloudTransferLimitsForProfile(
      Platform.isAndroid
          ? CloudTransferProfile.android
          : CloudTransferProfile.desktop,
    );

int get cloudTransferPlatformConcurrency =>
    cloudTransferPlatformLimits.maxConcurrentItems;
int get cloudTransferPlatformBytesInFlight =>
    cloudTransferPlatformLimits.maxBytesInFlight;

typedef TransferReservationObserver =
    void Function(int activeItems, int reservedBytes);

class BoundedTransferItem<T> {
  const BoundedTransferItem({required this.value, required this.bytes});

  final T value;
  final int bytes;
}

/// Starts transfers in input order while dynamically filling both item and
/// byte capacity. Results retain input order regardless of completion order.
class BoundedTransferScheduler {
  const BoundedTransferScheduler({
    required this.maxConcurrentItems,
    this.maxBytesInFlight = defaultCloudTransferBytesInFlight,
    this.maxItemBytes = maxCloudTransferItemBytes,
  }) : assert(maxConcurrentItems > 0),
       assert(maxBytesInFlight > 0),
       assert(maxItemBytes > 0);

  final int maxConcurrentItems;
  final int maxBytesInFlight;
  final int maxItemBytes;

  Future<List<R>> run<T, R>({
    required List<BoundedTransferItem<T>> items,
    required OperationToken token,
    required Future<R> Function(T item) transfer,
    TransferReservationObserver? onReservationChanged,
  }) async {
    for (final item in items) {
      if (item.bytes < 0 ||
          item.bytes > maxItemBytes ||
          item.bytes > maxBytesInFlight) {
        throw ArgumentError.value(item.bytes, 'item.bytes');
      }
    }
    final results = List<R?>.filled(items.length, null);
    var next = 0;
    var active = 0;
    var bytesInFlight = 0;
    Object? firstError;
    StackTrace? firstStackTrace;
    Completer<void>? changed;

    void notify() {
      final signal = changed;
      if (signal != null && !signal.isCompleted) signal.complete();
    }

    bool fits(BoundedTransferItem<T> item) =>
        active < maxConcurrentItems &&
        bytesInFlight + item.bytes <= maxBytesInFlight;

    void start(int index) {
      final item = items[index];
      active++;
      bytesInFlight += item.bytes;
      onReservationChanged?.call(active, bytesInFlight);
      Future<void>(() async {
        try {
          results[index] = await transfer(item.value);
        } catch (error, stackTrace) {
          firstError ??= error;
          firstStackTrace ??= stackTrace;
        } finally {
          active--;
          bytesInFlight -= item.bytes;
          onReservationChanged?.call(active, bytesInFlight);
          notify();
        }
      });
    }

    while (next < items.length || active != 0) {
      if (firstError == null && !token.isCancelled && !token.isPaused) {
        while (next < items.length && fits(items[next])) {
          token.throwIfCancelled();
          start(next++);
        }
      }
      if (active == 0) {
        if (firstError != null) break;
        if (token.isCancelled) break;
        if (next == items.length) break;
        await token.checkpoint();
        continue;
      }
      final signal = Completer<void>();
      changed = signal;
      if (firstError != null || token.isCancelled) {
        // A completed cancellation future would make Future.any return
        // synchronously forever while in-flight work is still unwinding.
        await signal.future;
      } else {
        await Future.any<void>([signal.future, token.whenCancelled]);
      }
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
    token.throwIfCancelled();
    return results.cast<R>();
  }
}
