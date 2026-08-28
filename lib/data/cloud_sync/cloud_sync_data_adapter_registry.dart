import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

class CloudSyncDataAdapterRegistry {
  CloudSyncDataAdapterRegistry(Iterable<CloudSyncDataAdapter> adapters)
    : _adapters = {for (final adapter in adapters) adapter.id: adapter} {
    if (_adapters.length != adapters.length) {
      throw ArgumentError('Cloud sync adapter IDs must be unique');
    }
  }

  final Map<String, CloudSyncDataAdapter> _adapters;

  List<CloudSyncDataAdapter> get adapters =>
      List.unmodifiable(_adapters.values);

  Set<String> get adapterIds => Set.unmodifiable(_adapters.keys);

  CloudSyncDataAdapter? adapter(String id) => _adapters[id];

  Stream<PortableSyncRecord> exportRecords() async* {
    for (final adapter in _adapters.values) {
      final records = await adapter.exportRecords().toList();
      for (final record in records) {
        if (record.adapterId != adapter.id) {
          throw CloudSyncPreflightException(
            'Adapter ${adapter.id} exported a record for ${record.adapterId}',
          );
        }
        // Export preflight is a trust boundary: adapters may implement their
        // own preflight without extending the validating base class.
        ValidatingCloudSyncDataAdapter.rejectSecrets(record.data);
      }
      await adapter.preflight(records);
      for (final record in records) {
        yield record;
      }
    }
  }

  Future<void> apply(Iterable<PortableSyncRecord> records) async {
    final grouped = <String, List<PortableSyncRecord>>{};
    for (final record in records) {
      final adapter = _adapters[record.adapterId];
      if (adapter == null) {
        throw CloudSyncPreflightException(
          'Unknown adapter ${record.adapterId}',
        );
      }
      (grouped[record.adapterId] ??= []).add(record);
    }

    // This loop must finish before the first mutation in the apply loop.
    for (final entry in grouped.entries) {
      await _adapters[entry.key]!.preflight(entry.value);
    }
    for (final entry in grouped.entries) {
      await _adapters[entry.key]!.apply(entry.value);
    }
  }
}
