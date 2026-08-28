import 'dart:convert';
import 'dart:io';

import 'agent_chat_resource_reference.dart';
import 'agent_chat_resource_reference_codec.dart';

/// Persists unsent resource cards separately from the JSONL transcript.
final class AgentChatResourceDraftStore {
  AgentChatResourceDraftStore(this.file);

  static const int _schemaVersion = 1;
  final File file;
  Future<void> _operationTail = Future<void>.value();

  Future<List<AgentChatResourceReference>> load(String sessionId) {
    if (sessionId.isEmpty) return Future.value(const []);
    return _serialized(() async {
      final root = await _readRoot();
      final sessions = root['sessions'];
      if (sessions is! Map<String, dynamic>) return const [];
      final values = sessions[sessionId];
      if (values is! List) return const [];
      return [
        for (final value in values)
          if (value is Map<String, dynamic>)
            AgentChatResourceReferenceCodec.decodeJsonMap(value),
      ];
    });
  }

  Future<void> save(
    String sessionId,
    List<AgentChatResourceReference> references,
  ) {
    if (sessionId.isEmpty) return Future<void>.value();
    return _serialized(() async {
      final root = await _readRoot();
      final sessions = Map<String, dynamic>.from(
        root['sessions'] as Map<String, dynamic>? ?? const {},
      );
      if (references.isEmpty) {
        sessions.remove(sessionId);
      } else {
        sessions[sessionId] = [
          for (final reference in references)
            AgentChatResourceReferenceCodec.encodeJsonMap(reference),
        ];
      }
      await _atomicWrite({
        'schemaVersion': _schemaVersion,
        'sessions': sessions,
      });
    });
  }

  Future<void> deleteSession(String sessionId) {
    return _serialized(() async {
      final root = await _readRoot();
      final sessions = Map<String, dynamic>.from(
        root['sessions'] as Map<String, dynamic>? ?? const {},
      )..remove(sessionId);
      await _atomicWrite({
        'schemaVersion': _schemaVersion,
        'sessions': sessions,
      });
    });
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _operationTail.then((_) => operation());
    _operationTail = result.then<void>((_) {}, onError: (_, __) {});
    return result;
  }

  Future<Map<String, dynamic>> _readRoot() async {
    await _recoverInterruptedWrite();
    if (!await file.exists()) {
      return <String, dynamic>{
        'schemaVersion': _schemaVersion,
        'sessions': <String, dynamic>{},
      };
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != _schemaVersion ||
        decoded['sessions'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid Agent resource draft store');
    }
    return decoded;
  }

  Future<void> _atomicWrite(Map<String, dynamic> value) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsString(jsonEncode(value), flush: true);
    if (await backup.exists()) await backup.delete();
    try {
      if (await file.exists()) await file.rename(backup.path);
      await temporary.rename(file.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _recoverInterruptedWrite() async {
    final temporary = File('${file.path}.tmp');
    final backup = File('${file.path}.bak');
    if (!await file.exists()) {
      if (await temporary.exists()) {
        await temporary.rename(file.path);
      } else if (await backup.exists()) {
        await backup.rename(file.path);
      }
    }
    if (await file.exists()) {
      if (await temporary.exists()) await temporary.delete();
      if (await backup.exists()) await backup.delete();
    }
  }
}
