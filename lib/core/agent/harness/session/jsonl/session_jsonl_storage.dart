import 'dart:convert';
import 'dart:io' as io;

import '../../../agent_types.dart';
import '../../compaction/compaction.dart';
import '../session.dart';
import 'session_jsonl_codec.dart';
import 'session_jsonl_line_storage.dart';
import 'session_jsonl_protocol.dart';

/// 基于 JSONL 文件的会话存储。
///
/// 记录形态：
/// - `{"op":"entry",...}`：条目
/// - `{"op":"record",...}`：运行记录
/// - `{"op":"lane",...}`：lane 指针
/// - `{"op":"fact",...}`：name/label 事实
/// - 头行 `{"op":"header",...}`
class JsonlSessionStorage implements SessionStorage {
  JsonlSessionStorage(this.file, this._metadata) {
    _replay();
  }

  final io.File file;
  final SessionMetadata _metadata;
  final SessionState _state = SessionState();

  static Future<JsonlSessionStorage> create(
    String path,
    SessionMetadata metadata,
  ) async {
    final file = io.File(path);
    await file.parent.create(recursive: true);
    if (!file.existsSync()) {
      await file.writeAsString(
        '${jsonEncode(SessionJsonlProtocol.encodeHeader(metadata))}\n',
      );
    }
    return JsonlSessionStorage(file, metadata);
  }

  Future<JsonlSessionStorage> fork(
    String path,
    SessionMetadata metadata,
    ForkOptions options,
  ) async {
    final mutations = _state.createForkMutations(options);
    final storage = await create(path, metadata);
    for (final mutation in mutations) {
      storage._applyForkMutation(mutation);
    }
    return storage;
  }

  void _replay() {
    for (final line in SessionJsonlLineStorage(file).readCompleteLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      try {
        final json = jsonDecode(trimmed);
        if (json is! Map<String, dynamic>) {
          continue;
        }
        _applyJson(json);
      } catch (_) {
        // 损坏行跳过。
      }
    }
  }

  void _applyJson(Map<String, dynamic> json) {
    switch (json['op']) {
      case 'entry':
        final entry = decodeEntry(json['entry']);
        if (entry != null) {
          _state.applyMutation(
            EntryMutation(entry: entry, lane: json['lane'] as String?),
          );
        }
      case 'record':
        final record = _decodeRecord(json['record']);
        if (record != null) {
          _state.applyMutation(RecordMutation(record: record));
        }
      case 'lane':
        _state.applyMutation(
          LaneMutation(
            seq: (json['seq'] as num).toInt(),
            lane: json['lane'] as String,
            leafId: json['leafId'] as String?,
          ),
        );
      case 'fact':
        if (json['fact'] == 'name') {
          _state.applyMutation(
            NameFactMutation(
              seq: (json['seq'] as num).toInt(),
              name: json['name'] as String?,
            ),
          );
        } else if (json['fact'] == 'label') {
          _state.applyMutation(
            LabelFactMutation(
              seq: (json['seq'] as num).toInt(),
              targetId: json['targetId'] as String,
              label: json['label'] as String?,
            ),
          );
        }
      default:
        break;
    }
  }

  void _append(Map<String, dynamic> json) {
    SessionJsonlLineStorage(file).appendJsonSync(json);
  }

  void _applyForkMutation(SessionMutation mutation) {
    _state.applyMutation(mutation);
    switch (mutation) {
      case EntryMutation():
        _append({
          'op': 'entry',
          if (mutation.lane != null) 'lane': mutation.lane,
          'entry': encodeEntry(mutation.entry),
        });
      case LaneMutation():
        _append({
          'op': 'lane',
          'seq': mutation.seq,
          'lane': mutation.lane,
          'leafId': mutation.leafId,
        });
      case NameFactMutation():
        _append({
          'op': 'fact',
          'seq': mutation.seq,
          'fact': 'name',
          'name': mutation.name,
        });
      case LabelFactMutation():
        _append({
          'op': 'fact',
          'seq': mutation.seq,
          'fact': 'label',
          'targetId': mutation.targetId,
          'label': mutation.label,
        });
      case RecordMutation():
        throw SessionError(
          SessionErrorCode.storage,
          'Fork mutations must not contain records',
        );
    }
  }

  // -- 编码 ---------------------------------------------------------------

