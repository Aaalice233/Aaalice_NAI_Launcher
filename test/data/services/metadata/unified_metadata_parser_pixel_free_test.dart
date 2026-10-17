import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/metadata_parse_result_expectations.dart';
import '../../../helpers/novelai_exif_fixture.dart';
import '../../../helpers/novelai_webp_layout_fixture.dart';
import '../../../helpers/stealth_png_fixture.dart';
import '../../../helpers/webp_metadata_fixture.dart';

Uint8List _plainPng() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)));

Uint8List _textChunkPng() => UnifiedMetadataParser.embedTextChunkOnly(
  _plainPng(),
  'Comment',
  jsonEncode({'prompt': 'text chunk', 'seed': 42, 'steps': 28}),
);

const _webpComment = {'prompt': 'webp exif', 'seed': 7, 'steps': 28};

void main() {
  group('parseFromImageWithoutPixelDecode', () {
    test('answers png text chunks exactly like the full parser', () {
      final bytes = _textChunkPng();

      final result = UnifiedMetadataParser.parseFromImageWithoutPixelDecode(
        bytes,
      );

      expect(result?.metadata?.seed, 42);
      expectSameParseResult(
        result,
        UnifiedMetadataParser.parseFromImage(bytes),
      );
    });

    test('answers webp exif exactly like the full parser', () {
      final bytes = buildNovelAiWebpFixture(comment: _webpComment);

      final result = UnifiedMetadataParser.parseFromImageWithoutPixelDecode(
        bytes,
      );

      expect(result?.metadata?.prompt, 'webp exif');
      expectSameParseResult(
        result,
        UnifiedMetadataParser.parseFromImage(bytes),
      );
    });

    test('answers unsupported and truncated containers directly', () {
      final unsupported = Uint8List.fromList(List.filled(32, 7));
      final truncated = Uint8List.sublistView(_plainPng(), 0, 20);
      final stealthWebp = novelAiLayoutWebp();
      final truncatedWebp = Uint8List.sublistView(
        stealthWebp,
        0,
        stealthWebp.length - 7,
      );

      for (final bytes in [unsupported, truncated, truncatedWebp]) {
        final result = UnifiedMetadataParser.parseFromImageWithoutPixelDecode(
          bytes,
        );
        expect(result?.success, isFalse);
        expectSameParseResult(
          result,
          UnifiedMetadataParser.parseFromImage(bytes),
        );
      }
    });

    test(
      'defers stealth-only and metadata-free pngs to the pixel decode',
      () async {
        final stealth = await stealthOnlyNovelAiPng('stealth only');

        expect(
          UnifiedMetadataParser.parseFromImageWithoutPixelDecode(stealth),
          isNull,
        );
        expect(
          UnifiedMetadataParser.parseFromImageWithoutPixelDecode(_plainPng()),
          isNull,
        );
        expect(
          UnifiedMetadataParser.parseFromImage(stealth).metadata?.prompt,
          'stealth only',
        );
      },
    );
  });

  group('parseFromWebpWithoutPixelDecode', () {
    test('rejects non-webp bytes like parseFromWebp', () {
      final bytes = _textChunkPng();

      expectSameParseResult(
        UnifiedMetadataParser.parseFromWebpWithoutPixelDecode(bytes),
        UnifiedMetadataParser.parseFromWebp(bytes),
      );
    });

    test('defers only when the webp pixels decide the answer', () {
      final exif = buildNovelAiWebpFixture(comment: _webpComment);
      final stealth = novelAiLayoutWebp(exif: rewrittenCameraExif());

      expectSameParseResult(
        UnifiedMetadataParser.parseFromWebpWithoutPixelDecode(exif),
        UnifiedMetadataParser.parseFromWebp(exif),
      );
      expect(
        UnifiedMetadataParser.parseFromWebpWithoutPixelDecode(stealth),
        isNull,
      );
      expect(
        UnifiedMetadataParser.parseFromWebp(stealth).metadata?.prompt,
        novelAiStealthPrompt,
      );
    });
  });

  group('parseFromPngWithoutPixelDecode', () {
    test('rejects non-png bytes like parseFromPng', () {
      final bytes = buildNovelAiWebpFixture(comment: _webpComment);

      expectSameParseResult(
        UnifiedMetadataParser.parseFromPngWithoutPixelDecode(bytes),
        UnifiedMetadataParser.parseFromPng(bytes),
      );
    });

    test('defers only when the png pixels decide the answer', () async {
      final text = _textChunkPng();

      expectSameParseResult(
        UnifiedMetadataParser.parseFromPngWithoutPixelDecode(text),
        UnifiedMetadataParser.parseFromPng(text),
      );
      expect(
        UnifiedMetadataParser.parseFromPngWithoutPixelDecode(
          await stealthOnlyNovelAiPng('stealth only'),
        ),
        isNull,
      );
    });
  });
}
