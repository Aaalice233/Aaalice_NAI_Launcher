import 'portable_sync_record.dart';

class CloudSyncPreflightException implements Exception {
  const CloudSyncPreflightException(this.message);
  final String message;

  @override
  String toString() => 'CloudSyncPreflightException: $message';
}

abstract interface class CloudSyncDataAdapter {
  String get id;

  Stream<PortableSyncRecord> exportRecords();

  /// Validates every record without changing business data.
  Future<void> preflight(List<PortableSyncRecord> records);

  /// Called only after every adapter in the registry passed preflight.
  Future<void> apply(List<PortableSyncRecord> records);
}

/// Implemented by adapters whose portable IDs also occur in metadata or
/// resource paths. A conflict copy must be a complete, independently
/// applicable business record.
abstract interface class CloudSyncConflictCopyAdapter {
  PortableSyncRecord copyForConflict(
    PortableSyncRecord source, {
    required String newPortableId,
  });
}

abstract class ValidatingCloudSyncDataAdapter implements CloudSyncDataAdapter {
  const ValidatingCloudSyncDataAdapter();

  Set<String> get allowedKinds;

  @override
  Future<void> preflight(List<PortableSyncRecord> records) async {
    final seen = <String>{};
    for (final record in records) {
      if (record.adapterId != id || !allowedKinds.contains(record.kind)) {
        throw CloudSyncPreflightException('Record is not allowed by $id');
      }
      if (!seen.add(record.id)) {
        throw CloudSyncPreflightException('Duplicate record ${record.id}');
      }
      _rejectSecrets(record.data);
      validateRecord(record);
    }
  }

  void validateRecord(PortableSyncRecord record) {}

  static void rejectSecrets(Map<String, Object?> data) => _rejectSecrets(data);

  static void _rejectSecrets(Object? value, [String path = 'data']) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_secretKey.hasMatch(key)) {
          throw CloudSyncPreflightException('Secret-like field at $path.$key');
        }
        _rejectSecrets(entry.value, '$path.$key');
      }
    } else if (value is Iterable) {
      var index = 0;
      for (final item in value) {
        _rejectSecrets(item, '$path[${index++}]');
      }
    }
  }

  static final RegExp _secretKey = RegExp(
    r'(token|password|passwd|api.?key|access.?key|secret|credential|authorization|cookie)',
    caseSensitive: false,
  );
}
