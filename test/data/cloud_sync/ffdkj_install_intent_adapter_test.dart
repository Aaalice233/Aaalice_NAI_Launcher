import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/cloud_sync/cloud_sync.dart';

void main() {
  test(
    'exports intent and records pending confirmation without installing',
    () async {
      var installed = true;
      var pending = 0;
      final adapter = FfdkjInstallIntentAdapter(
        isInstalled: () => installed,
        recordPendingIntent: () async => pending++,
      );

      final records = await adapter.exportRecords().toList();
      expect(records, hasLength(1));
      expect(records.single.resource, isNull);
      expect(
        records.single.data.keys,
        containsAll(['installed', 'requiresConfirmation']),
      );
      expect(records.single.data.toString(), isNot(contains('sqlite')));

      installed = false;
      await adapter.preflight(records);
      await adapter.apply(records);
      expect(pending, 1);
    },
  );

  test('installed target does not create a pending intent', () async {
    var pending = 0;
    final adapter = FfdkjInstallIntentAdapter(
      isInstalled: () => true,
      recordPendingIntent: () async => pending++,
    );
    final record = PortableSyncRecord(
      adapterId: adapter.id,
      id: 'install',
      kind: 'intent',
      data: const {'installed': true, 'requiresConfirmation': true},
    );
    await adapter.apply([record]);
    expect(pending, 0);
  });
}
