import '../../agent_types.dart';
import 'session.dart';

// ---------------------------------------------------------------------------
// 错误
// ---------------------------------------------------------------------------

enum SessionErrorCode {
  notFound,
  alreadyExists,
  invalidEntry,
  invalidPayload,
  invalidLane,
  invalidQuery,
  invalidForkTarget,
  storage,
}

class SessionError implements Exception {
  SessionError(this.code, this.message);

  final SessionErrorCode code;
  final String message;

  @override
  String toString() => 'SessionError($code): $message';
}

// ---------------------------------------------------------------------------
// Entry（追加式树条目）
// ---------------------------------------------------------------------------

/// 会话条目基类。seq/parentId/timestamp 由存储侧赋值。
sealed class SessionEntry {
  SessionEntry({
    required this.id,
    this.seq = 0,
    this.parentId,
    this.timestamp = 0,
  });

  String get type;

  final String id;

  /// 共享序列号（读侧，存储赋值）。
  int seq;

  /// 存储赋值：追加 lane 的叶子。
  String? parentId;

  /// Unix 毫秒（存储赋值）。
  int timestamp;
}

class MessageEntry extends SessionEntry {
  MessageEntry({
    required super.id,
    required this.message,
    this.terminate,
    super.seq,
    super.parentId,
    super.timestamp,
  });

  @override
  String get type => 'message';

  AgentMessage message;
  bool? terminate;
}

class ModelChangeEntry extends SessionEntry {
  ModelChangeEntry({
    required super.id,
    required this.provider,
    required this.modelId,
    super.seq,
    super.parentId,
    super.timestamp,
  });

  @override
  String get type => 'model_change';

  final String provider;
  final String modelId;
}

class ThinkingLevelEntry extends SessionEntry {
  ThinkingLevelEntry({
    required super.id,
    required this.thinkingLevel,
    super.seq,
    super.parentId,
    super.timestamp,
  });

  @override
  String get type => 'thinking_level_change';

  final String thinkingLevel;
}

class ActiveToolsEntry extends SessionEntry {
  ActiveToolsEntry({
    required super.id,
    required this.activeToolNames,
    super.seq,
    super.parentId,
    super.timestamp,
  });

  @override
  String get type => 'active_tools_change';

  final List<String> activeToolNames;
}

class CompactionEntry extends SessionEntry {
  CompactionEntry({
    required super.id,
    required this.summary,
    required this.retainedTail,
    required this.tokensBefore,
    this.details,
    this.usage,
    super.seq,
    super.parentId,
    super.timestamp,
  });

  @override
  String get type => 'compaction';

  final String summary;

  /// compaction 后保留的近期消息，直接存于条目。
  final List<AgentMessage> retainedTail;
  final int tokensBefore;
  final dynamic details;
  final Usage? usage;
}

class BranchSummaryEntry extends SessionEntry {
  BranchSummaryEntry({
    required super.id,
    required this.fromId,
    required this.summary,
    this.details,
    this.usage,
    super.seq,
    super.parentId,
    super.timestamp,
  });

  @override
  String get type => 'branch_summary';

  final String fromId;
  final String summary;
  final dynamic details;
  final Usage? usage;
}

class CustomEntry extends SessionEntry {
  CustomEntry({
    required super.id,
    required this.customType,
    this.data,
    super.seq,
    super.parentId,
    super.timestamp,
  });

  @override
  String get type => 'custom';

  final String customType;
  final dynamic data;
}

/// ProvisionedEntry：省略 parentId/seq/timestamp 的待写入条目
/// （Dart 中以默认值表达"未赋值"，存储侧覆写）。
typedef ProvisionedEntry = SessionEntry;

// ---------------------------------------------------------------------------
// 记录（LaneRecord）
// ---------------------------------------------------------------------------

/// 记录基类。seq/lane/timestamp 由存储侧赋值。
sealed class LaneRecord {
  LaneRecord({
    required this.id,
    required this.lane,
    this.seq = 0,
    this.timestamp = 0,
  });

