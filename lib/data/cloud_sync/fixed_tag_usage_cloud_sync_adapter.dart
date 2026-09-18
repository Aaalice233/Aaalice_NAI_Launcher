import '../models/fixed_tag/fixed_tag_usage_snapshot.dart';
import '../services/fixed_tag/fixed_tag_usage_record_store.dart';
import 'cloud_sync_data_adapter.dart';
import 'portable_sync_record.dart';

/// 固定词使用记录云同步适配器
///
/// 只同步“哪张图用了哪些固定词”：usage 记录携带图片内容哈希与快照指纹，
/// snapshot 记录按指纹保存快照本体；不含路径、账号或图片字节。
class FixedTagUsageCloudSyncAdapter extends ValidatingCloudSyncDataAdapter {
  FixedTagUsageCloudSyncAdapter(this._store);

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  final FixedTagUsageRecordStore _store;

  @override
  String get id => 'fixed-tag-usage';

  @override
  Set<String> get allowedKinds => const {'usage', 'snapshot'};

  @override
  Stream<PortableSyncRecord> exportRecords() async* {
    await _store.initialize();
    final usage = _store.exportUsage();
    if (usage.isEmpty) return;
    final referenced = {for (final record in usage) record.fingerprint};
    final snapshots = _store.exportSnapshots();
    for (final fingerprint in referenced.toList()..sort()) {
      final snapshot = snapshots[fingerprint];
      if (snapshot == null) continue;
      yield PortableSyncRecord(
        adapterId: id,
        id: _snapshotId(fingerprint),
        kind: 'snapshot',
        data: {'fingerprint': fingerprint, 'snapshot': snapshot},
      );
    }
    for (final record in usage) {
      yield PortableSyncRecord(
        adapterId: id,
        id: _usageId(record.contentHash),
        kind: 'usage',
        data: {
          'contentHash': record.contentHash,
          'fingerprint': record.fingerprint,
          'recordedAt': record.recordedAt.toUtc().millisecondsSinceEpoch,
        },
      );
    }
  }

  @override
  Map<String, Object?> tombstoneData(PortableSyncRecord record) => {
    if (record.kind == 'usage') 'contentHash': record.data['contentHash'],
    if (record.kind == 'snapshot') 'fingerprint': record.data['fingerprint'],
  };

  @override
  void validateRecord(PortableSyncRecord record) {
    if (record.kind == 'snapshot') {
      _validateSnapshot(record);
      return;
    }
    _validateUsage(record);
  }

  @override
  Future<void> preflight(List<PortableSyncRecord> records) async {
    await super.preflight(records);
    await _store.initialize();

    final batchFingerprints = <String>{
      for (final record in records)
        if (record.kind == 'snapshot' && !record.deleted)
          record.data['fingerprint']! as String,
    };
    for (final record in records) {
      if (record.kind != 'usage' || record.deleted) continue;
      final fingerprint = record.data['fingerprint']! as String;
      if (batchFingerprints.contains(fingerprint)) continue;
      if (_store.snapshotOf(fingerprint) != null) continue;
      throw CloudSyncPreflightException(
        'Fixed-tag usage references a missing snapshot: $fingerprint',
      );
    }
  }

  @override
  Future<void> apply(List<PortableSyncRecord> records) async {
    final snapshots = <String, Map<String, dynamic>>{};
    final usage = <FixedTagUsageRecord>[];
    final removedHashes = <String>[];
    for (final record in records) {
      if (record.kind == 'snapshot') {
        if (record.deleted) continue;
        snapshots[record.data['fingerprint']! as String] =
            Map<String, dynamic>.from(record.data['snapshot']! as Map);
        continue;
      }
      final contentHash = record.data['contentHash']! as String;
      if (record.deleted) {
        removedHashes.add(contentHash);
        continue;
      }
      usage.add(
        FixedTagUsageRecord(
          contentHash: contentHash,
          fingerprint: record.data['fingerprint']! as String,
          recordedAt: DateTime.fromMillisecondsSinceEpoch(
            (record.data['recordedAt']! as num).toInt(),
            isUtc: true,
          ),
        ),
      );
    }

    await _store.applySync(snapshots: snapshots, usage: usage);
    for (final contentHash in removedHashes) {
      await _store.removeUsage(contentHash);
    }
  }

  void _validateSnapshot(PortableSyncRecord record) {
    final fingerprint = record.data['fingerprint'];
    if (fingerprint is! String || !_hex64.hasMatch(fingerprint)) {
      throw const CloudSyncPreflightException(
        'Fixed-tag snapshot record lacks a valid fingerprint',
      );
    }
    if (record.id != _snapshotId(fingerprint)) {
      throw const CloudSyncPreflightException(
        'Fixed-tag snapshot identity mismatch',
      );
    }
    if (record.deleted) return;
    final snapshot = record.data['snapshot'];
    if (snapshot is! Map) {
      throw const CloudSyncPreflightException(
        'Fixed-tag snapshot record lacks a snapshot payload',
      );
    }
    final parsed = FixedTagUsageSnapshot.fromJson(
      Map<String, dynamic>.from(snapshot),
    );
    if (parsed.fingerprint != fingerprint) {
      throw const CloudSyncPreflightException(
        'Fixed-tag snapshot does not match its fingerprint',
      );
    }
  }

  void _validateUsage(PortableSyncRecord record) {
    final contentHash = record.data['contentHash'];
    if (contentHash is! String || !_hex64.hasMatch(contentHash)) {
      throw const CloudSyncPreflightException(
        'Fixed-tag usage record lacks a valid contentHash',
      );
    }
    if (record.id != _usageId(contentHash)) {
      throw const CloudSyncPreflightException(
        'Fixed-tag usage identity mismatch',
      );
    }
    if (record.deleted) return;
    final fingerprint = record.data['fingerprint'];
    if (fingerprint is! String || !_hex64.hasMatch(fingerprint)) {
      throw const CloudSyncPreflightException(
        'Fixed-tag usage record lacks a valid fingerprint',
      );
    }
    final recordedAt = record.data['recordedAt'];
    if (recordedAt is! int || recordedAt < 0) {
      throw const CloudSyncPreflightException(
        'Fixed-tag usage record lacks a valid recordedAt',
      );
    }
  }

  String _usageId(String contentHash) => 'usage:$contentHash';

  String _snapshotId(String fingerprint) => 'snapshot:$fingerprint';
}
