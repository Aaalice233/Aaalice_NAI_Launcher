import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/isolate_pool.dart';
import 'package:nai_launcher/data/services/metadata/metadata_parse_executor.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/fixed_tag_usage_fixture.dart';
import '../../../helpers/metadata_parse_result_expectations.dart';
import '../../../helpers/shared_compute_gate.dart';
import '../../../helpers/stealth_png_fixture.dart';
import '../../../helpers/webp_metadata_fixture.dart';

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

  test('parses text chunks and WebP EXIF without the compute gate', () async {
    final sources = {
      'png text chunk': await novelAiPngBytes('text chunk prompt'),
      'webp exif': buildNovelAiWebpFixture(
        comment: const {'prompt': 'webp exif', 'seed': 7, 'steps': 28},
      ),
    };

    for (final MapEntry(key: name, value: bytes) in sources.entries) {
      final result = await expectRunsWithoutComputeGate(
        ComputeGate(),
        () => const MetadataParseExecutor().parseBytes(bytes),
      );

      expect(result.success, isTrue, reason: name);
      expectSameParseResult(
        result,
        UnifiedMetadataParser.parseFromImage(bytes),
      );
    }
  });

  test('hands only the stealth pixel decode to the compute gate', () async {
    final bytes = await stealthOnlyNovelAiPng('bytes-prompt');

    final result = await expectQueuedBehindSharedComputeGate(
      () => const MetadataParseExecutor().parseBytes(bytes),
    );

    expect(result.sourceFormat, 'NovelAI stealth_pngcomp');
    expect(result.metadata?.prompt, 'bytes-prompt');
    expectSameParseResult(result, UnifiedMetadataParser.parseFromImage(bytes));
  });
}
