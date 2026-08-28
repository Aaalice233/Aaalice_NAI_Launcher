import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cloud_sync/backend/cloud_sync_backend.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_capability_mapper.dart';
import 'package:nai_launcher/presentation/providers/cloud_sync/cloud_sync_ui_provider.dart';

void main() {
  test('maps every backend capability and the real provider limit', () {
    final result = mapCloudSyncCapability(
      const CloudSyncConnectionDraft(backend: CloudSyncBackendKind.github),
      const CloudBackendCapability(
        mode: CloudBackendMode.manualBackupOnly,
        message: 'probe complete',
        supportsHistory: false,
        supportsDelete: false,
        warnings: ['history remains in Git'],
      ),
    );

    expect(result.mode, CloudSyncCapabilityMode.manualBackupOnly);
    expect(result.supportsHistory, isFalse);
    expect(result.supportsDelete, isFalse);
    expect(result.warnings, ['history remains in Git']);
    expect(result.limit, contains('100 MiB'));
  });
}
