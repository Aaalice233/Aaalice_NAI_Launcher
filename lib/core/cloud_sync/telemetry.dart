import 'dart:async';

import 'telemetry_log.dart';

final class CloudSyncTelemetrySnapshot {
  const CloudSyncTelemetrySnapshot({
    required this.elapsed,
    required this.stageDurations,
    required this.requestCount,
    required this.bytesRead,
    required this.bytesWritten,
    required this.hashPasses,
    required this.payloadReads,
    required this.localBytesRead,
    required this.localBytesWritten,
    required this.flushes,
  });

  final Duration elapsed;
  final Map<String, Duration> stageDurations;
  final int requestCount;
  final int bytesRead;
  final int bytesWritten;
  final int hashPasses;
  final int payloadReads;
  final int localBytesRead;
  final int localBytesWritten;
  final int flushes;

  String toLogFields() =>
      'elapsedMs=${elapsed.inMilliseconds}, requests=$requestCount, '
      'bytesRead=$bytesRead, bytesWritten=$bytesWritten, '
      'hashPasses=$hashPasses, payloadReads=$payloadReads, '
      'localBytesRead=$localBytesRead, localBytesWritten=$localBytesWritten, '
      'flushes=$flushes, '
      'stages=${stageDurations.map((key, value) => MapEntry(key, value.inMilliseconds))}';
}

final class CloudSyncTelemetry {
  CloudSyncTelemetry._();

  static final Object _zoneKey = Object();
  static _CloudSyncTelemetryState? get _current =>
      Zone.current[_zoneKey] as _CloudSyncTelemetryState?;

  static Future<T> trace<T>(
    String operation,
    Future<T> Function() action, {
    void Function(CloudSyncTelemetrySnapshot snapshot)? onComplete,
  }) async {
    final state = _CloudSyncTelemetryState();
    try {
      return await runZoned(action, zoneValues: {_zoneKey: state});
    } finally {
      state.finishStage();
      final snapshot = state.snapshot();
      onComplete?.call(snapshot);
      logCloudSyncMetrics(
        'Cloud sync operation metrics: operation=$operation, '
        '${snapshot.toLogFields()}',
      );
    }
  }

  static void enterStage(String stage) => _current?.enterStage(stage);

  static void recordRequest({int bytesRead = 0, int bytesWritten = 0}) {
    final current = _current;
    if (current == null) return;
    current.requestCount++;
    current.bytesRead += bytesRead;
    current.bytesWritten += bytesWritten;
  }

  static void recordHashPass([int count = 1]) {
    if (count > 0) _current?.hashPasses += count;
  }

  static void recordPayloadOpen() {
    _current?.payloadReads++;
  }

  static void recordLocalRead(int bytes) {
    if (bytes > 0) _current?.localBytesRead += bytes;
  }

  static void recordLocalWrite(int bytes, {bool flushed = false}) {
    if (bytes < 0) return;
    final current = _current;
    if (current == null) return;
    current.localBytesWritten += bytes;
    if (flushed) current.flushes++;
  }
}

final class _CloudSyncTelemetryState {
  final Stopwatch elapsed = Stopwatch()..start();
  final Map<String, Duration> stageDurations = {};
  String? activeStage;
  Stopwatch? activeStageWatch;
  int requestCount = 0;
  int bytesRead = 0;
  int bytesWritten = 0;
  int hashPasses = 0;
  int payloadReads = 0;
  int localBytesRead = 0;
  int localBytesWritten = 0;
  int flushes = 0;

  void enterStage(String stage) {
    if (stage == activeStage) return;
    finishStage();
    activeStage = stage;
    activeStageWatch = Stopwatch()..start();
  }

  void finishStage() {
    final stage = activeStage;
    final watch = activeStageWatch;
    if (stage != null && watch != null) {
      watch.stop();
      stageDurations[stage] =
          (stageDurations[stage] ?? Duration.zero) + watch.elapsed;
    }
    activeStage = null;
    activeStageWatch = null;
  }

  CloudSyncTelemetrySnapshot snapshot() {
    elapsed.stop();
    return CloudSyncTelemetrySnapshot(
      elapsed: elapsed.elapsed,
      stageDurations: Map.unmodifiable(stageDurations),
      requestCount: requestCount,
      bytesRead: bytesRead,
      bytesWritten: bytesWritten,
      hashPasses: hashPasses,
      payloadReads: payloadReads,
      localBytesRead: localBytesRead,
      localBytesWritten: localBytesWritten,
      flushes: flushes,
    );
  }
}
