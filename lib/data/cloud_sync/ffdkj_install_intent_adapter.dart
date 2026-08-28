import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

typedef FfdkjConfirmation = Future<bool> Function();
typedef FfdkjPendingIntentWriter = Future<void> Function();

/// Syncs only the user's installation intent, never tag.sqlite or metadata.
class FfdkjInstallIntentAdapter extends ValidatingCloudSyncDataAdapter {
  FfdkjInstallIntentAdapter({
    required this.isInstalled,
    required this.recordPendingIntent,
  });

  final bool Function() isInstalled;
  final FfdkjPendingIntentWriter recordPendingIntent;

  @override
  String get id => 'ffdkj-install-intent';

  @override
  Set<String> get allowedKinds => const {'intent'};

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    if (!isInstalled()) return;
    yield PortableSyncRecord(
      adapterId: id,
      id: 'install',
      kind: 'intent',
      data: const {'installed': true, 'requiresConfirmation': true},
    );
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.deleted ||
        record.id != 'install' ||
        record.resource != null ||
        record.data['installed'] != true ||
        record.data['requiresConfirmation'] != true) {
      throw const CloudSyncPreflightException('Invalid ffdkj install intent');
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    if (records.isEmpty || isInstalled()) return;
    await recordPendingIntent();
  }
}
