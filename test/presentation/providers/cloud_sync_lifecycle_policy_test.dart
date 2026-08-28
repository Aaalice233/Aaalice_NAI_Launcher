import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/core/cloud_sync/models.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_lifecycle_policy.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';

void main() {
  test('uses the portable snapshot identity instead of provider ETag', () {
    final bytes = SnapshotHead(
      snapshotId: 'snapshot-portable',
      manifestSha256: 'a' * 64,
      updatedAt: DateTime.utc(2026),
    ).encode();

    expect(
      cloudSyncSnapshotId(
        CloudHeadRead(
          bytes: Uint8List.fromList(bytes),
          revision: 'provider-specific-etag',
        ),
      ),
      'snapshot-portable',
    );
  });

  test('resume only fully syncs for a changed revision or pending journal', () {
    bool decide({
      String? known = 'revision-1',
      String? current = 'revision-1',
      bool pending = false,
      CloudSyncCapabilityMode mode = CloudSyncCapabilityMode.bidirectional,
    }) => shouldRunLifecycleSync(true, mode, known, current, pending);

    expect(decide(), isFalse);
    expect(decide(current: 'revision-2'), isTrue);
    expect(decide(pending: true), isTrue);
    expect(
      decide(
        current: 'revision-2',
        pending: true,
        mode: CloudSyncCapabilityMode.manualBackupOnly,
      ),
      isFalse,
    );
  });
}
