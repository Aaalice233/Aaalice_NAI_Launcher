import 'dart:convert';

import '../../../core/cloud_sync/coordinator.dart';
import '../../../core/cloud_sync/data_source.dart';
import 'cloud_sync_ui_provider.dart';

class CloudSyncMergePreviewResult {
  const CloudSyncMergePreviewResult({
    required this.remoteRevision,
    required this.conflicts,
    required this.changes,
  });

  final String? remoteRevision;
  final List<CloudSyncConflictView> conflicts;
  final List<CloudSyncChangeSummary> changes;
}

Future<CloudSyncMergePreviewResult> buildCloudSyncPreview(
  SyncCoordinator coordinator,
) async {
  final preview = await coordinator.preview();
  final conflicts = <CloudSyncConflictView>[];
  for (final value in preview.conflicts) {
    conflicts.add(
      CloudSyncConflictView(
        id: value.id,
        kind: await cloudSyncRecordKind(
          value.local?.value ?? value.remote?.value ?? value.base?.value,
        ),
        title: value.id,
        baseSummary: value.base == null ? 'missing' : 'present',
        localSummary: value.local == null ? 'missing' : 'present',
        remoteSummary: value.remote == null ? 'missing' : 'present',
      ),
    );
  }
  return CloudSyncMergePreviewResult(
    remoteRevision: preview.remoteSnapshotId,
    conflicts: conflicts,
    changes: await summarizeCloudSyncChanges(
      before: preview.localSnapshot,
      after: preview.snapshot,
    ),
  );
}

Future<List<CloudSyncChangeSummary>> summarizeCloudSyncChanges({
  required CloudSyncSnapshotData before,
  required CloudSyncSnapshotData after,
}) async {
  final counts = <CloudSyncDataKind, List<int>>{};
  final ids = {...before.records.keys, ...after.records.keys};
  for (final id in ids) {
    final old = before.records[id];
    final next = after.records[id];
    if (old == next) continue;
    final record = next ?? old;
    if (record == null || record.kind == 'resource') continue;
    final kind = await cloudSyncRecordKind(record);
    final values = counts.putIfAbsent(kind, () => [0, 0, 0]);
    if (next == null || next.deleted) {
      values[2]++;
    } else if (old == null || old.deleted) {
      values[0]++;
    } else {
      values[1]++;
    }
  }
  return [
    for (final entry in counts.entries)
      CloudSyncChangeSummary(
        kind: entry.key,
        added: entry.value[0],
        modified: entry.value[1],
        deleted: entry.value[2],
      ),
  ];
}

Future<CloudSyncDataKind> cloudSyncRecordKind(CloudSyncRecord? record) async {
  if (record == null || record.binary || record.kind == 'resource') {
    return CloudSyncDataKind.largeBinary;
  }
  final bytes = await record.readBytes();
  if (bytes == null) return CloudSyncDataKind.settings;
  final adapter = (jsonDecode(utf8.decode(bytes)) as Map)['adapterId'];
  if (adapter is String) {
    if (adapter.contains('vibe') || adapter.contains('precise')) {
      return CloudSyncDataKind.largeBinary;
    }
    if (adapter.contains('gallery') || adapter.contains('favorite')) {
      return CloudSyncDataKind.galleries;
    }
    if (adapter.contains('prompt') || adapter.contains('tag')) {
      return CloudSyncDataKind.prompts;
    }
  }
  return CloudSyncDataKind.settings;
}
