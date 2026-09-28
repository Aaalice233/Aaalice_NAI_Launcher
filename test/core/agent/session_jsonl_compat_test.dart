import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/session/session.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';

void main() {
  group('Session JSONL compatibility', () {
    test('decodes legacy and structured thinking with usage', () {
      final legacy =
          decodeMessage({
                'role': 'assistant',
                'text': 'answer',
                'thinking': ['legacy thought'],
                'usage': {'input': 3, 'output': 2, 'totalTokens': 5},
                'stopReason': 'stop',
              })!
              as AssistantMessage;
      expect(
        legacy.content.whereType<AssistantThinkingContent>().single.thinking,
        'legacy thought',
      );
      expect(legacy.usage?.totalTokens, 5);

      final structured =
          decodeMessage({
                'role': 'assistant',
                'content': [
                  {'type': 'thinking', 'thinking': 'new thought'},
                  {'type': 'text', 'text': 'answer'},
                ],
                'usage': {
                  'input': 4,
                  'output': 6,
                  'totalTokens': 10,
                  'cost': {'total': 0.5},
                },
                'stopReason': 'stop',
              })!
              as AssistantMessage;
      expect(
        structured.content
            .whereType<AssistantThinkingContent>()
            .single
            .thinking,
        'new thought',
      );
      expect(structured.usage?.totalTokens, 10);
      expect(structured.usage?.cost.total, 0.5);

      final encoded = encodeMessage(structured);
      expect(encoded['content'], isA<List<dynamic>>());
      expect(encoded['thinking'], ['new thought']);
    });

    test('skips a damaged middle line and an incomplete tail', () async {
      final directory = await Directory.systemTemp.createTemp('session-jsonl-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}s.jsonl');
      final lines = [
        jsonEncode({'op': 'header', 'id': 's', 'createdAt': 1}),
        jsonEncode({'op': 'fact', 'seq': 1, 'fact': 'name', 'name': 'before'}),
        '{damaged middle',
        jsonEncode({'op': 'fact', 'seq': 2, 'fact': 'name', 'name': 'after'}),
      ];
      file.writeAsStringSync('${lines.join('\n')}\n{"op":"fact"');

      final storage = JsonlSessionStorage(
        file,
        const SessionMetadata(id: 's', createdAt: 1),
      );
      expect(await storage.getName(), 'after');
    });

    test('replays a complete final JSON record without a newline', () async {
      final directory = await Directory.systemTemp.createTemp('session-jsonl-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}s.jsonl');
      file.writeAsStringSync(
        '${jsonEncode({'op': 'header', 'id': 's', 'createdAt': 1})}\n'
        '${jsonEncode({'op': 'fact', 'seq': 1, 'fact': 'name', 'name': 'tail'})}',
      );

      final storage = JsonlSessionStorage(
        file,
        const SessionMetadata(id: 's', createdAt: 1),
      );

      expect(await storage.getName(), 'tail');
    });

    test('append preserves a complete final record without a newline', () async {
      final directory = await Directory.systemTemp.createTemp('session-jsonl-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}s.jsonl');
      file.writeAsStringSync(
        '${jsonEncode({'op': 'header', 'id': 's', 'createdAt': 1})}\n'
        '${jsonEncode({'op': 'fact', 'seq': 1, 'fact': 'name', 'name': 'tail'})}',
      );

      final storage = JsonlSessionStorage(
        file,
        const SessionMetadata(id: 's', createdAt: 1),
      );
      await storage.setName('appended');

      final records = file
          .readAsLinesSync()
          .map(jsonDecode)
          .whereType<Map<String, dynamic>>()
          .toList();
      expect(records, hasLength(3));
      expect(records[1]['name'], 'tail');
      expect(records[2]['name'], 'appended');
    });

    test('append removes a genuinely incomplete final record', () async {
      final directory = await Directory.systemTemp.createTemp('session-jsonl-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}s.jsonl');
      file.writeAsStringSync(
        '${jsonEncode({'op': 'header', 'id': 's', 'createdAt': 1})}\n'
        '{"op":"fact","seq":1',
      );

      final storage = JsonlSessionStorage(
        file,
        const SessionMetadata(id: 's', createdAt: 1),
      );
      await storage.setName('appended');

      final records = file
          .readAsLinesSync()
          .map(jsonDecode)
          .whereType<Map<String, dynamic>>()
          .toList();
      expect(records, hasLength(2));
      expect(records.last['name'], 'appended');
    });

    test('reads CRLF and a line larger than the scan chunk', () async {
      final directory = await Directory.systemTemp.createTemp('session-jsonl-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}s.jsonl');
      final longName = 'x' * (70 * 1024);
      file.writeAsStringSync(
        '${jsonEncode({'op': 'header', 'id': 's', 'createdAt': 1})}\r\n'
        '${jsonEncode({'op': 'fact', 'seq': 1, 'fact': 'name', 'name': longName})}\r\n',
      );

      final storage = JsonlSessionStorage(
        file,
        const SessionMetadata(id: 's', createdAt: 1),
      );
      expect(await storage.getName(), longName);
    });

    test('list skips damaged recent files before counting 30 sessions', () async {
      final directory = await Directory.systemTemp.createTemp('session-jsonl-');
      addTearDown(() => directory.delete(recursive: true));
      final sessionsDirectory = Directory(
        '${directory.path}${Platform.pathSeparator}agent_chat'
        '${Platform.pathSeparator}sessions',
      )..createSync(recursive: true);
      final baseline = DateTime(2026, 1, 1);

      for (var index = 0; index < 35; index++) {
        final id = 'valid-$index';
        final file = File(
          '${sessionsDirectory.path}${Platform.pathSeparator}$id.jsonl',
        );
        file.writeAsStringSync(
          '${jsonEncode({'op': 'header', 'id': id, 'createdAt': index})}\n',
        );
        file.setLastModifiedSync(baseline.add(Duration(seconds: index)));
      }
      for (var index = 0; index < 30; index++) {
        final file = File(
          '${sessionsDirectory.path}${Platform.pathSeparator}damaged-$index.jsonl',
        );
        file.writeAsStringSync(
          index.isEven ? '{not json}\n' : '${jsonEncode({'op': 'entry'})}\n',
        );
        file.setLastModifiedSync(
          baseline.add(Duration(minutes: 1, seconds: index)),
        );
      }

      final sessions = await JsonlSessionRepo(directory).list();

      expect(sessions, hasLength(30));
      expect(sessions.map((metadata) => metadata.id), [
        for (var index = 34; index >= 5; index--) 'valid-$index',
      ]);
    });

    test(
      'fork persists branch and tree options with facts and lanes',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'session-jsonl-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final repo = JsonlSessionRepo(directory);
        final source = await repo.create(
          const SessionCreateOptions(id: 'source'),
        );
        await source.appendEntry(
          MessageEntry(id: 'root', message: UserMessage.text('root')),
          'main',
        );
        await source.appendEntry(
          MessageEntry(id: 'main-2', message: UserMessage.text('main 2')),
          'main',
        );
        await source.createLane('alternate', 'root');
        await source.appendEntry(
          MessageEntry(
            id: 'alternate-2',
            message: UserMessage.text('alternate'),
          ),
          'alternate',
        );
        await source.appendEntry(
          MessageEntry(id: 'main-3', message: UserMessage.text('main 3')),
          'main',
        );
        await source.setName('source name');
        await source.setLabel('root', 'root label');
        await source.setLabel('main-2', 'main label');
        await source.setLabel('alternate-2', 'alternate label');

        Future<Session> forkAndReopen(ForkOptions options) async {
          final forked = await repo.fork(
            const SessionMetadata(id: 'source', createdAt: 0),
            options,
          );
          final metadata = await forked.getMetadata();
          expect(metadata.parentSessionId, 'source');
          return repo.open(metadata);
        }

        Future<void> expectFork(
          ForkOptions options, {
          required List<String> entries,
          required Map<String, String?> lanes,
        }) async {
          final forked = await forkAndReopen(options);
          expect(
            (await forked.findEntries(
              const EntryQuery(order: EntryOrder.oldestFirst),
            )).map((entry) => entry.id),
            entries,
          );
          expect({
            for (final lane in await forked.getLanes()) lane.lane: lane.leafId,
          }, lanes);
          expect(await forked.getName(), 'source name');
          expect(await forked.getLabel('root'), 'root label');
          expect(
            await forked.getLabel('main-2'),
            entries.contains('main-2') ? 'main label' : isNull,
          );
          expect(
            await forked.getLabel('alternate-2'),
            entries.contains('alternate-2') ? 'alternate label' : isNull,
          );
        }

        await expectFork(
          const ForkOptions(),
          entries: ['root', 'main-2', 'main-3'],
          lanes: {'main': 'main-3'},
        );
        await expectFork(
          const ForkOptions(entryId: 'main-2'),
          entries: ['root'],
          lanes: {'main': 'root'},
        );
        await expectFork(
          const ForkOptions(
            scope: 'branch',
            entryId: 'main-2',
            position: 'before',
          ),
          entries: ['root'],
          lanes: {'main': 'root'},
        );
        await expectFork(
          const ForkOptions(scope: 'branch', entryId: 'main-2', position: 'at'),
          entries: ['root', 'main-2'],
          lanes: {'main': 'main-2'},
        );
        await expectFork(
          const ForkOptions(scope: 'tree'),
          entries: ['root', 'main-2', 'alternate-2', 'main-3'],
          lanes: {'main': 'main-3', 'alternate': 'alternate-2'},
        );
      },
    );
  });
}