  String get type;

  final String id;
  final String lane;
  int seq;
  int timestamp;
}

enum RunIntentKind { run, compaction, navigation }

class RunIntent {
  const RunIntent({
    required this.kind,
    this.originalPrompt = const [],
    this.initialMessages = const [],
    this.systemPromptOverride,
    this.resumeData,
    this.customInstructions,
    this.resultEntryId,
    this.targetId,
    this.summarize,
    this.label,
    this.summaryEntryId,
  });

  final RunIntentKind kind;

  /// run：before_run 之前归一化的调用方输入。
  final List<AgentMessage> originalPrompt;

  /// run：捕获的 nextRun 项 + prompt + before_run 注入。
  final List<ProvisionedEntry> initialMessages;
  final String? systemPromptOverride;
  final Map<String, dynamic>? resumeData;

  /// compaction。
  final String? customInstructions;
  final String? resultEntryId;

  /// navigation。
  final String? targetId;
  final bool? summarize;
  final String? label;
  final String? summaryEntryId;
}

class OperationStartedRecord extends LaneRecord {
  OperationStartedRecord({
    required super.id,
    required super.lane,
    required this.sourceLeafId,
    required this.intent,
    super.seq,
    super.timestamp,
  });

  @override
  String get type => 'operation_started';

  final String? sourceLeafId;
  final RunIntent intent;
}

class AbortRequestedRecord extends LaneRecord {
  AbortRequestedRecord({
    required super.id,
    required super.lane,
    required this.runId,
    super.seq,
    super.timestamp,
  });

  @override
  String get type => 'abort_requested';

  final String runId;
}

enum OperationOutcomeKind { completed, aborted, failed, declined }

class OperationFinishedRecord extends LaneRecord {
  OperationFinishedRecord({
    required super.id,
    required super.lane,
    required this.runId,
    required this.outcome,
    this.error,
    super.seq,
    super.timestamp,
  });

  @override
  String get type => 'operation_finished';

  final String runId;
  final OperationOutcomeKind outcome;
  final ({String code, String message})? error;
}

enum CompactionReason { manual, threshold, overflow }

class StepAttemptRecord extends LaneRecord {
  StepAttemptRecord({
    required super.id,
    required super.lane,
    required this.runId,
    required this.step,
    required this.attempt,
    required this.resultEntryId,
    this.compactionReason,
    super.seq,
    super.timestamp,
  });

  @override
  String get type => 'step_attempt';

  final String runId;

  /// assistant / branch_summary / compaction。
  final String step;
  final int attempt;
  final String resultEntryId;
  final CompactionReason? compactionReason;
}

enum ReplayMode { never, safe }

class ToolStartedRecord extends LaneRecord {
  ToolStartedRecord({
    required super.id,
    required super.lane,
    required this.runId,
    required this.assistantEntryId,
    required this.toolIndex,
    required this.toolCallId,
    required this.toolName,
    required this.effectiveArgs,
    required this.resultEntryId,
    required this.replay,
    super.seq,
    super.timestamp,
  });

  @override
  String get type => 'tool_started';

  final String runId;
  final String assistantEntryId;
  final int toolIndex;
  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> effectiveArgs;
  final String resultEntryId;
  final ReplayMode replay;
}

enum QueueKind { steer, followUp, nextRun }

class QueueEnqueuedRecord extends LaneRecord {
  QueueEnqueuedRecord({
    required super.id,
    required super.lane,
    required this.queue,
    required this.target,
    this.runId,
    super.seq,
    super.timestamp,
  });

  @override
  String get type => 'queue_enqueued';

  final QueueKind queue;
  final ProvisionedEntry target;
  final String? runId;
}

class QueueCancelledRecord extends LaneRecord {
  QueueCancelledRecord({
    required super.id,
    required super.lane,
    required this.entryId,
    this.runId,
    super.seq,
    super.timestamp,
  });

