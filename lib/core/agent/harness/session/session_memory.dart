import '../llm_helpers.dart';
import 'session.dart';


class InMemorySessionStorage implements SessionStorage {
  InMemorySessionStorage(this.metadata);

  SessionMetadata metadata;
  final SessionState state = SessionState();

  InMemorySessionStorage fork(
    SessionMetadata metadata,
    ForkOptions options,
  ) {
    final storage = InMemorySessionStorage(metadata);
    for (final mutation in state.createForkMutations(options)) {
      storage.state.applyMutation(mutation);
    }
    return storage;
  }

  @override
  Future<SessionMetadata> getMetadata() async => metadata;

  @override
  Future<List<LanePointer>> getLanes() async => state.getLanes();

  @override
  Future<void> createLane(String lane, String? at) async {
    state.validateNewLane(lane);
    state.validateTarget(at);
    state.applyMutation(
      LaneMutation(seq: state.nextSequence, lane: lane, leafId: at),
    );
  }

  @override
  Future<void> moveLane(String lane, String? to) async {
    state.requireLane(lane);
    state.validateTarget(to);
    state.applyMutation(
      LaneMutation(seq: state.nextSequence, lane: lane, leafId: to),
    );
  }

  @override
  Future<SessionEntry> appendEntry(
    ProvisionedEntry newEntry,
    String lane,
  ) async {
    final parentId = state.requireLane(lane);
    state.validateUnusedId(newEntry.id);
    newEntry.parentId = parentId;
    newEntry.seq = state.nextSequence;
    newEntry.timestamp = DateTime.now().millisecondsSinceEpoch;
    state.applyMutation(EntryMutation(entry: newEntry, lane: lane));
    return newEntry;
  }

  @override
  Future<LaneRecord> appendRecord(NewRecord newRecord) async {
    state.requireLane(newRecord.lane);
    state.validateUnusedId(newRecord.id);
    final currentOpen = state
        .findOpenOperations(newRecord.lane, limit: 1)
        .firstOrNull;
    if (newRecord is OperationStartedRecord && currentOpen != null) {
      throw SessionError(
        SessionErrorCode.storage,
        'Lane ${newRecord.lane} already has an open operation '
            '${currentOpen.id}',
      );
    }
    newRecord.seq = state.nextSequence;
    newRecord.timestamp = DateTime.now().millisecondsSinceEpoch;
    state.applyMutation(RecordMutation(record: newRecord));
    return newRecord;
  }

  @override
  Future<SessionEntry?> getEntry(String id) async => state.getEntry(id);

  @override
  Future<List<SessionEntry>> findEntries([EntryQuery? query]) async {
    return state.findEntries(query);
  }

  @override
  Future<List<SessionEntry>> findEntriesOnBranch(
    EntryQuery query,
    BranchBounds bounds, {
    required String start,
  }) async {
    return state.findEntriesOnBranch(query, bounds, start: start);
  }

  @override
  Future<List<LaneRecord>> findRecords([RecordQuery? query]) async {
    return state.findRecords(query);
  }

  @override
  Future<List<OperationStartedRecord>> findOpenOperations(
    String lane, {
    int? limit,
  }) async {
    return state.findOpenOperations(lane, limit: limit);
  }

  @override
  Future<List<LogItem>> getLog([LogOptions? options]) async {
    return state.getLog(options);
  }

  @override
  Future<String?> getName() async => state.getName();

  @override
  Future<void> setName(String? name) async {
    state.applyMutation(
      NameFactMutation(seq: state.nextSequence, name: name),
    );
  }

  @override
  Future<String?> getLabel(String id) async => state.getLabel(id);

  @override
  Future<void> setLabel(String id, String? label) async {
    state.validateTarget(id);
    state.applyMutation(
      LabelFactMutation(
        seq: state.nextSequence,
        targetId: id,
        label: label,
      ),
    );
  }

  @override
  Future<SessionStats> getStats() async => state.getStats();
}

class InMemorySessionRepo implements SessionRepo {
  final Map<String, InMemorySessionStorage> _sessions = {};

  @override
  Future<Session> create([SessionCreateOptions? options]) async {
    final o = options ?? const SessionCreateOptions();
    final id = o.id ?? uuidv7();
    if (_sessions.containsKey(id)) {
      throw SessionError(
        SessionErrorCode.alreadyExists,
        'Session already exists: $id',
      );
    }
    final storage = InMemorySessionStorage(
      SessionMetadata(
        id: id,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        parentSessionId: o.parentSessionId,
      ),
    );
    _sessions[id] = storage;
    return Session(storage);
  }

  @override
  Future<Session> open(SessionMetadata metadata) async {
    return Session(_requireStorage(metadata.id));
  }

  @override
  Future<List<SessionMetadata>> list() async {
    return [
      for (final storage in _sessions.values) await storage.getMetadata(),
    ];
  }

  @override
  Future<void> delete(SessionMetadata metadata) async {
    _sessions.remove(metadata.id);
  }

  @override
  Future<Session> fork(
    SessionMetadata source, [
    ForkOptions? options,
  ]) async {
    final sourceStorage = _requireStorage(source.id);
    final o = options ?? const ForkOptions();
    final id = uuidv7();
    if (_sessions.containsKey(id)) {
      throw SessionError(
        SessionErrorCode.alreadyExists,
        'Session already exists: $id',
      );
    }
    final storage = sourceStorage.fork(
      SessionMetadata(
        id: id,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        parentSessionId: source.id,
      ),
      o,
    );
    _sessions[id] = storage;
    return Session(storage);
  }

  InMemorySessionStorage _requireStorage(String id) {
    final storage = _sessions[id];
    if (storage == null) {
      throw SessionError(SessionErrorCode.notFound, 'Session not found: $id');
    }
    return storage;
  }
}
