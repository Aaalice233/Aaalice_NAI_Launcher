import 'session_types.dart';


sealed class SessionMutation {
  const SessionMutation();

  int get seq;
}

class EntryMutation extends SessionMutation {
  const EntryMutation({required this.entry, this.lane});

  @override
  int get seq => entry.seq;

  final SessionEntry entry;
  final String? lane;
}

class RecordMutation extends SessionMutation {
  const RecordMutation({required this.record});

  @override
  int get seq => record.seq;

  final LaneRecord record;
}

class LaneMutation extends SessionMutation {
  const LaneMutation({
    required this.seq,
    required this.lane,
    required this.leafId,
  });

  @override
  final int seq;

  final String lane;
  final String? leafId;
}

class NameFactMutation extends SessionMutation {
  const NameFactMutation({required this.seq, required this.name});

  @override
  final int seq;

  final String? name;
}

class LabelFactMutation extends SessionMutation {
  const LabelFactMutation({
    required this.seq,
    required this.targetId,
    required this.label,
  });

  @override
  final int seq;

  final String targetId;
  final String? label;
}

void _invalidMutation(String message) => throw SessionError(
  SessionErrorCode.invalidEntry,
  'Invalid session mutation: $message',
  );

void assertValidLimit(int? limit) {
  if (limit != null && limit <= 0) {
    throw SessionError(
      SessionErrorCode.invalidQuery,
      'limit must be a positive integer',
    );
  }
}

void assertValidCursor(int? afterSeq) {
  if (afterSeq != null && afterSeq < 0) {
    throw SessionError(
      SessionErrorCode.invalidQuery,
      'cursor sequence must be a non-negative integer',
    );
  }
}

Iterable<T> _ordered<T>(List<T> items, EntryOrder? order) {
  if (order == EntryOrder.oldestFirst) {
    return items;
  }
  return items.reversed;
}

class SessionState {
  int _sequence = 0;
  final Set<String> _usedIds = {};
  final List<SessionEntry> _entries = [];
  final Map<String, SessionEntry> _entriesById = {};
  final List<LaneRecord> _records = [];
  final Map<String, Map<String, OperationStartedRecord>> _openOperationsByLane = {};
  final Map<String, String?> _lanes = {'main': null};
  final List<LogItem> _log = [];
  final SessionStats _stats = SessionStats();
  String? _name;
  final Map<String, String> _labels = {};

  int get nextSequence => _sequence + 1;

  List<LanePointer> getLanes() {
    return [
      for (final entry in _lanes.entries)
        LanePointer(lane: entry.key, leafId: entry.value),
    ];
  }

  String? requireLane(String lane) {
    if (!_lanes.containsKey(lane)) {
      throw SessionError(SessionErrorCode.invalidLane, 'Lane not found: $lane');
    }
    return _lanes[lane];
  }

  void validateNewLane(String lane) {
    if (_lanes.containsKey(lane)) {
      throw SessionError(
        SessionErrorCode.alreadyExists,
        'Lane already exists: $lane',
      );
    }
  }

  void validateTarget(String? targetId) {
    if (targetId != null && !_entriesById.containsKey(targetId)) {
      throw SessionError(
        SessionErrorCode.notFound,
        'Entry not found: $targetId',
      );
    }
  }

  void validateUnusedId(String id) {
    if (_usedIds.contains(id)) {
      throw SessionError(
        SessionErrorCode.alreadyExists,
        'Session id already exists: $id',
      );
    }
  }

