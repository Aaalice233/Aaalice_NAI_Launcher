import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/webp_metadata_fixture.dart';

void main() {
  const novelAiComment = <String, dynamic>{
    'prompt': '1girl, webp metadata',
    'uc': 'lowres',
    'width': 832,
    'height': 1216,
    'seed': 123456789,
    'steps': 28,
    'scale': 5.0,
    'sampler': 'k_euler',
  };

  test('file early failures keep HEAD statistics semantics', () async {
    final directory = await Directory.systemTemp.createTemp('metadata-stats-');
    addTearDown(() => directory.delete(recursive: true));

    UnifiedMetadataParser.resetStatistics();
    final missing = UnifiedMetadataParser.parseFromFile(
      '${directory.path}${Platform.pathSeparator}missing.png',
    );
    expect(missing.success, isFalse);
    expect(UnifiedMetadataParser.statistics.totalAttempts, 1);
    expect(UnifiedMetadataParser.statistics.failedParses, 0);
    expect(UnifiedMetadataParser.statistics.totalParseTime, Duration.zero);

    final small = File('${directory.path}${Platform.pathSeparator}small.png')
      ..writeAsBytesSync(const [1, 2, 3]);
    final tooSmall = UnifiedMetadataParser.parseFromFile(small.path);
    expect(tooSmall.success, isFalse);
    expect(UnifiedMetadataParser.statistics.totalAttempts, 2);
    expect(UnifiedMetadataParser.statistics.failedParses, 0);
    expect(UnifiedMetadataParser.statistics.totalParseTime, Duration.zero);
  });

  test(
    'PNG chunk text overrides decoder text while retaining decoder fields',
    () {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      final withChunk = UnifiedMetadataParser.embedTextChunkOnly(
        png,
        'Comment',
        jsonEncode(novelAiComment),
      );

      final textData = ImageMetadataContainerCodec.extractPngTextData(
        withChunk,
        decoderTextData: const {
          'Comment': 'decoder value',
          'DecoderOnly': 'preserved',
        },
      );

      expect(textData['Comment'], jsonEncode(novelAiComment));
      expect(textData['DecoderOnly'], 'preserved');
    },
  );

  group('public parse statistics', () {
    setUp(UnifiedMetadataParser.resetStatistics);

    test('PNG success records one container attempt and one success', () {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );
      final withMetadata = UnifiedMetadataParser.embedTextChunkOnly(
        png,
        'Comment',
        jsonEncode(novelAiComment),
      );

      final result = UnifiedMetadataParser.parseFromPng(withMetadata);

      expect(result.success, isTrue, reason: result.errorMessage);
      _expectAggregateStatistics(attempts: 1, successes: 1, failures: 0);
      expect(UnifiedMetadataParser.statistics.parserSuccessCounts, {
        'NovelAI': 1,
      });
    });

    test('PNG text failure records one container attempt and one failure', () {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 1, height: 1)),
      );

      final result = UnifiedMetadataParser.parseFromPng(png);

      expect(result.success, isFalse);
      _expectAggregateStatistics(attempts: 1, successes: 0, failures: 1);
      expect(UnifiedMetadataParser.statistics.parserSuccessCounts, isEmpty);
    });

    test('WebP success records one container attempt and one success', () {
      final result = UnifiedMetadataParser.parseFromWebp(
        buildNovelAiWebpFixture(comment: novelAiComment),
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      _expectAggregateStatistics(attempts: 1, successes: 1, failures: 0);
      expect(UnifiedMetadataParser.statistics.parserSuccessCounts, {
        'NovelAI': 1,
      });
    });

    test('WebP text failure records one container attempt and one failure', () {
      final result = UnifiedMetadataParser.parseFromWebp(
        buildNovelAiWebpFixture(comment: const {'unknown': true}),
      );

      expect(result.success, isFalse);
      _expectAggregateStatistics(attempts: 1, successes: 0, failures: 1);
      expect(UnifiedMetadataParser.statistics.parserSuccessCounts, isEmpty);
    });

    test(
      'text parsing keeps its own single aggregate and parser statistics',
      () {
        final success = UnifiedMetadataParser.parseFromTextData({
          'Comment': jsonEncode(novelAiComment),
        });

        expect(success.success, isTrue, reason: success.errorMessage);
        _expectAggregateStatistics(attempts: 0, successes: 1, failures: 0);
        expect(
          UnifiedMetadataParser.statistics.totalParseTime,
          success.parseTime,
        );
        expect(UnifiedMetadataParser.statistics.parserSuccessCounts, {
          'NovelAI': 1,
        });

        UnifiedMetadataParser.resetStatistics();
        final failure = UnifiedMetadataParser.parseFromTextData(const {
          'Comment': 'not metadata',
        });

        expect(failure.success, isFalse);
        _expectAggregateStatistics(attempts: 0, successes: 0, failures: 1);
        expect(
          UnifiedMetadataParser.statistics.totalParseTime,
          failure.parseTime,
        );
        expect(UnifiedMetadataParser.statistics.parserSuccessCounts, isEmpty);
      },
    );
  });

  test('format-dispatch entry preserves PNG metadata parsing', () {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 1, height: 1)),
    );
    final withMetadata = UnifiedMetadataParser.embedTextChunkOnly(
      png,
      'Comment',
      jsonEncode(novelAiComment),
    );

    final result = UnifiedMetadataParser.parseFromImage(withMetadata);

    expect(result.success, isTrue, reason: result.errorMessage);
    expect(result.metadata?.prompt, '1girl, webp metadata');
  });

  group('UnifiedMetadataParser WebP', () {
    test('extracts NovelAI JSON from EXIF UserComment in a real RIFF WebP', () {
      final bytes = buildNovelAiWebpFixture(comment: novelAiComment);

      // Guard the fixture itself: it includes a decodable lossless WebP image
      // payload in addition to VP8X, unknown and EXIF chunks.
      expect(img.decodeWebP(bytes), isNotNull);

      final result = UnifiedMetadataParser.parseFromImage(bytes);

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.sourceFormat, 'NovelAI WebP EXIF');
      expect(result.metadata?.prompt, '1girl, webp metadata');
      expect(result.metadata?.negativePrompt, 'lowres');
      expect(result.metadata?.seed, 123456789);
      expect(result.metadata?.width, 832);
      expect(result.metadata?.height, 1216);
      expect(result.metadata?.source, 'NovelAI Diffusion V4.5');
      expect(result.triedParsers, contains('WebP EXIF'));
    });

    test('reports a valid WebP without EXIF metadata as unrecognized', () {
      final bytes = buildNovelAiWebpFixture();

      final result = UnifiedMetadataParser.parseFromImage(bytes);

      expect(result.success, isFalse);
      expect(result.metadata, isNull);
      expect(result.errorMessage, contains('No EXIF UserComment'));
    });

    test('reports truncated WebP container without pretending success', () {
      final complete = buildNovelAiWebpFixture(comment: novelAiComment);
      final truncated = complete.sublist(0, complete.length - 5);

      final result = UnifiedMetadataParser.parseFromImage(truncated);

      expect(result.success, isFalse);
      expect(result.metadata, isNull);
      expect(result.errorMessage, contains('Truncated WebP RIFF container'));
    });

    test('rejects non-ASCII EXIF UserComment encoding with diagnostics', () {
      final bytes = buildNovelAiWebpFixture(
        comment: novelAiComment,
        invalidUserCommentPrefix: true,
      );

      final result = UnifiedMetadataParser.parseFromImage(bytes);

      expect(result.success, isFalse);
      expect(result.metadata, isNull);
      expect(result.errorMessage, contains('expected ASCII prefix'));
    });

    test('file parsing accepts an uppercase WebP extension', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'nai_webp_metadata_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}${Platform.pathSeparator}sample.WEBP');
      await file.writeAsBytes(buildNovelAiWebpFixture(comment: novelAiComment));

      final result = UnifiedMetadataParser.parseFromFile(
        file.path,
        useGradualRead: false,
        useCache: false,
      );

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.metadata?.prompt, '1girl, webp metadata');
    });
  });
}

void _expectAggregateStatistics({
  required int attempts,
  required int successes,
  required int failures,
}) {
  final statistics = UnifiedMetadataParser.statistics;
  expect(statistics.totalAttempts, attempts);
  expect(statistics.successfulParses, successes);
  expect(statistics.failedParses, failures);
  expect(statistics.successfulParses + statistics.failedParses, 1);
  expect(statistics.totalParseTime, isA<Duration>());
}
