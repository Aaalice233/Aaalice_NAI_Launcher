import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart' as p;

import '../../../../utils/app_logger.dart';
import '../session.dart';
import 'session_jsonl_line_storage.dart';
import 'session_jsonl_protocol.dart';
import 'session_jsonl_storage.dart';

/// 会话列表项：头行元数据加一次目录 stat 得到的文件信息。
typedef SessionFileInfo = ({
  SessionMetadata metadata,
  String path,
  DateTime modifiedAt,
  int size,
});

/// 会话仓库：目录内一 JSONL 一会话。
class JsonlSessionRepo implements SessionRepo {
  JsonlSessionRepo(this.baseDir);

  static const _listLimit = 30;

  final io.Directory baseDir;

  io.File _fileFor(String id) =>
      io.File(p.join(baseDir.path, 'agent_chat', 'sessions', '$id.jsonl'));

  Future<List<SessionFileInfo>> _listAll() async {
    final dir = io.Directory(p.join(baseDir.path, 'agent_chat', 'sessions'));
    if (!dir.existsSync()) {
      return const [];
    }
    final candidates =
        <(io.File, io.FileStat)>[
          for (final entity in dir.listSync())
            if (entity is io.File && entity.path.endsWith('.jsonl'))
              (entity, entity.statSync()),
        ]..sort((a, b) => b.$2.modified.compareTo(a.$2.modified));
    final result = <SessionFileInfo>[];
    for (final (file, stat) in candidates) {
      final metadata = _readHeader(file);
      if (metadata == null) {
        continue;
      }
      result.add((
        metadata: metadata,
        path: file.path,
        modifiedAt: stat.modified,
        size: stat.size,
      ));
      if (result.length == _listLimit) {
        break;
      }
    }
    return result;
  }

  SessionMetadata? _readHeader(io.File file) {
    try {
      final first = SessionJsonlLineStorage(
        file,
      ).readCompleteLinesSync(maxLines: 1);
      if (first.isEmpty || first.first.isEmpty) {
        return null;
      }
      return SessionJsonlProtocol.decodeHeader(jsonDecode(first.first));
    } catch (_) {
      return null;
    }
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
    return [for (final item in all) item.metadata];
  }

  /// 只读头行的列表：不打开会话正文，调用方据文件信息决定是否回放。
  Future<List<SessionFileInfo>> listWithFileInfo() => _listAll();

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
