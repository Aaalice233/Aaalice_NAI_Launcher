import 'package:flutter_test/flutter_test.dart';

import '../../../tool/cloud_sync/cloud_sync_benchmark.dart' as benchmark;

void main() {
  test(
    'cloud-sync production protocol and transfer budget benchmark',
    () async {
      const output = String.fromEnvironment(
        'CLOUD_SYNC_BENCHMARK_OUTPUT',
        defaultValue:
            'tool/.tmp/cloud-sync-benchmark/report.synthetic-test.json',
      );
      const includeOneGiB = bool.fromEnvironment(
        'CLOUD_SYNC_BENCHMARK_INCLUDE_1GIB',
      );

      await benchmark.runCloudSyncBenchmark([
        '--output',
        output,
        if (includeOneGiB) '--include-1gib',
      ]);
    },
  );
}