  void applyMutation(SessionMutation mutation) {
    final seq = mutation.seq;
    if (seq != _sequence + 1) {
      _invalidMutation('has non-consecutive seq $seq');
    }

    switch (mutation) {
      case EntryMutation():
        final entry = mutation.entry;
        if (_usedIds.contains(entry.id)) {
          _invalidMutation('contains duplicate id ${entry.id}');
        }
        final lane = mutation.lane;
        if (lane != null) {
          if (!_lanes.containsKey(lane)) {
            _invalidMutation('references missing lane $lane');
          }
          if (entry.parentId != _lanes[lane]) {
            _invalidMutation('does not chain to the lane leaf');
          }
        }
        if (entry.parentId != null && !_entriesById.containsKey(entry.parentId)) {
          _invalidMutation('references missing parent ${entry.parentId}');
        }
        _sequence = seq;
        _usedIds.add(entry.id);
        _entries.add(entry);
        _entriesById[entry.id] = entry;
        if (lane != null) {
          _lanes[lane] = entry.id;
        }
        _log.add(LogEntryItem(seq: seq, entry: entry));
        if (entry is MessageEntry) {
          _stats.messageCount += 1;
        }
      case RecordMutation():
        final record = mutation.record;
        if (!_lanes.containsKey(record.lane)) {
          _invalidMutation('references missing lane ${record.lane}');
        }
        if (_usedIds.contains(record.id)) {
          _invalidMutation('contains duplicate id ${record.id}');
        }
        _sequence = seq;
        _usedIds.add(record.id);
        _records.add(record);
        if (record is OperationStartedRecord) {
          _openOperationsByLane
              .putIfAbsent(record.lane, () => {})
              [record.id] = record;
        } else if (record is OperationFinishedRecord) {
          _openOperationsByLane[record.lane]?.remove(record.runId);
        }
        _log.add(LogRecordItem(seq: seq, record: record));
        if (record is UsageRecord) {
          _stats.cachedTokens += record.usage.cacheRead;
          _stats.uncachedTokens += record.usage.input + record.usage.cacheWrite;
          _stats.totalTokens += record.usage.totalTokens;
          _stats.costTotal += record.usage.cost.total;
        }
      case LaneMutation():
        if (mutation.leafId != null &&
            !_entriesById.containsKey(mutation.leafId)) {
          _invalidMutation('references missing lane target ${mutation.leafId}');
        }
        _sequence = seq;
        _lanes[mutation.lane] = mutation.leafId;
        _log.add(
          LogLaneItem(seq: seq, lane: mutation.lane, leafId: mutation.leafId),
        );
      case NameFactMutation():
        _sequence = seq;
        _name = mutation.name;
        _log.add(LogNameFactItem(seq: seq, name: mutation.name));
      case LabelFactMutation():
        if (!_entriesById.containsKey(mutation.targetId)) {
          _invalidMutation(
            'references missing label target ${mutation.targetId}',
          );
        }
        _sequence = seq;
        if (mutation.label == null) {
          _labels.remove(mutation.targetId);
        } else {
          _labels[mutation.targetId] = mutation.label!;
        }
        _log.add(
          LogLabelFactItem(
            seq: seq,
            targetId: mutation.targetId,
            label: mutation.label,
          ),
        );
    }
  }

  SessionEntry? getEntry(String id) => _entriesById[id];

  List<SessionEntry> findEntries([EntryQuery? query]) {
    final q = query ?? const EntryQuery();
    assertValidLimit(q.limit);
    assertValidCursor(q.cursor?.afterSeq);
    final results = <SessionEntry>[];
    for (final entry in _ordered(_entries, q.order)) {
      if (!_matchesEntryQuery(entry, q)) {
        continue;
      }
      results.add(entry);
      if (results.length == q.limit) {
        break;
      }
    }
    return results;
  }

  List<SessionEntry> findEntriesOnBranch(
    EntryQuery query,
    BranchBounds bounds, {
    required String start,
  }) {
    assertValidLimit(query.limit);
    assertValidCursor(query.cursor?.afterSeq);
    final results = <SessionEntry>[];
    if (query.order == EntryOrder.oldestFirst) {
      final path = walkToRoot(start, bounds: bounds).toList().reversed;
      for (final entry in path) {
        final reachedBound =
            entry.id == bounds.stopAtId || entry.type == bounds.stopAtType;
        if (_matchesEntryQuery(entry, query)) {
          results.add(entry);
        }
        if (reachedBound || results.length == query.limit) {
          break;
        }
      }
    } else {
      for (final entry in walkToRoot(start, bounds: bounds)) {
        if (_matchesEntryQuery(entry, query)) {
          results.add(entry);
        }
        if (results.length == query.limit) {
          break;
        }
      }
    }
    return results;
  }

  List<LaneRecord> findRecords([RecordQuery? query]) {
    final q = query ?? const RecordQuery();
    assertValidLimit(q.limit);
    assertValidCursor(q.afterSeq);
    final results = <LaneRecord>[];
    for (final record in _ordered(_records, q.order)) {
      if (!_matchesRecordQuery(record, q)) {
        continue;
      }
      results.add(record);
      if (results.length == q.limit) {
        break;
      }
    }
    return results;
  }

  List<OperationStartedRecord> findOpenOperations(
    String lane, {
    int? limit,
  }) {
    assertValidLimit(limit);
    final openOperationsById = _openOperationsByLane[lane];
    final openOperations = openOperationsById == null
        ? <OperationStartedRecord>[]
        : openOperationsById.values.toList().reversed.toList();
    return limit == null ? openOperations : openOperations.take(limit).toList();
  }

  List<LogItem> getLog([LogOptions? options]) {
    final o = options ?? const LogOptions();
    assertValidLimit(o.limit);
    assertValidCursor(o.afterSeq);
    final results = <LogItem>[];
    for (final item in _log) {
      if (o.afterSeq != null && item.seq <= o.afterSeq!) {
        continue;
      }
      results.add(item);
      if (results.length == o.limit) {
        break;
      }
    }
    return results;
  }

