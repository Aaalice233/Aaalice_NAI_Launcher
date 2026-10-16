import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/metadata_parse_result_expectations.dart';
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

_BytesParse _parseViaFile(File file, {required bool useGradualRead}) =>
    (bytes) {
      file.writeAsBytesSync(bytes);
      return UnifiedMetadataParser.parseFromFile(
        file.path,
        useGradualRead: useGradualRead,
      );
    };

void main() {
  setUp(UnifiedMetadataParser.resetStatistics);

  test('every entry point parses the content rewritten in place', () async {
    final directory = await Directory.systemTemp.createTemp(
      'metadata-reparse-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}image.png');

    _expectFollowsInPlaceRewrite({
      ..._pngEntries,
      'parseFromFile gradual': _parseViaFile(file, useGradualRead: true),
      'parseFromFile whole': _parseViaFile(file, useGradualRead: false),
    }, _textChunkPng);
    _expectFollowsInPlaceRewrite(_webpEntries, _webp);
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

      expectSameParseResult(UnifiedMetadataParser.parseFromImage(bytes), first);
      expectSameParseResult(
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
}