  @override
  String get type => 'queue_cancelled';

  final String entryId;
  final String? runId;
}

class WriteDeferredRecord extends LaneRecord {
  WriteDeferredRecord({
    required super.id,
    required super.lane,
    required this.runId,
    required this.target,
    super.seq,
    super.timestamp,
  });

  @override
  String get type => 'write_deferred';

  final String runId;
  final ProvisionedEntry target;
}

enum UsageCause {
  assistant,
  compaction,
  branchSummary,
  deferredFetch,
  tool,
  hook,
  adjustment,
}

class UsageRecord extends LaneRecord {
  UsageRecord({
    required super.id,
    required super.lane,
    required this.usage,
    required this.cause,
    this.runId,
    this.entryId,
    this.attempt,
    this.stopReason,
    this.toolCallId,
    this.details,
    super.seq,
    super.timestamp,
  });

  @override
  String get type => 'usage';

  final Usage usage;
  final UsageCause cause;
  final String? runId;
  final String? entryId;
  final int? attempt;

  /// assistant/compaction/branch_summary/deferred_fetch 时存在。
  final String? stopReason;
  final String? toolCallId;
  final dynamic details;
}

/// NewRecord：省略 seq/timestamp 的待写入记录。
typedef NewRecord = LaneRecord;

// ---------------------------------------------------------------------------
// 查询
// ---------------------------------------------------------------------------

enum EntryOrder { newestFirst, oldestFirst }

class EntryCursor {
  const EntryCursor({required this.afterSeq});

  final int afterSeq;
}

class EntryQuery {
  const EntryQuery({
    this.type,
    this.customType,
    this.order,
    this.limit,
    this.cursor,
  });

  final String? type;
  final String? customType;
  final EntryOrder? order;
  final int? limit;
  final EntryCursor? cursor;
}

/// 分支扫描边界。默认：整个路径，叶到根。
class BranchBounds {
  const BranchBounds({this.start, this.stopAtType, this.stopAtId});

  final String? start;
  final String? stopAtType;
  final String? stopAtId;
}

class RecordQuery {
  const RecordQuery({
    this.lane,
    this.type,
    this.runId,
    this.operationKind,
    this.afterSeq,
    this.cursor,
    this.order,
    this.limit,
  });

  final String? lane;
  final String? type;
  final String? runId;
  final RunIntentKind? operationKind;
  final int? afterSeq;

  /// Order-aware cursor. For newest-first queries this selects records with
  /// seq lower than [EntryCursor.afterSeq]. [afterSeq] keeps its legacy,
  /// always-forward semantics.
  final EntryCursor? cursor;
  final EntryOrder? order;
  final int? limit;
}

// ---------------------------------------------------------------------------
// 元数据 / 统计 / 日志
// ---------------------------------------------------------------------------

class SessionMetadata {
  const SessionMetadata({
    required this.id,
    required this.createdAt,
    this.parentSessionId,
  });

  final String id;
  final int createdAt;
  final String? parentSessionId;
}

class SessionStats {
  SessionStats({
    this.messageCount = 0,
    this.cachedTokens = 0,
    this.uncachedTokens = 0,
    this.totalTokens = 0,
    this.costTotal = 0,
  });

  int messageCount;
  int cachedTokens;
  int uncachedTokens;
  int totalTokens;
  double costTotal;

  SessionStats copy() => SessionStats(
    messageCount: messageCount,
    cachedTokens: cachedTokens,
    uncachedTokens: uncachedTokens,
    totalTokens: totalTokens,
    costTotal: costTotal,
  );
}

class LanePointer {
  const LanePointer({required this.lane, required this.leafId});

  final String lane;
  final String? leafId;
}

sealed class LogItem {
  const LogItem({required this.seq});

  final int seq;
}

class LogEntryItem extends LogItem {
  const LogEntryItem({required super.seq, required this.entry});

