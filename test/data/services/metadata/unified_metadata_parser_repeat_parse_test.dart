import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/image_metadata_parser_service.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/stealth_png_fixture.dart';
import '../../../helpers/webp_metadata_fixture.dart';

typedef _BytesParse = MetadataParseResult? Function(Uint8List bytes);

Uint8List _textChunkPng(String prompt) =>
    UnifiedMetadataParser.embedTextChunkOnly(
      Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4))),
      'Comment',
      jsonEncode({'prompt': prompt, 'seed': 42, 'steps': 28}),
    );

Uint8List _webp(String prompt) => buildNovelAiWebpFixture(
  comment: {'prompt': prompt, 'seed': 7, 'steps': 28},
);

const Map<String, _BytesParse> _pngEntries = {
  'parseFromImage': UnifiedMetadataParser.parseFromImage,
  'parseFromPng': UnifiedMetadataParser.parseFromPng,
  'parseFromImageWithoutPixelDecode':
      UnifiedMetadataParser.parseFromImageWithoutPixelDecode,
  'parseFromPngWithoutPixelDecode':
      UnifiedMetadataParser.parseFromPngWithoutPixelDecode,
};

const Map<String, _BytesParse> _webpEntries = {
  'parseFromImage': UnifiedMetadataParser.parseFromImage,
  'parseFromWebp': UnifiedMetadataParser.parseFromWebp,
  'parseFromImageWithoutPixelDecode':
      UnifiedMetadataParser.parseFromImageWithoutPixelDecode,
};

void _expectFollowsInPlaceRewrite(
  Map<String, _BytesParse> entries,
  Uint8List Function(String prompt) build,
) {
  for (final MapEntry(key: name, value: parse) in entries.entries) {
    final buffer = Uint8List.fromList(build('prompt-a'));
    final rewritten = build('prompt-b');
    expect(rewritten.length, buffer.length, reason: name);

    expect(parse(buffer)?.metadata?.prompt, 'prompt-a', reason: name);
    buffer.setAll(0, rewritten);
    expect(parse(buffer)?.metadata?.prompt, 'prompt-b', reason: name);
  }
}

void _expectSameResult(MetadataParseResult actual, MetadataParseResult first) {
  expect(actual.success, first.success);
  expect(actual.sourceFormat, first.sourceFormat);
  expect(actual.rawData, first.rawData);
  expect(actual.triedParsers, first.triedParsers);
  expect(actual.errorMessage, first.errorMessage);
  expect(actual.metadata, first.metadata);
  expect(actual.bytesRead, first.bytesRead);
}

void main() {
  setUp(UnifiedMetadataParser.resetStatistics);

  test('a png buffer rewritten in place parses to its new content', () {
    _expectFollowsInPlaceRewrite(_pngEntries, _textChunkPng);
  });

  test('a webp buffer rewritten in place parses to its new content', () {
    _expectFollowsInPlaceRewrite(_webpEntries, _webp);
  });

  test('a file rewritten at the same path parses to its new content', () async {
    final directory = await Directory.systemTemp.createTemp(
      'metadata-reparse-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}image.png');
    final first = _textChunkPng('prompt-a');
    final rewritten = _textChunkPng('prompt-b');
    expect(rewritten.length, first.length);

    for (final useGradualRead in [true, false]) {
      file.writeAsBytesSync(first);
      expect(
        UnifiedMetadataParser.parseFromFile(
          file.path,
          useGradualRead: useGradualRead,
        ).metadata?.prompt,
        'prompt-a',
      );

      file.writeAsBytesSync(rewritten);
      expect(
        UnifiedMetadataParser.parseFromFile(
          file.path,
          useGradualRead: useGradualRead,
        ).metadata?.prompt,
        'prompt-b',
      );
    }
  });

  test('identical bytes go through the full parse on every call', () async {
    final fixtures = {
      'text chunk png': _textChunkPng('repeat'),
      'stealth-only png': await stealthOnlyNovelAiPng('repeat'),
      'webp exif': _webp('repeat'),
    };

    for (final MapEntry(key: name, value: bytes) in fixtures.entries) {
      UnifiedMetadataParser.resetStatistics();
      final first = UnifiedMetadataParser.parseFromImage(bytes);
      expect(first.metadata?.prompt, 'repeat', reason: name);

      _expectSameResult(UnifiedMetadataParser.parseFromImage(bytes), first);
      _expectSameResult(
        UnifiedMetadataParser.parseFromImage(Uint8List.fromList(bytes)),
        first,
      );

      final statistics = UnifiedMetadataParser.statistics;
      expect(statistics.totalAttempts, 3, reason: name);
      expect(statistics.successfulParses, 3, reason: name);
      // Only bumped when the text decoder actually runs.
      expect(
        statistics.parserSuccessCounts.values.fold<int>(0, (a, b) => a + b),
        3,
        reason: name,
      );
    }
  });

  test('offers no cache switch or cache reset', () {
    final bytes = _textChunkPng('api');
    final parses = <Function>[
      UnifiedMetadataParser.parseFromImage,
      UnifiedMetadataParser.parseFromPng,
      UnifiedMetadataParser.parseFromWebp,
    ];

    for (final parse in parses) {
      expect(
        () => Function.apply(parse, [bytes], {#useCache: false}),
        throwsNoSuchMethodError,
      );
    }
    expect(
      () => Function.apply(
        UnifiedMetadataParser.parseFromFile,
        ['missing.png'],
        {#useCache: false},
      ),
      throwsNoSuchMethodError,
    );
    expect(
      () => (ImageMetadataParserService() as dynamic).clearCache(),
      throwsNoSuchMethodError,
    );
  });
}
