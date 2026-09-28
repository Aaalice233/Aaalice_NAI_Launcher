import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/session/session.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';
import 'package:nai_launcher/core/agent/harness/session/session_types.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_session_summary_cache.dart';

void main() {
  late Directory tmp;
  late JsonlSessionRepo repo;
  late List<String> opened;
  late AgentChatSessionSummaryCache cache;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('session_summary_cache');
    repo = JsonlSessionRepo(Directory(tmp.path));
    opened = [];
    cache = AgentChatSessionSummaryCache(
      repository: repo,
      openSession: (SessionMetadata metadata) {
        opened.add(metadata.id);
        return repo.open(metadata);
      },
    );
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  File fileFor(String id) => File(
    '${tmp.path}${Platform.pathSeparator}agent_chat'
    '${Platform.pathSeparator}sessions${Platform.pathSeparator}$id.jsonl',
  );

  Future<String> createSession(String text) async {
    final session = await repo.create();
    if (text.isNotEmpty) {
      await session.appendMessage(UserMessage.text(text));
    }
    return (await session.getMetadata()).id;
  }

  group('AgentChatSessionSummaryCache', () {
    test('replays each session once, then reuses unchanged names', () async {
      final first = await createSession('hello there');
      final second = await createSession('another thread');

      final initial = await cache.list();
      expect(
        {for (final item in initial) item.id: item.name},
        {first: 'hello there', second: 'another thread'},
      );
      expect(opened.toSet(), {first, second});

      opened.clear();
      final repeated = await cache.list();
      expect(
        {for (final item in repeated) item.id: item.name},
        {first: 'hello there', second: 'another thread'},
      );
      expect(opened, isEmpty);
    });

    test('a persisted name wins over the first user message', () async {
      final id = await createSession('first message text');
      final session = await repo.open(
        (await repo.list()).firstWhere((item) => item.id == id),
      );
      await session.setName('custom name');

      final summaries = await cache.list();
      expect(summaries.single.name, 'custom name');
    });

    test('a long first user message is truncated', () async {
      final text = List.filled(20, 'lorem').join(' ');
      final id = await createSession(text);

      final summaries = await cache.list();
      expect(summaries.single.id, id);
      expect(summaries.single.name, '${text.substring(0, 40)}…');
    });

    test('an unnamed empty session lists without a name', () async {
      await createSession('');
      final summaries = await cache.list();
      expect(summaries.single.name, '');
    });

    test('only the appended session is replayed again', () async {
      final busy = await createSession('busy session');
      final idle = await createSession('idle session');
      final session = await repo.open(
        (await repo.list()).firstWhere((item) => item.id == busy),
      );
      await session.setName('busy session');
      await cache.list();
      opened.clear();

      await session.appendMessage(UserMessage.text('one more turn'));

      final summaries = await cache.list();
      expect(opened, [busy]);
      expect(
        {for (final item in summaries) item.id: item.name},
        {busy: 'busy session', idle: 'idle session'},
      );
    });

    test('a rename invalidates only the renamed session', () async {
      final renamed = await createSession('before rename');
      final untouched = await createSession('untouched');
      await cache.list();
      opened.clear();

      final session = await repo.open(
        (await repo.list()).firstWhere((item) => item.id == renamed),
      );
      await session.setName('after rename');

      final summaries = await cache.list();
      expect(opened, [renamed]);
      expect(
        {for (final item in summaries) item.id: item.name},
        {renamed: 'after rename', untouched: 'untouched'},
      );
    });

    test('a size change invalidates even when the timestamp is kept', () async {
      final id = await createSession('original text');
      await cache.list();
      opened.clear();
      final file = fileFor(id);
      final modifiedAt = file.lastModifiedSync();

      final session = await repo.open(
        (await repo.list()).firstWhere((item) => item.id == id),
      );
      await session.setName('renamed while frozen');
      await file.setLastModified(modifiedAt);

      final summaries = await cache.list();
      expect(opened, [id]);
      expect(summaries.single.name, 'renamed while frozen');
    });

    test('a timestamp change invalidates even when the size is kept', () async {
      final id = await createSession('external edit');
      await cache.list();
      opened.clear();
      final file = fileFor(id);
      final size = file.lengthSync();

      file.writeAsStringSync(file.readAsStringSync());
      await file.setLastModified(
        file.lastModifiedSync().add(const Duration(minutes: 5)),
      );
      expect(file.lengthSync(), size);

      await cache.list();
      expect(opened, [id]);
    });

    test('a deleted session drops out of the cache', () async {
      final kept = await createSession('kept');
      final removed = await createSession('removed');
      await cache.list();
      opened.clear();

      repo.deleteById(removed);
      final afterDelete = await cache.list();
      expect([for (final item in afterDelete) item.id], [kept]);
      expect(opened, isEmpty);

      final recreated = await createSession('recreated');
      final afterCreate = await cache.list();
      expect(opened, [recreated]);
      expect(
        {for (final item in afterCreate) item.id: item.name},
        {kept: 'kept', recreated: 'recreated'},
      );
    });

    test('updatedAt mirrors the listed file timestamp', () async {
      final id = await createSession('timestamped');
      final expected = DateTime(2026, 3, 4, 5, 6, 7);
      await fileFor(id).setLastModified(expected);

      final summaries = await cache.list();
      expect(
        summaries.single.updatedAt.millisecondsSinceEpoch,
        expected.millisecondsSinceEpoch,
      );
    });
  });
}
