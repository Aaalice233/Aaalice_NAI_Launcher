import 'dart:collection';

class SyncRecord<T> {
  const SyncRecord({
    required this.id,
    required this.value,
    this.deleted = false,
  });
  final String id;
  final T? value;
  final bool deleted;

  @override
  bool operator ==(Object other) =>
      other is SyncRecord<T> &&
      id == other.id &&
      value == other.value &&
      deleted == other.deleted;
  @override
  int get hashCode => Object.hash(id, value, deleted);
}

enum ConflictChoice { local, remote, keepBoth, defer }

class MergeConflict<T> {
  const MergeConflict({
    required this.id,
    this.base,
    this.local,
    this.remote,
    required this.binary,
  });
  final String id;
  final SyncRecord<T>? base;
  final SyncRecord<T>? local;
  final SyncRecord<T>? remote;
  final bool binary;
}

class MergeResult<T> {
  MergeResult(
    Map<String, SyncRecord<T>> records,
    List<MergeConflict<T>> conflicts,
  ) : records = UnmodifiableMapView(Map.of(records)),
      conflicts = UnmodifiableListView(List.of(conflicts));
  final Map<String, SyncRecord<T>> records;
  final List<MergeConflict<T>> conflicts;
}

typedef ConflictResolver<T> =
    ConflictChoice Function(MergeConflict<T> conflict);

class ThreeWayMerger<T> {
  const ThreeWayMerger({required this.isBinary, this.stableIdentity});
  final bool Function(SyncRecord<T>? record) isBinary;
  final String Function(SyncRecord<T> record)? stableIdentity;

  MergeResult<T> merge({
    required Map<String, SyncRecord<T>> base,
    required Map<String, SyncRecord<T>> local,
    required Map<String, SyncRecord<T>> remote,
    ConflictResolver<T>? resolve,
  }) {
    final output = <String, SyncRecord<T>>{};
    final conflicts = <MergeConflict<T>>[];
    final ids = {...base.keys, ...local.keys, ...remote.keys}.toList()..sort();
    for (final id in ids) {
      final ancestor = base[id];
      final left = local[id];
      final right = remote[id];
      final leftChanged = left != ancestor;
      final rightChanged = right != ancestor;
      if (!leftChanged && !rightChanged) {
        if (ancestor != null) output[id] = ancestor;
        continue;
      }
      if (leftChanged && !rightChanged) {
        _put(output, left ?? _tombstone(id));
        continue;
      }
      if (!leftChanged && rightChanged) {
        _put(output, right ?? _tombstone(id));
        continue;
      }
      if (left == right) {
        if (left != null) _put(output, left);
        continue;
      }
      final deletionConflict =
          (left?.deleted ?? left == null) || (right?.deleted ?? right == null);
      final binary = isBinary(left) || isBinary(right);
      final conflict = MergeConflict(
        id: id,
        base: ancestor,
        local: left,
        remote: right,
        binary: binary,
      );
      final choice =
          resolve?.call(conflict) ??
          (binary && !deletionConflict
              ? ConflictChoice.keepBoth
              : ConflictChoice.defer);
      switch (choice) {
        case ConflictChoice.local:
          _put(output, left!);
        case ConflictChoice.remote:
          _put(output, right!);
        case ConflictChoice.keepBoth:
          if (deletionConflict) {
            conflicts.add(conflict);
            continue;
          }
          _put(output, left!);
          _put(
            output,
            SyncRecord(
              id: _copyId(id, right!, output),
              value: right.value,
              deleted: right.deleted,
            ),
          );
        case ConflictChoice.defer:
          conflicts.add(conflict);
      }
    }
    return MergeResult(output, conflicts);
  }

  SyncRecord<T> _tombstone(String id) =>
      SyncRecord(id: id, value: null, deleted: true);

  void _put(Map<String, SyncRecord<T>> output, SyncRecord<T> record) {
    output[record.id] = record;
  }

  String _copyId(
    String id,
    SyncRecord<T> record,
    Map<String, SyncRecord<T>> output,
  ) {
    final stable =
        stableIdentity?.call(record) ??
        record.value.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
    var candidate = '$id.remote-$stable';
    var suffix = 2;
    while (output.containsKey(candidate) && output[candidate] != record) {
      candidate = '$id.remote-$stable-${suffix++}';
    }
    return candidate;
  }
}