  final SessionEntry entry;
}

class LogRecordItem extends LogItem {
  const LogRecordItem({required super.seq, required this.record});

  final LaneRecord record;
}

class LogLaneItem extends LogItem {
  const LogLaneItem({
    required super.seq,
    required this.lane,
    required this.leafId,
  });

  final String lane;
  final String? leafId;
}

class LogNameFactItem extends LogItem {
  const LogNameFactItem({required super.seq, required this.name});

  final String? name;
}

class LogLabelFactItem extends LogItem {
  const LogLabelFactItem({
    required super.seq,
    required this.targetId,
    required this.label,
  });

  final String targetId;
  final String? label;
}

class LogOptions {
  const LogOptions({this.afterSeq, this.limit});

  final int? afterSeq;
  final int? limit;
}

// ---------------------------------------------------------------------------
// 存储与树接口
// ---------------------------------------------------------------------------

/// 会话存储契约。
abstract class SessionStorage {
  Future<SessionMetadata> getMetadata();

  // Lanes
  Future<List<LanePointer>> getLanes();
  Future<void> createLane(String lane, String? at);
  Future<void> moveLane(String lane, String? to);

  // Entries and Records
  Future<SessionEntry> appendEntry(ProvisionedEntry entry, String lane);
  Future<LaneRecord> appendRecord(NewRecord record);

  // Reads
  Future<SessionEntry?> getEntry(String id);
  Future<List<SessionEntry>> findEntries([EntryQuery? query]);
  Future<List<SessionEntry>> findEntriesOnBranch(
    EntryQuery query,
    BranchBounds bounds, {
    required String start,
  });
  Future<List<LaneRecord>> findRecords([RecordQuery? query]);

  /// 返回未完成的 operation_started（最新在前）。恢复语义用 limit: 2。
  Future<List<OperationStartedRecord>> findOpenOperations(
    String lane, {
    int? limit,
  });
  Future<List<LogItem>> getLog([LogOptions? options]);

  // Global facts
  Future<String?> getName();
  Future<void> setName(String? name);
  Future<String?> getLabel(String id);
  Future<void> setLabel(String id, String? label);
  Future<SessionStats> getStats();
}

/// 会话树视图契约。
abstract class SessionTree {
  Future<String?> getLeafId();
  Future<SessionEntry?> getEntry(String id);
  Future<SessionStats> getStats();

  Future<String?> getName();
  Future<void> setName(String? name);
  Future<String?> getLabel(String targetId);
  Future<void> setLabel(String targetId, String? label);

  Future<List<SessionEntry>> findEntries([EntryQuery? query]);
  Future<SessionEntry?> findEntry([EntryQuery? query]);

  Future<List<SessionEntry>> findEntriesOnBranch([
    EntryQuery? query,
    BranchBounds? bounds,
  ]);
  Future<SessionEntry?> findEntryOnBranch([
    EntryQuery? query,
    BranchBounds? bounds,
  ]);

  Future<String> appendMessage(AgentMessage message);
  Future<String> appendCustomEntry(String customType, [dynamic data]);
}

class SessionCreateOptions {
  const SessionCreateOptions({this.id, this.parentSessionId});

  final String? id;
  final String? parentSessionId;
}

class ForkOptions {
  const ForkOptions({this.scope, this.entryId, this.position});

  /// 'branch'（默认）或 'tree'。
  final String? scope;
  final String? entryId;

  /// 'before' | 'at'。
  final String? position;
}

/// 会话仓库契约。
abstract class SessionRepo {
  Future<Session> create([SessionCreateOptions? options]);
  Future<Session> open(SessionMetadata metadata);
  Future<List<SessionMetadata>> list();
  Future<void> delete(SessionMetadata metadata);
  Future<Session> fork(SessionMetadata source, [ForkOptions? options]);
}

/// 会话停止原因。
typedef SessionStopReason = StopReason;