  Map<String, dynamic> encodeEntry(SessionEntry entry) => {
    'type': entry.type,
    'id': entry.id,
    'seq': entry.seq,
    'parentId': entry.parentId,
    'timestamp': entry.timestamp,
    if (entry is MessageEntry)
      'message': encodeMessage(entry.message), // ignore: unnecessary_type_check
    if (entry is ModelChangeEntry) ...{
      'provider': entry.provider,
      'modelId': entry.modelId,
    },
    if (entry is ThinkingLevelEntry) 'thinkingLevel': entry.thinkingLevel,
    if (entry is ActiveToolsEntry) 'activeToolNames': entry.activeToolNames,
    if (entry is CompactionEntry) ...{
      'summary': entry.summary,
      'tokensBefore': entry.tokensBefore,
      'retainedTail': [
        for (final message in entry.retainedTail) encodeMessage(message),
      ],
      if (entry.details is CompactionDetails)
        'details': {
          'readFiles': (entry.details as CompactionDetails).readFiles,
          'modifiedFiles': (entry.details as CompactionDetails).modifiedFiles,
        },
      if (entry.usage != null) 'usage': entry.usage!.toJson(),
    },
    if (entry is BranchSummaryEntry) ...{
      'fromId': entry.fromId,
      'summary': entry.summary,
      'details': entry.details,
      if (entry.usage != null) 'usage': entry.usage!.toJson(),
    },
    if (entry is CustomEntry) ...{
      'customType': entry.customType,
      'data': entry.data,
    },
  };

  SessionEntry? decodeEntry(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final type = json['type'] as String?;
    final id = json['id'] as String? ?? '';
    final seq = (json['seq'] as num?)?.toInt() ?? 0;
    final parentId = json['parentId'] as String?;
    final timestamp = (json['timestamp'] as num?)?.toInt() ?? 0;
    switch (type) {
      case 'message':
        final message = decodeMessage(json['message']);
        if (message == null) {
          return null;
        }
        return MessageEntry(
          id: id,
          message: message,
          seq: seq,
          parentId: parentId,
          timestamp: timestamp,
        );
      case 'model_change':
        return ModelChangeEntry(
          id: id,
          provider: json['provider'] as String? ?? '',
          modelId: json['modelId'] as String? ?? '',
          seq: seq,
          parentId: parentId,
          timestamp: timestamp,
        );
      case 'thinking_level_change':
        return ThinkingLevelEntry(
          id: id,
          thinkingLevel: json['thinkingLevel'] as String? ?? 'off',
          seq: seq,
          parentId: parentId,
          timestamp: timestamp,
        );
      case 'active_tools_change':
        return ActiveToolsEntry(
          id: id,
          activeToolNames: [
            for (final name in json['activeToolNames'] as List? ?? [])
              name as String,
          ],
          seq: seq,
          parentId: parentId,
          timestamp: timestamp,
        );
      case 'compaction':
        final detailsJson = json['details'];
        return CompactionEntry(
          id: id,
          summary: json['summary'] as String? ?? '',
          retainedTail: [
            for (final m in json['retainedTail'] as List? ?? [])
              if (decodeMessage(m) != null) decodeMessage(m)!,
          ],
          tokensBefore: (json['tokensBefore'] as num?)?.toInt() ?? 0,
          details: detailsJson is Map<String, dynamic>
              ? CompactionDetails(
                  readFiles: _stringList(detailsJson['readFiles']),
                  modifiedFiles: _stringList(detailsJson['modifiedFiles']),
                )
              : null,
          usage: _decodeUsage(json['usage']),
          seq: seq,
          parentId: parentId,
          timestamp: timestamp,
        );
      case 'branch_summary':
        return BranchSummaryEntry(
          id: id,
          fromId: json['fromId'] as String? ?? '',
          summary: json['summary'] as String? ?? '',
          details: json['details'],
          usage: _decodeUsage(json['usage']),
          seq: seq,
          parentId: parentId,
          timestamp: timestamp,
        );
      case 'custom':
        return CustomEntry(
          id: id,
          customType: json['customType'] as String? ?? '',
          data: json['data'],
          seq: seq,
          parentId: parentId,
          timestamp: timestamp,
        );
      default:
        return null;
    }
  }

  // -- SessionStorage ------------------------------------------------------

  @override
  Future<SessionMetadata> getMetadata() async => _metadata;

  @override
  Future<List<LanePointer>> getLanes() async => _state.getLanes();

  @override
  Future<void> createLane(String lane, String? at) async {
    _state.validateNewLane(lane);
    _state.validateTarget(at);
    _state.applyMutation(
      LaneMutation(seq: _state.nextSequence, lane: lane, leafId: at),
    );
    _append({
      'op': 'lane',
      'seq': _state.nextSequence - 1,
      'lane': lane,
      'leafId': at,
    });
  }

