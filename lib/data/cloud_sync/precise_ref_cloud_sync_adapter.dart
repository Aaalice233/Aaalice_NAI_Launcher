import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../core/enums/precise_ref_type.dart';
import '../services/precise_ref_library_storage_service.dart';
import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

class PreciseRefCloudSyncAdapter extends ValidatingCloudSyncDataAdapter
    implements CloudSyncConflictCopyAdapter {
  PreciseRefCloudSyncAdapter(this._storage);

  final PreciseRefLibraryStorageService _storage;

  @override
  String get id => 'precise-ref-library';

  @override
  Set<String> get allowedKinds => const {'entry'};

  @override
  PortableSyncRecord copyForConflict(
    PortableSyncRecord source, {
    required String newPortableId,
  }) {
    final copyId = _conflictUuid(newPortableId);
    return PortableSyncRecord(
      adapterId: id,
      id: copyId,
      kind: source.kind,
      data: source.data,
      resource: PortableSyncResource(
        relativePath: 'precise-ref/$copyId/original',
        length: source.resource!.length,
        mediaType: source.resource!.mediaType,
        openRead: source.resource!.openRead,
      ),
    );
  }

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    for (final entry in await _storage.getAllEntries()) {
      final length = await _storage.getImageLength(entry.id);
      if (length == null) continue;
      yield PortableSyncRecord(
        adapterId: id,
        id: entry.id,
        kind: 'entry',
        data: {
          'name': entry.name,
          'type': entry.type.name,
          'strength': entry.strength,
          'fidelity': entry.fidelity,
          'isFavorite': entry.isFavorite,
          'usedCount': entry.usedCount,
          'lastUsedAt': entry.lastUsedAt?.toUtc().toIso8601String(),
          'createdAt': entry.createdAt.toUtc().toIso8601String(),
        },
        resource: PortableSyncResource(
          relativePath: 'precise-ref/${entry.id}/original',
          length: length,
          openRead: () => _storage.openImageRead(entry.id),
        ),
      );
    }
  }

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.deleted) return;
    final data = record.data;
    if (record.resource == null ||
        data['name'] is! String ||
        data['type'] is! String ||
        data['strength'] is! num ||
        data['fidelity'] is! num ||
        data['isFavorite'] is! bool ||
        data['usedCount'] is! int ||
        data['createdAt'] is! String ||
        !_validDate(data['createdAt']) ||
        !_validNullableDate(data['lastUsedAt'])) {
      throw CloudSyncPreflightException(
        'Invalid precise reference ${record.id}',
      );
    }
    if (!PreciseRefType.values.any((value) => value.name == data['type'])) {
      throw const CloudSyncPreflightException('Unknown precise reference type');
    }
    if (!record.resource!.relativePath.startsWith(
          'precise-ref/${record.id}/',
        ) ||
        record.resource!.relativePath.toLowerCase().contains('thumbnail')) {
      throw const CloudSyncPreflightException(
        'Invalid precise reference resource path',
      );
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    for (final record in records) {
      if (record.deleted) {
        await _storage.deleteEntry(record.id);
        continue;
      }
      final data = record.data;
      await _storage.importPortableEntryStream(
        record.resource!.openRead(),
        expectedLength: record.resource!.length,
        id: record.id,
        name: data['name']! as String,
        type: PreciseRefType.values.firstWhere(
          (value) => value.name == data['type'],
        ),
        strength: (data['strength']! as num).toDouble(),
        fidelity: (data['fidelity']! as num).toDouble(),
        isFavorite: data['isFavorite']! as bool,
        usedCount: data['usedCount']! as int,
        lastUsedAt: _date(data['lastUsedAt']),
        createdAt: DateTime.parse(data['createdAt']! as String).toUtc(),
      );
    }
  }

  bool _validDate(Object? value) =>
      value is String && DateTime.tryParse(value) != null;
  bool _validNullableDate(Object? value) => value == null || _validDate(value);
  DateTime? _date(Object? value) =>
      value is String ? DateTime.parse(value).toUtc() : null;

  String _conflictUuid(String identity) {
    final bytes = sha256.convert(utf8.encode(identity)).bytes.toList();
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .take(16)
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