  String? getName() => _name;

  String? getLabel(String id) => _labels[id];

  SessionStats getStats() => _stats;

  List<SessionMutation> createForkMutations(ForkOptions options) {
    List<SessionEntry> copiedEntries;
    List<LanePointer> forkLanes;
    if (options.scope == 'tree') {
      copiedEntries = findEntries(
        const EntryQuery(order: EntryOrder.oldestFirst),
      );
      forkLanes = getLanes();
    } else {
      final selectedEntryId = options.entryId ?? requireLane('main');
      String? targetId;
      if (selectedEntryId != null) {
        final entry = getEntry(selectedEntryId);
        if (entry == null || entry is! MessageEntry) {
          throw SessionError(
            SessionErrorCode.invalidForkTarget,
            'Fork target is not a message entry: $selectedEntryId',
          );
        }
        final position =
            options.position ??
            (options.entryId == null ? 'at' : 'before');
        targetId = position == 'at' ? entry.id : entry.parentId;
      }
      copiedEntries = targetId == null
          ? const []
          : findEntriesOnBranch(
              const EntryQuery(order: EntryOrder.oldestFirst),
              const BranchBounds(),
              start: targetId,
            );
      forkLanes = [LanePointer(lane: 'main', leafId: targetId)];
    }

    final mutations = <SessionMutation>[];
    var sequence = 1;
    for (final sourceEntry in copiedEntries) {
      sourceEntry.seq = sequence++;
      mutations.add(EntryMutation(entry: sourceEntry));
    }
    for (final pointer in forkLanes) {
      mutations.add(
        LaneMutation(seq: sequence++, lane: pointer.lane, leafId: pointer.leafId),
      );
    }
    if (_name != null) {
      mutations.add(NameFactMutation(seq: sequence++, name: _name));
    }
    for (final entry in copiedEntries) {
      final label = _labels[entry.id];
      if (label != null) {
        mutations.add(
          LabelFactMutation(seq: sequence++, targetId: entry.id, label: label),
        );
      }
    }
    return mutations;
  }

  Iterable<SessionEntry> walkToRoot(
    String? start, {
    BranchBounds? bounds,
  }) sync* {
    if (start == null) {
      return;
    }
    final visited = <String>{};
    var current = _entriesById[start];
    if (current == null) {
      throw SessionError(SessionErrorCode.notFound, 'Entry not found: $start');
    }
    while (current != null) {
      if (visited.contains(current.id)) {
        throw SessionError(
          SessionErrorCode.invalidEntry,
          'Session branch contains a cycle at ${current.id}',
        );
      }
      visited.add(current.id);
      yield current;
      if (current.id == bounds?.stopAtId ||
          current.type == bounds?.stopAtType ||
          current.parentId == null) {
        break;
      }
      final parentId = current.parentId!;
      current = _entriesById[parentId];
      if (current == null) {
        throw SessionError(
          SessionErrorCode.invalidEntry,
          'Entry not found: $parentId',
        );
      }
    }
  }

  bool _matchesEntryQuery(SessionEntry entry, EntryQuery query) {
    final typeOk = query.type == null || entry.type == query.type;
    final customOk =
        query.customType == null ||
        (entry is CustomEntry && entry.customType == query.customType);
    final cursorOk =
        query.cursor == null ||
        (query.order == EntryOrder.oldestFirst
            ? entry.seq > query.cursor!.afterSeq
            : entry.seq < query.cursor!.afterSeq);
    return typeOk && customOk && cursorOk;
  }

  bool _matchesRecordQuery(LaneRecord record, RecordQuery query) {
    final laneOk = query.lane == null || record.lane == query.lane;
    final typeOk = query.type == null || record.type == query.type;
    final runIdOk = query.runId == null ||
        (record is OperationStartedRecord
            ? record.id == query.runId
            : switch (record) {
                final AbortRequestedRecord r => r.runId == query.runId,
                final OperationFinishedRecord r => r.runId == query.runId,
                final StepAttemptRecord r => r.runId == query.runId,
                final ToolStartedRecord r => r.runId == query.runId,
                final QueueEnqueuedRecord r => r.runId == query.runId,
                final QueueCancelledRecord r => r.runId == query.runId,
                final WriteDeferredRecord r => r.runId == query.runId,
                final UsageRecord r => r.runId == query.runId,
                _ => false,
              });
    final opKindOk =
        query.operationKind == null ||
        (record is OperationStartedRecord &&
            record.intent.kind == query.operationKind);
    final afterSeqOk = query.afterSeq == null || record.seq > query.afterSeq!;
    return laneOk && typeOk && runIdOk && opKindOk && afterSeqOk;
  }
}