  @override
  Future<void> moveLane(String lane, String? to) async {
    _state.requireLane(lane);
    _state.validateTarget(to);
    _state.applyMutation(
      LaneMutation(seq: _state.nextSequence, lane: lane, leafId: to),
    );
    _append({
      'op': 'lane',
      'seq': _state.nextSequence - 1,
      'lane': lane,
      'leafId': to,
    });
  }

  @override
  Future<SessionEntry> appendEntry(ProvisionedEntry entry, String lane) async {
    final parentId = _state.requireLane(lane);
    _state.validateUnusedId(entry.id);
    entry.parentId = parentId;
    entry.seq = _state.nextSequence;
    entry.timestamp = DateTime.now().millisecondsSinceEpoch;
    _state.applyMutation(EntryMutation(entry: entry, lane: lane));
    _append({'op': 'entry', 'lane': lane, 'entry': encodeEntry(entry)});
    return entry;
  }

  @override
  Future<LaneRecord> appendRecord(NewRecord record) async {
    _state.requireLane(record.lane);
    _state.validateUnusedId(record.id);
    final currentOpen = _state
        .findOpenOperations(record.lane, limit: 1)
        .firstOrNull;
    if (record is OperationStartedRecord && currentOpen != null) {
      throw SessionError(
        SessionErrorCode.storage,
        'Lane ${record.lane} already has an open operation ${currentOpen.id}',
      );
    }
    record.seq = _state.nextSequence;
    record.timestamp = DateTime.now().millisecondsSinceEpoch;
    final encodedRecord = _encodeRecord(record);
    jsonEncode(encodedRecord);
    _state.applyMutation(RecordMutation(record: record));
    _append({'op': 'record', 'record': encodedRecord});
    return record;
  }

  @override
  Future<SessionEntry?> getEntry(String id) async => _state.getEntry(id);

  @override
  Future<List<SessionEntry>> findEntries([EntryQuery? query]) async {
    return _state.findEntries(query);
  }

  @override
  Future<List<SessionEntry>> findEntriesOnBranch(
    EntryQuery query,
    BranchBounds bounds, {
    required String start,
  }) async {
    return _state.findEntriesOnBranch(query, bounds, start: start);
  }

  @override
  Future<List<LaneRecord>> findRecords([RecordQuery? query]) async {
    return _state.findRecords(query);
  }

  @override
  Future<List<OperationStartedRecord>> findOpenOperations(
    String lane, {
    int? limit,
  }) async {
    return _state.findOpenOperations(lane, limit: limit);
  }

  @override
  Future<List<LogItem>> getLog([LogOptions? options]) async {
    return _state.getLog(options);
  }

  @override
  Future<String?> getName() async => _state.getName();

  @override
  Future<void> setName(String? name) async {
    final seq = _state.nextSequence;
    _state.applyMutation(NameFactMutation(seq: seq, name: name));
    _append({'op': 'fact', 'seq': seq, 'fact': 'name', 'name': name});
  }

  @override
  Future<String?> getLabel(String id) async => _state.getLabel(id);

  @override
  Future<void> setLabel(String id, String? label) async {
    _state.validateTarget(id);
    final seq = _state.nextSequence;
    _state.applyMutation(
      LabelFactMutation(seq: seq, targetId: id, label: label),
    );
    _append({
      'op': 'fact',
      'seq': seq,
      'fact': 'label',
      'targetId': id,
      'label': label,
    });
  }

  @override
  Future<SessionStats> getStats() async => _state.getStats();

  // -- 记录编解码 ---------------------------------------------------------

