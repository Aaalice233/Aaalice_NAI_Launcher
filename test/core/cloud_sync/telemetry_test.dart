import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/telemetry.dart';

void main() {
  test(
    'telemetry captures deterministic stage, request, byte, and hash totals',
    () async {
      CloudSyncTelemetrySnapshot? result;

      await CloudSyncTelemetry.trace('test', () async {
        CloudSyncTelemetry.enterStage('preparing');
        CloudSyncTelemetry.recordHashPass(3);
        CloudSyncTelemetry.recordRequest(bytesRead: 12, bytesWritten: 34);
        CloudSyncTelemetry.enterStage('uploading');
        CloudSyncTelemetry.recordRequest(bytesWritten: 56);
        CloudSyncTelemetry.recordPayloadOpen();
        CloudSyncTelemetry.recordLocalRead(78);
        CloudSyncTelemetry.recordLocalWrite(90, flushed: true);
      }, onComplete: (snapshot) => result = snapshot);

      expect(result, isNotNull);
      expect(result!.requestCount, 2);
      expect(result!.bytesRead, 12);
      expect(result!.bytesWritten, 90);
      expect(result!.hashPasses, 3);
      expect(result!.payloadReads, 1);
      expect(result!.localBytesRead, 78);
      expect(result!.localBytesWritten, 90);
      expect(result!.flushes, 1);
      expect(result!.stageDurations.keys, ['preparing', 'uploading']);
      expect(result!.elapsed, greaterThanOrEqualTo(Duration.zero));
    },
  );

  test('instrumentation outside a trace is a no-op', () {
    CloudSyncTelemetry.enterStage('idle');
    CloudSyncTelemetry.recordHashPass();
    CloudSyncTelemetry.recordRequest(bytesRead: 1, bytesWritten: 1);
    CloudSyncTelemetry.recordPayloadOpen();
    CloudSyncTelemetry.recordLocalRead(1);
    CloudSyncTelemetry.recordLocalWrite(1, flushed: true);
  });
}
