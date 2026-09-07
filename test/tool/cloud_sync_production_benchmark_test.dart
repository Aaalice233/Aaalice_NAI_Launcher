import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/cloud_sync/cloud_sync_production_benchmark.dart'
    as benchmark;

void main() {
  test(
    'production round trip stages recovery for a previously absent record',
    () async {
      final parent = Directory('tool/.tmp/cloud-sync-benchmark-test');
      await parent.create(recursive: true);
      final directory = await parent.createTemp('roundtrip-');
      addTearDown(() => directory.delete(recursive: true));
      final report = File('${directory.path}/report.json');

      // A small payload exercises the same capture, recovery and apply contract;
      // the separate CI benchmark still enforces the full 1 GiB budget.
      await benchmark.main(['--output', report.path, '--bytes', '65536']);

      final result =
          jsonDecode(await report.readAsString()) as Map<String, dynamic>;
      expect(result['appliedBytes'], 65536);
      expect(result['sourceOpens'], 1);
      expect(result['durableBaseRecords'], result['payloadCount']);
      expect(result['uploadHashPasses'], result['payloadCount']);
      expect(result['downloadHashPasses'], result['payloadCount']);
      expect(result['defaultOneGiBExecuted'], isFalse);
    },
  );
}
