import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart' as p;

import '../../../../core/utils/app_logger.dart';
import '../../agent_types.dart';
import 'session.dart';

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
        '${jsonEncode({'op': 'header', ..._metadataJson(metadata)})}\n',
      );
    }
    return JsonlSessionStorage(file, metadata);
  }

  static Map<String, dynamic> _metadataJson(SessionMetadata metadata) => {
    'id': metadata.id,
    'createdAt': metadata.createdAt,
    'parentSessionId': metadata.parentSessionId,
  };

  void _replay() {
    if (!file.existsSync()) {
      return;
    }
    final lines = file.readAsLinesSync();
    for (final line in lines) {
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
    file.writeAsStringSync('${jsonEncode(json)}\n', mode: io.FileMode.append);
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
    if (entry is ActiveToolsEntry)
      'activeToolNames': entry.activeToolNames,
    if (entry is CompactionEntry) ...{
      'summary': entry.summary,
      'tokensBefore': entry.tokensBefore,
      'retainedTail': [
        for (final message in entry.retainedTail) encodeMessage(message),
      ],
    },
    if (entry is BranchSummaryEntry) ...{
      'fromId': entry.fromId,
      'summary': entry.summary,
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
        return CompactionEntry(
          id: id,
          summary: json['summary'] as String? ?? '',
          retainedTail: [
            for (final m in json['retainedTail'] as List? ?? [])
              if (decodeMessage(m) != null) decodeMessage(m)!,
          ],
          tokensBefore: (json['tokensBefore'] as num?)?.toInt() ?? 0,
          seq: seq,
          parentId: parentId,
          timestamp: timestamp,
        );
      case 'branch_summary':
        return BranchSummaryEntry(
          id: id,
          fromId: json['fromId'] as String? ?? '',
          summary: json['summary'] as String? ?? '',
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
    _state.applyMutation(RecordMutation(record: record));
    _append({'op': 'record', 'record': _encodeRecord(record)});
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

  // -- 记录编解码（只持久化恢复所需子集） ---------------------------------

  Map<String, dynamic> _encodeRecord(LaneRecord record) => {
    'type': record.type,
    'id': record.id,
    'seq': record.seq,
    'lane': record.lane,
    'timestamp': record.timestamp,
  };

  LaneRecord? _decodeRecord(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final type = json['type'] as String?;
    switch (type) {
      case 'operation_started':
        return OperationStartedRecord(
          id: json['id'] as String? ?? '',
          lane: json['lane'] as String? ?? 'main',
          sourceLeafId: json['sourceLeafId'] as String?,
          intent: const RunIntent(kind: RunIntentKind.run),
          seq: (json['seq'] as num?)?.toInt() ?? 0,
          timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        );
      case 'operation_finished':
        return OperationFinishedRecord(
          id: json['id'] as String? ?? '',
          lane: json['lane'] as String? ?? 'main',
          runId: json['runId'] as String? ?? '',
          outcome: OperationOutcomeKind.completed,
          seq: (json['seq'] as num?)?.toInt() ?? 0,
          timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        );
      default:
        // 其余记录类型与恢复无关，不持久化/不重放。
        return null;
    }
  }
}

/// 消息编解码（JSONL 友好子集，含 custom/summary 角色）。
Map<String, dynamic> encodeMessage(AgentMessage message) {
  if (message is UserMessage) {
    return {
      'role': 'user',
      'text': message.text,
      'images': [
        for (final image in message.images)
          {'mimeType': image.source.mimeType, 'base64': image.source.base64Data},
      ],
      'timestamp': message.timestamp,
    };
  }
  if (message is AssistantMessage) {
    return {
      'role': 'assistant',
      'text': message.text,
      'thinking': [
        for (final block in message.content)
          if (block is AssistantThinkingContent) block.thinking,
      ],
      'toolCalls': [
        for (final call in message.toolCalls)
          {'id': call.id, 'name': call.name, 'arguments': call.arguments},
      ],
      'stopReason': message.stopReason.name,
      'errorMessage': message.errorMessage,
      'usage': message.usage?.toJson(),
      'provider': message.provider,
      'model': message.model,
      'timestamp': message.timestamp,
    };
  }
  if (message is ToolResultMessage) {
    return {
      'role': 'toolResult',
      'toolCallId': message.toolCallId,
      'toolName': message.toolName,
      'content': message.text,
      'isError': message.isError,
      'timestamp': message.timestamp,
    };
  }
  return {'role': message.role, 'timestamp': message.timestamp};
}

AgentMessage? decodeMessage(Object? json) {
  if (json is! Map<String, dynamic>) {
    return null;
  }
  final role = json['role'] as String?;
  final timestamp = (json['timestamp'] as num?)?.toInt() ??
      DateTime.now().millisecondsSinceEpoch;
  switch (role) {
    case 'user':
      final content = <UserContent>[
        if (json['text'] case final String text when text.isNotEmpty)
          UserTextContent(text),
        for (final imageJson in json['images'] as List? ?? [])
          if (imageJson is Map<String, dynamic> &&
              imageJson['mimeType'] is String &&
              imageJson['base64'] is String)
            UserImageContent(
              ImageContent(
                source: ImageSource.base64(
                  mimeType: imageJson['mimeType'] as String,
                  base64Data: imageJson['base64'] as String,
                ),
              ),
            ),
      ];
      return UserMessage(content: content, timestamp: timestamp);
    case 'assistant':
      final calls = json['toolCalls'];
      final usageJson = json['usage'];
      return AssistantMessage(
        content: [
          if (json['text'] case final String text when text.isNotEmpty)
            AssistantTextContent(text),
          if (calls is List)
            for (final call in calls)
              if (call is Map<String, dynamic>)
                ToolCallContent(
                  id: call['id'] as String? ?? '',
                  name: call['name'] as String? ?? '',
                  arguments: call['arguments'] is Map<String, dynamic>
                      ? call['arguments'] as Map<String, dynamic>
                      : const {},
                ),
        ],
        stopReason: StopReason.values.firstWhere(
          (r) => r.name == json['stopReason'],
          orElse: () => StopReason.stop,
        ),
        errorMessage: json['errorMessage'] as String?,
        usage: usageJson is Map<String, dynamic>
            ? Usage(
                input: (usageJson['input'] as num?)?.toInt() ?? 0,
                output: (usageJson['output'] as num?)?.toInt() ?? 0,
                cacheRead: (usageJson['cacheRead'] as num?)?.toInt() ?? 0,
                cacheWrite: (usageJson['cacheWrite'] as num?)?.toInt() ?? 0,
                totalTokens: (usageJson['totalTokens'] as num?)?.toInt() ?? 0,
              )
            : null,
        provider: json['provider'] as String?,
        model: json['model'] as String?,
        timestamp: timestamp,
      );
    case 'toolResult':
      return ToolResultMessage(
        toolCallId: json['toolCallId'] as String? ?? '',
        toolName: json['toolName'] as String? ?? '',
        content: [
          if (json['content'] case final String content
              when content.isNotEmpty)
            ToolResultTextContent(content),
        ],
        isError: json['isError'] as bool? ?? false,
        timestamp: timestamp,
      );
    default:
      return null;
  }
}

/// 会话仓库：目录内一 JSONL 一会话。
class JsonlSessionRepo implements SessionRepo {
  JsonlSessionRepo(this.baseDir);

  final io.Directory baseDir;

  io.File _fileFor(String id) => io.File(
    p.join(baseDir.path, 'agent_chat', 'sessions', '$id.jsonl'),
  );

  Future<List<(SessionMetadata, io.File)>> _listAll() async {
    final dir = io.Directory(p.join(baseDir.path, 'agent_chat', 'sessions'));
    if (!dir.existsSync()) {
      return const [];
    }
    final result = <(SessionMetadata, io.File)>[];
    final files = dir
        .listSync()
        .whereType<io.File>()
        .where((f) => f.path.endsWith('.jsonl'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final file in files.take(30)) {
      final metadata = _readHeader(file);
      if (metadata != null) {
        result.add((metadata, file));
      }
    }
    return result;
  }

  SessionMetadata? _readHeader(io.File file) {
    try {
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final json = jsonDecode(trimmed);
        if (json is Map<String, dynamic> && json['op'] == 'header') {
          return SessionMetadata(
            id: json['id'] as String? ?? '',
            createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
            parentSessionId: json['parentSessionId'] as String?,
          );
        }
        break;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Future<Session> create([SessionCreateOptions? options]) async {
    final o = options ?? const SessionCreateOptions();
    final id = o.id ?? _shortId();
    final file = _fileFor(id);
    if (file.existsSync()) {
      throw SessionError(
        SessionErrorCode.alreadyExists,
        'Session already exists: $id',
      );
    }
    final metadata = SessionMetadata(
      id: id,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      parentSessionId: o.parentSessionId,
    );
    final storage = await JsonlSessionStorage.create(file.path, metadata);
    return Session(storage);
  }

  @override
  Future<Session> open(SessionMetadata metadata) async {
    final file = _fileFor(metadata.id);
    if (!file.existsSync()) {
      throw SessionError(
        SessionErrorCode.notFound,
        'Session not found: ${metadata.id}',
      );
    }
    return Session(JsonlSessionStorage(file, metadata));
  }

  @override
  Future<List<SessionMetadata>> list() async {
    final all = await _listAll();
    return [for (final (metadata, _) in all) metadata];
  }

  /// 列出会话及 UI 列表名：优先 setName 持久化名，其次首条用户消息。
  Future<List<(SessionMetadata, String)>> listWithNames() async {
    final all = await _listAll();
    final result = <(SessionMetadata, String)>[];
    for (final (metadata, file) in all) {
      final session = Session(JsonlSessionStorage(file, metadata));
      var name = '';
      try {
        name = (await session.getName())?.trim() ?? '';
      } catch (_) {
        name = '';
      }
      if (name.isEmpty) {
        final firstUser = await session.findEntry(
          const EntryQuery(type: 'message'),
        );
        if (firstUser is MessageEntry && firstUser.message is UserMessage) {
          final text = (firstUser.message as UserMessage).text
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (text.isNotEmpty) {
            name = text.length <= 40 ? text : '${text.substring(0, 40)}…';
          }
        }
      }
      result.add((metadata, name));
    }
    return result;
  }

  @override
  Future<void> delete(SessionMetadata metadata) async {
    final file = _fileFor(metadata.id);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  /// 按 id 直接删除会话文件（存在才删；容忍任何元数据解析问题）。
  void deleteById(String sessionId) {
    try {
      final file = _fileFor(sessionId);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      AppLogger.w('delete session by id failed: $e', 'AgentChat');
    }
  }

  @override
  Future<Session> fork(
    SessionMetadata source, [
    ForkOptions? options,
  ]) async {
    final sourceFile = _fileFor(source.id);
    if (!sourceFile.existsSync()) {
      throw SessionError(
        SessionErrorCode.notFound,
        'Session not found: ${source.id}',
      );
    }
    final sourceSession = Session(
      JsonlSessionStorage(sourceFile, source),
    );
    final id = _shortId();
    final metadata = SessionMetadata(
      id: id,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      parentSessionId: source.id,
    );
    final newFile = _fileFor(id);
    final storage = await JsonlSessionStorage.create(newFile.path, metadata);
    final newSession = Session(storage);
    // 复制 main 分支全部条目。
    final entries = await sourceSession.findEntriesOnBranch(
      const EntryQuery(order: EntryOrder.oldestFirst),
    );
    for (final entry in entries) {
      final copy = _cloneEntry(entry);
      copy.seq = 0;
      copy.parentId = null;
      copy.timestamp = 0;
      await newSession.appendEntry(copy, 'main');
    }
    return newSession;
  }

  SessionEntry _cloneEntry(SessionEntry entry) {
    final json = JsonlSessionStorage(newFileDummy, dummyMetadata)
        .encodeEntry(entry);
    return JsonlSessionStorage(newFileDummy, dummyMetadata).decodeEntry(json)!;
  }

  static final io.File newFileDummy = io.File('dummy');
  static const dummyMetadata = SessionMetadata(id: 'dummy', createdAt: 0);
}

String _shortId() => DateTime.now().millisecondsSinceEpoch
    .toRadixString(36)
    .padLeft(8, '0')
    .substring(0, 8) +
    (DateTime.now().microsecondsSinceEpoch % 1000).toString().padLeft(3, '0');
