import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/harness/session/session_jsonl.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('line_storage_bounded');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      await tmp.delete(recursive: true);
    }
  });

  File write(String name, String content) {
    final file = File('${tmp.path}${Platform.pathSeparator}$name')
      ..writeAsStringSync(content);
    return file;
  }

  group('SessionJsonlLineStorage bounded read', () {
    test('stops at the bound and ignores the rest of a large file', () {
      const header = '{"op":"header","id":"s1","createdAt":1}';
      final noise = List.generate(
        4000,
        (index) => '{"op":"entry","seq":$index,"blob":"${'x' * 200}"}',
      ).join('\n');
      final file = write('large.jsonl', '$header\n$noise\nnot json at all');
      expect(file.lengthSync(), greaterThan(64 * 1024));

      final first = SessionJsonlLineStorage(
        file,
      ).readCompleteLinesSync(maxLines: 1);
      expect(first, [header]);
    });

    test('a non-positive bound yields nothing', () {
      final file = write('two.jsonl', '{"a":1}\n{"a":2}\n');
      expect(
        SessionJsonlLineStorage(file).readCompleteLinesSync(maxLines: 0),
        isEmpty,
      );
      expect(
        SessionJsonlLineStorage(file).readCompleteLinesSync(maxLines: -3),
        isEmpty,
      );
    });

    test('a bound above the line count returns every line', () {
      final file = write('three.jsonl', '{"a":1}\n{"a":2}\n{"a":3}\n');
      expect(
        SessionJsonlLineStorage(file).readCompleteLinesSync(maxLines: 99),
        ['{"a":1}', '{"a":2}', '{"a":3}'],
      );
    });

    test('the bound is honoured across chunk boundaries', () {
      final file = write('chunked.jsonl', '{"a":1}\n{"a":2}\n{"a":3}\n');
      final storage = SessionJsonlLineStorage(file, chunkSize: 4);
      expect(storage.readCompleteLinesSync(maxLines: 2), [
        '{"a":1}',
        '{"a":2}',
      ]);
      expect(storage.readCompleteLinesSync(), [
        '{"a":1}',
        '{"a":2}',
        '{"a":3}',
      ]);
    });

    test('a bound reached on the final newline never reads the torn tail', () {
      final file = write('torn.jsonl', '{"a":1}\n{"a":2}\n{"a":');
      expect(SessionJsonlLineStorage(file).readCompleteLinesSync(maxLines: 2), [
        '{"a":1}',
        '{"a":2}',
      ]);
      expect(SessionJsonlLineStorage(file).readCompleteLinesSync(), [
        '{"a":1}',
        '{"a":2}',
      ]);
    });

    test('an unterminated final line is kept only when it is valid JSON', () {
      final complete = write('complete_tail.jsonl', '{"a":1}\n{"a":2}');
      expect(
        SessionJsonlLineStorage(complete).readCompleteLinesSync(maxLines: 2),
        ['{"a":1}', '{"a":2}'],
      );

      final torn = write('torn_tail.jsonl', '{"a":1}\n{"a"');
      expect(SessionJsonlLineStorage(torn).readCompleteLinesSync(maxLines: 2), [
        '{"a":1}',
      ]);
    });

    test('an empty or missing file yields nothing', () {
      final empty = write('empty.jsonl', '');
      expect(
        SessionJsonlLineStorage(empty).readCompleteLinesSync(maxLines: 1),
        isEmpty,
      );
      final missing = File('${tmp.path}${Platform.pathSeparator}missing.jsonl');
      expect(
        SessionJsonlLineStorage(missing).readCompleteLinesSync(maxLines: 1),
        isEmpty,
      );
    });

    test('a leading blank line is returned verbatim', () {
      final file = write('blank_first.jsonl', '\n{"a":1}\n');
      expect(SessionJsonlLineStorage(file).readCompleteLinesSync(maxLines: 1), [
        '',
      ]);
    });

    test('CRLF terminators are stripped under a bound', () {
      final file = write('crlf.jsonl', '{"a":1}\r\n{"a":2}\r\n');
      expect(SessionJsonlLineStorage(file).readCompleteLinesSync(maxLines: 1), [
        '{"a":1}',
      ]);
    });
  });
}
