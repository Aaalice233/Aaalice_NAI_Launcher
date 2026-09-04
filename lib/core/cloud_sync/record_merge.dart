import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'data_source.dart';
import 'merge.dart';

class CloudRecordMergeResult {
  const CloudRecordMergeResult(this.snapshot, this.conflicts);
  final CloudSyncSnapshotData snapshot;
  final List<MergeConflict<CloudSyncRecord>> conflicts;
}

class CloudRecordMerger {
  const CloudRecordMerger();

  Future<CloudRecordMergeResult> merge({
    required CloudSyncSnapshotData base,
    required CloudSyncSnapshotData local,
    required CloudSyncSnapshotData remote,
    ConflictResolver<CloudSyncRecord>? resolve,
    CloudSyncConflictRecordCopier? conflictCopier,
  }) async {
    Map<String, SyncRecord<CloudSyncRecord>> convert(
      CloudSyncSnapshotData source,
    ) => {
      for (final entry in source.records.entries)
        entry.key: SyncRecord(
          id: entry.key,
          value: entry.value,
          deleted: entry.value.deleted,
        ),
    };
    final metadataChoices = <String, ConflictChoice>{};
    ConflictChoice effectiveResolver(MergeConflict<CloudSyncRecord> conflict) {
      final owner = conflict.id.contains('.c')
          ? conflict.id.substring(0, conflict.id.lastIndexOf('.c'))
          : null;
      if (owner != null && metadataChoices.containsKey(owner)) {
        final choice = metadataChoices[owner]!;
        // A deferred metadata conflict already represents the complete
        // portable record; do not expose each chunk as another conflict.
        return choice == ConflictChoice.defer ? ConflictChoice.local : choice;
      }
      final deletion =
          (conflict.local?.deleted ?? conflict.local == null) ||
          (conflict.remote?.deleted ?? conflict.remote == null);
      final choice =
          resolve?.call(conflict) ??
          (conflict.binary && !deletion
              ? ConflictChoice.keepBoth
              : ConflictChoice.defer);
      if (conflict.local?.value?.kind == 'metadata' ||
          conflict.remote?.value?.kind == 'metadata') {
        metadataChoices[conflict.id] = choice;
      }
      return choice;
    }

    final result =
        ThreeWayMerger<CloudSyncRecord>(
          isBinary: (record) => record?.value?.binary ?? false,
          stableIdentity: (record) {
            final value = record.value!;
            final digest = sha256.convert([
              ...utf8.encode(
                '${value.kind}|${value.binary}|${value.deleted}|'
                '${value.payload?.sha256 ?? ''}|'
                '${value.tombstoneIdentity ?? ''}|',
              ),
            ]);
            return digest.toString().substring(0, 12);
          },
        ).merge(
          base: convert(base),
          local: convert(local),
          remote: convert(remote),
          resolve: effectiveResolver,
        );
    final records = <CloudSyncRecord>[];
    for (final entry in result.records.entries) {
      final value = entry.value.value;
      if (value != null) {
        final resourceOwner =
            value.kind == 'resource' && value.id.contains('.c')
            ? value.id.substring(0, value.id.lastIndexOf('.c'))
            : null;
        if (resourceOwner != null &&
            metadataChoices[resourceOwner] == ConflictChoice.defer) {
          continue;
        }
        // Resource records are copied by the data source together with their
        // owning metadata. Keeping this independently generated copy would
        // create an unreferenced chunk.
        if (conflictCopier != null &&
            value.kind == 'resource' &&
            value.id != entry.key) {
          continue;
        }
        if (value.id == entry.key) {
          records.add(value);
        } else if (conflictCopier != null) {
          records.addAll(
            await conflictCopier.copyConflictRecord(
              source: value,
              requestedId: entry.key,
              sourceSnapshot: remote.records[value.id] == value
                  ? remote
                  : local,
            ),
          );
        } else {
          records.add(
            CloudSyncRecord(
              id: entry.key,
              kind: value.kind,
              binary: value.binary,
              deleted: value.deleted,
              bytes: value.bytes,
              payload: value.bytes == null ? value.payload : null,
              tombstoneIdentity: value.tombstoneIdentity,
            ),
          );
        }
      } else {
        final previous =
            local.records[entry.key] ??
            remote.records[entry.key] ??
            base.records[entry.key];
        // Resource chunks are owned by portable metadata. Their metadata
        // tombstone removes the complete graph; independent chunk tombstones
        // have no stable portable identity.
        if (conflictCopier != null && previous?.kind == 'resource') continue;
        records.add(
          CloudSyncRecord(
            id: entry.key,
            kind: previous?.kind ?? 'record',
            binary: previous?.binary ?? false,
            deleted: true,
          ),
        );
      }
    }
    var snapshot = CloudSyncSnapshotData(records);
    if (conflictCopier != null) {
      snapshot = await conflictCopier.finalizeMergedSnapshot(snapshot);
    }
    return CloudRecordMergeResult(snapshot, result.conflicts);
  }
}

/// Data-layer extension for records whose identity is embedded in their
/// portable metadata and resource graph.
abstract interface class CloudSyncConflictRecordCopier {
  Future<List<CloudSyncRecord>> copyConflictRecord({
    required CloudSyncRecord source,
    required String requestedId,
    required CloudSyncSnapshotData sourceSnapshot,
  });

  Future<CloudSyncSnapshotData> finalizeMergedSnapshot(
    CloudSyncSnapshotData snapshot,
  );
}
