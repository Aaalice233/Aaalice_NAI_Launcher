import 'dart:convert';

import '../../agent_types.dart';
import '../llm_helpers.dart';
import 'session_state.dart';
import 'session_types.dart';

export 'session_state.dart';
export 'session_types.dart';

typedef IdGenerator = String Function();

void _assertValidLimit(int? limit) => assertValidLimit(limit);
void _assertValidCursor(int? afterSeq) => assertValidCursor(afterSeq);

/// 持久 payload 必须可 JSON 序列化：对 dynamic 载荷做编码校验，
/// 类型化结构由类型系统保证。
void assertJsonSerializable(Object? value) {
  dynamic dynamicPayload;
  if (value is CustomEntry) {
    dynamicPayload = value.data;
  } else if (value is RunIntent) {
    dynamicPayload = value.resumeData;
  } else if (value is UsageRecord) {
    dynamicPayload = value.details;
  } else if (value is StepAttemptRecord ||
      value is ToolStartedRecord ||
      value is WriteDeferredRecord) {
    dynamicPayload = null;
  } else if (value != null) {
    dynamicPayload = value;
  }
  if (dynamicPayload == null) {
    return;
  }
  try {
    jsonEncode(dynamicPayload);
  } catch (e) {
    throw SessionError(
      SessionErrorCode.invalidPayload,
      'Durable payload is not serializable: $e',
    );
  }
}

/// 会话：SessionTree 视图 + 存储写通道。
class Session implements SessionTree {
  Session(this.storage, {IdGenerator? idGenerator})
    : idGenerator = idGenerator ?? (() => uuidv7());

  final SessionStorage storage;
  final IdGenerator idGenerator;

  Future<SessionMetadata> getMetadata() => storage.getMetadata();

  /// 指定 lane 的树视图。
  SessionTree view(String lane) {
    if (lane == 'main') {
      return this;
    }
    return _LaneSessionView(this, lane);
  }

  @override
  Future<String?> getLeafId() => _getLeafIdForLane('main');

  @override
  Future<SessionEntry?> getEntry(String id) => storage.getEntry(id);

  @override
  Future<SessionStats> getStats() => storage.getStats();

  @override
  Future<String?> getName() => storage.getName();

  @override
  Future<void> setName(String? name) => storage.setName(name);

  @override
  Future<String?> getLabel(String targetId) => storage.getLabel(targetId);

  @override
  Future<void> setLabel(String targetId, String? label) =>
      storage.setLabel(targetId, label);

  @override
  Future<List<SessionEntry>> findEntries([EntryQuery? query]) {
    return _queryEntries(query);
  }

