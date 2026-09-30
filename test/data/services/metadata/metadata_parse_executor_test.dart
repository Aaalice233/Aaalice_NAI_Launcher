import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/metadata/metadata_parse_executor.dart';

import '../../../helpers/stealth_png_fixture.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metadata-executor-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('parses a stealth-only file in the background', () async {
    final file = File('${directory.path}/stealth_only.png');
    await file.writeAsBytes(await stealthOnlyNovelAiPng('stealth-only-prompt'));

    final result = await const MetadataParseExecutor().parseFile(file.path);

    expect(result.success, isTrue);
    expect(result.sourceFormat, 'NovelAI stealth_pngcomp');
    expect(result.metadata?.prompt, 'stealth-only-prompt');
  });

  test('reports a missing file as a failed result', () async {
    final result = await const MetadataParseExecutor().parseFile(
      '${directory.path}/absent.png',
    );

    expect(result.success, isFalse);
    expect(result.errorMessage, startsWith('File not found'));
  });

  test('parses image bytes in the background', () async {
    final bytes = await stealthOnlyNovelAiPng('bytes-prompt');

    final result = await const MetadataParseExecutor().parseBytes(bytes);

    expect(result.success, isTrue);
    expect(result.metadata?.prompt, 'bytes-prompt');
  });
}
