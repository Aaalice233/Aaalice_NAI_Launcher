import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart' as p;

import '../../../../utils/app_logger.dart';
import '../../../agent_types.dart';
import '../session.dart';
import 'session_jsonl_line_storage.dart';
import 'session_jsonl_protocol.dart';
import 'session_jsonl_storage.dart';

/// 会话仓库：目录内一 JSONL 一会话。
class JsonlSessionRepo implements SessionRepo {
  JsonlSessionRepo(this.baseDir);

  final io.Directory baseDir;

  io.File _fileFor(String id) =>
      io.File(p.join(baseDir.path, 'agent_chat', 'sessions', '$id.jsonl'));

  Future<List<(SessionMetadata, io.File)>> _listAll() async {
    final dir = io.Directory(p.join(baseDir.path, 'agent_chat', 'sessions'));
    if (!dir.existsSync()) {
      return const [];
    }
    final result = <(SessionMetadata, io.File)>[];
    final files =
        dir
            .listSync()
            .whereType<io.File>()
            .where((f) => f.path.endsWith('.jsonl'))
            .toList()
          ..sort(
            (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
          );
    for (final file in files) {
      final metadata = _readHeader(file);
      if (metadata != null) {
        result.add((metadata, file));
        if (result.length == 30) {
          break;
        }
      }
    }
    return result;
  }

  SessionMetadata? _readHeader(io.File file) {
    try {
      for (final line in SessionJsonlLineStorage(
        file,
      ).readCompleteLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final json = jsonDecode(trimmed);
        final metadata = SessionJsonlProtocol.decodeHeader(json);
        if (metadata != null) {
          return metadata;
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
  Future<List<(SessionMetadata, String, DateTime)>> listWithNames() async {
    final all = await _listAll();
    final result = <(SessionMetadata, String, DateTime)>[];
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
      result.add((metadata, name, file.lastModifiedSync()));
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
  Future<Session> fork(SessionMetadata source, [ForkOptions? options]) async {
    final sourceFile = _fileFor(source.id);
    if (!sourceFile.existsSync()) {
      throw SessionError(
        SessionErrorCode.notFound,
        'Session not found: ${source.id}',
      );
    }
    final sourceStorage = JsonlSessionStorage(sourceFile, source);
    final id = _shortId();
    final metadata = SessionMetadata(
      id: id,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      parentSessionId: source.id,
    );
    final newFile = _fileFor(id);
    final storage = await sourceStorage.fork(
      newFile.path,
      metadata,
      options ?? const ForkOptions(),
    );
    return Session(storage);
  }
}

String _shortId() =>
    DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .padLeft(8, '0')
        .substring(0, 8) +
    (DateTime.now().microsecondsSinceEpoch % 1000).toString().padLeft(3, '0');