  Map<String, dynamic> _encodeRecord(LaneRecord record) {
    final common = <String, dynamic>{
      'type': record.type,
      'id': record.id,
      'seq': record.seq,
      'lane': record.lane,
      'timestamp': record.timestamp,
    };
    if (record is OperationStartedRecord) {
      return {
        ...common,
        'sourceLeafId': record.sourceLeafId,
        'intent': _encodeRunIntent(record.intent),
      };
    }
    if (record is AbortRequestedRecord) {
      return {...common, 'runId': record.runId};
    }
    if (record is OperationFinishedRecord) {
      return {
        ...common,
        'runId': record.runId,
        'outcome': record.outcome.name,
        if (record.error != null)
          'error': {
            'code': record.error!.code,
            'message': record.error!.message,
          },
      };
    }
    if (record is StepAttemptRecord) {
      return {
        ...common,
        'runId': record.runId,
        'step': record.step,
        'attempt': record.attempt,
        'resultEntryId': record.resultEntryId,
        'compactionReason': record.compactionReason?.name,
      };
    }
    if (record is ToolStartedRecord) {
      return {
        ...common,
        'runId': record.runId,
        'assistantEntryId': record.assistantEntryId,
        'toolIndex': record.toolIndex,
        'toolCallId': record.toolCallId,
        'toolName': record.toolName,
        'effectiveArgs': record.effectiveArgs,
        'resultEntryId': record.resultEntryId,
        'replay': record.replay.name,
      };
    }
    if (record is QueueEnqueuedRecord) {
      return {
        ...common,
        'queue': record.queue.name,
        'target': encodeEntry(record.target),
        'runId': record.runId,
      };
    }
    if (record is QueueCancelledRecord) {
      return {...common, 'entryId': record.entryId, 'runId': record.runId};
    }
    if (record is WriteDeferredRecord) {
      return {
        ...common,
        'runId': record.runId,
        'target': encodeEntry(record.target),
      };
    }
    if (record is UsageRecord) {
      return {
        ...common,
        'usage': record.usage.toJson(),
        'cause': record.cause.name,
        'runId': record.runId,
        'entryId': record.entryId,
        'attempt': record.attempt,
        'stopReason': record.stopReason,
        'toolCallId': record.toolCallId,
        'details': record.details,
      };
    }
    throw SessionError(
      SessionErrorCode.invalidPayload,
      'Unsupported lane record type: ${record.runtimeType}',
    );
  }

  LaneRecord? _decodeRecord(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final type = json['type'] as String?;
    final id = json['id'] as String? ?? '';
    final lane = json['lane'] as String? ?? 'main';
    final seq = (json['seq'] as num?)?.toInt() ?? 0;
    final timestamp = (json['timestamp'] as num?)?.toInt() ?? 0;
    switch (type) {
      case 'operation_started':
        return OperationStartedRecord(
          id: id,
          lane: lane,
          sourceLeafId: json['sourceLeafId'] as String?,
          intent: _decodeRunIntent(json['intent']),
          seq: seq,
          timestamp: timestamp,
        );
      case 'abort_requested':
        return AbortRequestedRecord(
          id: id,
          lane: lane,
          runId: json['runId'] as String? ?? '',
          seq: seq,
          timestamp: timestamp,
        );
      case 'operation_finished':
        final errorJson = json['error'];
        return OperationFinishedRecord(
          id: id,
          lane: lane,
          runId: json['runId'] as String? ?? '',
          outcome: _enumByName(
            OperationOutcomeKind.values,
            json['outcome'],
            OperationOutcomeKind.failed,
          ),
          error: errorJson is Map<String, dynamic>
              ? (
                  code: errorJson['code'] as String? ?? '',
                  message: errorJson['message'] as String? ?? '',
                )
              : null,
          seq: seq,
          timestamp: timestamp,
        );
      case 'step_attempt':
        return StepAttemptRecord(
          id: id,
          lane: lane,
          runId: json['runId'] as String? ?? '',
          step: json['step'] as String? ?? '',
          attempt: (json['attempt'] as num?)?.toInt() ?? 0,
          resultEntryId: json['resultEntryId'] as String? ?? '',
          compactionReason: _nullableEnumByName(
            CompactionReason.values,
            json['compactionReason'],
          ),
          seq: seq,
          timestamp: timestamp,
        );
      case 'tool_started':
        return ToolStartedRecord(
          id: id,
          lane: lane,
          runId: json['runId'] as String? ?? '',
          assistantEntryId: json['assistantEntryId'] as String? ?? '',
          toolIndex: (json['toolIndex'] as num?)?.toInt() ?? 0,
          toolCallId: json['toolCallId'] as String? ?? '',
          toolName: json['toolName'] as String? ?? '',
          effectiveArgs:
              (json['effectiveArgs'] as Map?)?.cast<String, dynamic>() ??
              const {},
          resultEntryId: json['resultEntryId'] as String? ?? '',
          replay: _enumByName(
            ReplayMode.values,
            json['replay'],
            ReplayMode.never,
          ),
          seq: seq,
          timestamp: timestamp,
        );
      case 'queue_enqueued':
        return QueueEnqueuedRecord(
          id: id,
          lane: lane,
          queue: _enumByName(
            QueueKind.values,
            json['queue'],
            QueueKind.nextRun,
          ),
          target: _decodeRequiredEntry(json['target']),
          runId: json['runId'] as String?,
          seq: seq,
          timestamp: timestamp,
        );
      case 'queue_cancelled':
        return QueueCancelledRecord(
          id: id,
          lane: lane,
          entryId: json['entryId'] as String? ?? '',
          runId: json['runId'] as String?,
          seq: seq,
          timestamp: timestamp,
        );
      case 'write_deferred':
        return WriteDeferredRecord(
          id: id,
          lane: lane,
          runId: json['runId'] as String? ?? '',
          target: _decodeRequiredEntry(json['target']),
          seq: seq,
          timestamp: timestamp,
        );
      case 'usage':
        return UsageRecord(
          id: id,
          lane: lane,
          usage: _decodeUsage(json['usage']) ?? const Usage(),
          cause: _enumByName(
            UsageCause.values,
            json['cause'],
            UsageCause.adjustment,
          ),
          runId: json['runId'] as String?,
          entryId: json['entryId'] as String?,
          attempt: (json['attempt'] as num?)?.toInt(),
          stopReason: json['stopReason'] as String?,
          toolCallId: json['toolCallId'] as String?,
          details: json['details'],
          seq: seq,
          timestamp: timestamp,
        );
      default:
        return null;
    }
  }