  @override
  Future<SessionEntry?> findEntry([EntryQuery? query]) async {
    final results = await _queryEntries(query, 1);
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<List<SessionEntry>> findEntriesOnBranch([
    EntryQuery? query,
    BranchBounds? bounds,
  ]) {
    return _queryBranchEntries('main', query, bounds);
  }

  @override
  Future<SessionEntry?> findEntryOnBranch([
    EntryQuery? query,
    BranchBounds? bounds,
  ]) async {
    final results = await _queryBranchEntries('main', query, bounds, 1);
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<String> appendMessage(AgentMessage message) {
    return _appendMessageToLane('main', message);
  }

  @override
  Future<String> appendCustomEntry(String customType, [dynamic data]) {
    return _appendCustomEntryToLane('main', customType, data);
  }

  Future<List<LanePointer>> getLanes() => storage.getLanes();

  Future<void> createLane(String lane, String? at) =>
      storage.createLane(lane, at);

  Future<void> moveLane(String lane, String? to) => storage.moveLane(lane, to);

  Future<SessionEntry> appendEntry(ProvisionedEntry entry, String lane) =>
      _commitEntry(entry, lane);

  Future<LaneRecord> appendRecord(NewRecord record) => _commitRecord(record);

  Future<List<LaneRecord>> findRecords([RecordQuery? query]) {
    final q = query ?? const RecordQuery();
    _assertValidLimit(q.limit);
    _assertValidCursor(q.afterSeq);
    _assertValidCursor(q.cursor?.afterSeq);
    if (q.operationKind != null && q.type != 'operation_started') {
      throw SessionError(
        SessionErrorCode.invalidQuery,
        'operationKind requires type "operation_started"',
      );
    }
    return storage.findRecords(q);
  }

  Future<List<OperationStartedRecord>> findOpenOperations(
    String lane, {
    int? limit,
  }) {
    _assertValidLimit(limit);
    return storage.findOpenOperations(lane, limit: limit);
  }

  Future<List<LogItem>> getLog([LogOptions? options]) {
    final o = options ?? const LogOptions();
    _assertValidLimit(o.limit);
    _assertValidCursor(o.afterSeq);
    return storage.getLog(o);
  }

  /// 返回 lane 当前叶子；lane 不存在时抛错。
  Future<String?> _getLeafIdForLane(String lane) async {
    final pointer = (await getLanes())
        .where((candidate) => candidate.lane == lane)
        .firstOrNull;
    if (pointer == null) {
      throw SessionError(SessionErrorCode.invalidLane, 'Lane not found: $lane');
    }
    return pointer.leafId;
  }

  Future<List<SessionEntry>> _queryEntries(
    EntryQuery? query, [
    int? resultLimit,
  ]) async {
    final q = query ?? const EntryQuery();
    _assertValidLimit(q.limit);
    _assertValidCursor(q.cursor?.afterSeq);
    final effective = resultLimit == null || resultLimit == q.limit
        ? q
        : EntryQuery(
            type: q.type,
            customType: q.customType,
            order: q.order,
            limit: resultLimit,
            cursor: q.cursor,
          );
    return storage.findEntries(effective);
  }

  Future<List<SessionEntry>> _queryBranchEntries(
    String defaultLane, [
    EntryQuery? query,
    BranchBounds? bounds,
    int? resultLimit,
  ]) async {
    final q = query ?? const EntryQuery();
    final b = bounds ?? const BranchBounds();
    _assertValidLimit(q.limit);
    _assertValidCursor(q.cursor?.afterSeq);
    final start = b.start ?? await _getLeafIdForLane(defaultLane);
    if (start == null) {
      return const [];
    }
    final effective = resultLimit == null || resultLimit == q.limit
        ? q
        : EntryQuery(
            type: q.type,
            customType: q.customType,
            order: q.order,
            limit: resultLimit,
            cursor: q.cursor,
          );
    return storage.findEntriesOnBranch(effective, b, start: start);
  }

  Future<String> _appendMessageToLane(String lane, AgentMessage message) async {
    final entry = await _commitEntry(
      MessageEntry(id: idGenerator(), message: message),
      lane,
    );
    return entry.id;
  }

  Future<String> _appendCustomEntryToLane(
    String lane,
    String customType, [
    dynamic data,
  ]) async {
    final entry = await _commitEntry(
      CustomEntry(id: idGenerator(), customType: customType, data: data),
      lane,
    );
    return entry.id;
  }

  Future<SessionEntry> _commitEntry(ProvisionedEntry entry, String lane) {
    return storage.appendEntry(entry, lane);
  }

  Future<LaneRecord> _commitRecord(NewRecord record) {
    return storage.appendRecord(record);
  }
}

/// lane 视图。
class _LaneSessionView implements SessionTree {
  _LaneSessionView(this._session, this._lane);

  final Session _session;
  final String _lane;

  @override
  Future<String?> getLeafId() => _session._getLeafIdForLane(_lane);

  @override
  Future<SessionEntry?> getEntry(String id) => _session.getEntry(id);

  @override
  Future<SessionStats> getStats() => _session.getStats();

  @override
  Future<String?> getName() => _session.getName();

  @override
  Future<void> setName(String? name) => _session.setName(name);

  @override
  Future<String?> getLabel(String targetId) => _session.getLabel(targetId);

  @override
  Future<void> setLabel(String targetId, String? label) =>
      _session.setLabel(targetId, label);

  @override
  Future<List<SessionEntry>> findEntries([EntryQuery? query]) =>
      _session.findEntries(query);

  @override
  Future<SessionEntry?> findEntry([EntryQuery? query]) =>
      _session.findEntry(query);

  @override
  Future<List<SessionEntry>> findEntriesOnBranch([
    EntryQuery? query,
    BranchBounds? bounds,
  ]) => _session._queryBranchEntries(_lane, query, bounds);

  @override
  Future<SessionEntry?> findEntryOnBranch([
    EntryQuery? query,
    BranchBounds? bounds,
  ]) async {
    final results = await _session._queryBranchEntries(_lane, query, bounds, 1);
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<String> appendMessage(AgentMessage message) =>
      _session._appendMessageToLane(_lane, message);

  @override
  Future<String> appendCustomEntry(String customType, [dynamic data]) =>
      _session._appendCustomEntryToLane(_lane, customType, data);
}
