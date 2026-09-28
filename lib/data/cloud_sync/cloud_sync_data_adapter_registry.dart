import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

class CloudSyncDataAdapterRegistry {
  CloudSyncDataAdapterRegistry(
    Iterable<CloudSyncDataAdapter> adapters, {
    Set<String>? activeAdapterIds,
    Future<void> Function(Set<String> adapterIds)? afterApply,
  }) : _afterApply = afterApply,
       _adapters = {for (final adapter in adapters) adapter.id: adapter},
       _activeAdapterIds =
           activeAdapterIds ?? {for (final adapter in adapters) adapter.id} {
    if (_adapters.length != adapters.length) {
      throw ArgumentError('Cloud sync adapter IDs must be unique');
    }
    if (!_adapters.keys.toSet().containsAll(_activeAdapterIds)) {
      throw ArgumentError('Active cloud sync adapter IDs must be registered');
    }
  }

  final Map<String, CloudSyncDataAdapter> _adapters;
  final Set<String> _activeAdapterIds;
  final Future<void> Function(Set<String> adapterIds)? _afterApply;

  List<CloudSyncDataAdapter> get adapters => List.unmodifiable(
    _adapters.values.where((adapter) => _activeAdapterIds.contains(adapter.id)),
  );

  Set<String> get adapterIds => Set.unmodifiable(_activeAdapterIds);

  Set<String> get knownAdapterIds => Set.unmodifiable(_adapters.keys);

  CloudSyncDataAdapter? adapter(String id) => _adapters[id];

  Stream<PortableSyncRecord> exportRecords() async* {
    for (final adapter in adapters) {
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
      if (adapter == null || !_activeAdapterIds.contains(record.adapterId)) {
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
    if (grouped.isNotEmpty) {
      await _afterApply?.call(Set.unmodifiable(grouped.keys.toSet()));
    }
  }
}