  Map<String, dynamic> _encodeRunIntent(RunIntent intent) => {
    'kind': intent.kind.name,
    'originalPrompt': [
      for (final message in intent.originalPrompt) encodeMessage(message),
    ],
    'initialMessages': [
      for (final entry in intent.initialMessages) encodeEntry(entry),
    ],
    'systemPromptOverride': intent.systemPromptOverride,
    'resumeData': intent.resumeData,
    'customInstructions': intent.customInstructions,
    'resultEntryId': intent.resultEntryId,
    'targetId': intent.targetId,
    'summarize': intent.summarize,
    'label': intent.label,
    'summaryEntryId': intent.summaryEntryId,
  };

  RunIntent _decodeRunIntent(Object? value) {
    final json = value is Map<String, dynamic>
        ? value
        : const <String, dynamic>{};
    return RunIntent(
      kind: _enumByName(RunIntentKind.values, json['kind'], RunIntentKind.run),
      originalPrompt: [
        for (final item in json['originalPrompt'] as List? ?? const [])
          if (decodeMessage(item) case final message?) message,
      ],
      initialMessages: [
        for (final item in json['initialMessages'] as List? ?? const [])
          _decodeRequiredEntry(item),
      ],
      systemPromptOverride: json['systemPromptOverride'] as String?,
      resumeData: (json['resumeData'] as Map?)?.cast<String, dynamic>(),
      customInstructions: json['customInstructions'] as String?,
      resultEntryId: json['resultEntryId'] as String?,
      targetId: json['targetId'] as String?,
      summarize: json['summarize'] as bool?,
      label: json['label'] as String?,
      summaryEntryId: json['summaryEntryId'] as String?,
    );
  }

  SessionEntry _decodeRequiredEntry(Object? value) {
    final entry = decodeEntry(value);
    if (entry == null) {
      throw const FormatException('Invalid session entry in lane record');
    }
    return entry;
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    Object? name,
    T fallback,
  ) => values.firstWhere((value) => value.name == name, orElse: () => fallback);

  static T? _nullableEnumByName<T extends Enum>(List<T> values, Object? name) =>
      values.cast<T?>().firstWhere(
        (value) => value?.name == name,
        orElse: () => null,
      );

  static List<String> _stringList(Object? value) => [
    for (final item in value as List? ?? const [])
      if (item is String) item,
  ];

  static Usage? _decodeUsage(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }
    final costJson = value['cost'];
    return Usage(
      input: (value['input'] as num?)?.toInt() ?? 0,
      output: (value['output'] as num?)?.toInt() ?? 0,
      cacheRead: (value['cacheRead'] as num?)?.toInt() ?? 0,
      cacheWrite: (value['cacheWrite'] as num?)?.toInt() ?? 0,
      totalTokens: (value['totalTokens'] as num?)?.toInt() ?? 0,
      cost: costJson is Map<String, dynamic>
          ? Cost(
              input: (costJson['input'] as num?)?.toDouble() ?? 0,
              output: (costJson['output'] as num?)?.toDouble() ?? 0,
              cacheRead: (costJson['cacheRead'] as num?)?.toDouble() ?? 0,
              cacheWrite: (costJson['cacheWrite'] as num?)?.toDouble() ?? 0,
              total: (costJson['total'] as num?)?.toDouble() ?? 0,
            )
          : const Cost(),
    );
  }
}

/// Message codec retained as part of the public JSONL API.
Map<String, dynamic> encodeMessage(AgentMessage message) =>
    SessionJsonlCodec.encode(message);

AgentMessage? decodeMessage(Object? value) => SessionJsonlCodec.decode(value);
