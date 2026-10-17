import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/data/services/metadata/exif_metadata_extractor.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/exif_orientation_fixture.dart' show plainWebp;
import '../../../helpers/metadata_parse_result_expectations.dart';
import '../../../helpers/novelai_exif_fixture.dart';
import '../../../helpers/novelai_webp_layout_fixture.dart';
import '../../../helpers/riff_webp_builder.dart';

const _exifPrompt = '1girl, exif prompt, 中文提示词';
const _exifSeed = 2042154368;
const _stealthFormat = 'NovelAI stealth_pngcomp';
const _exifFormat = 'NovelAI WebP EXIF';

final String _exifEnvelope = novelAiEnvelopeJson(
  prompt: _exifPrompt,
  seed: _exifSeed,
);

Uint8List _withUserComment(List<int> userComment) =>
    novelAiLayoutWebp(exif: novelAiExif(userComment: userComment));

void _expectExifMetadata(MetadataParseResult result) {
  expect(result.success, isTrue, reason: result.errorMessage);
  expect(result.sourceFormat, _exifFormat);
  expect(result.metadata?.prompt, _exifPrompt);
  expect(result.metadata?.seed, _exifSeed);
}

void _expectStealthMetadata(MetadataParseResult result) {
  expect(result.success, isTrue, reason: result.errorMessage);
  expect(result.sourceFormat, _stealthFormat);
  expect(result.metadata?.prompt, novelAiStealthPrompt);
  expect(result.metadata?.seed, novelAiStealthSeed);
  expect(result.metadata?.source, novelAiV45FullSource);
  expect(result.metadata?.software, 'NovelAI');
}

void main() {
  test('fixture keeps the NovelAI chunk order with EXIF at the end', () {
    final bytes = _withUserComment(asciiUserComment(_exifEnvelope));
    final chunkTypes = <String>[];
    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final size = ByteData.sublistView(
        bytes,
        offset + 4,
        offset + 8,
      ).getUint32(0, Endian.little);
      chunkTypes.add(ascii.decode(bytes.sublist(offset, offset + 4)));
      offset += 8 + size + (size.isOdd ? 1 : 0);
    }

    expect(chunkTypes, ['VP8X', 'ALPH', 'VP8 ', 'EXIF']);
    expect(bytes[20] & 0x18, 0x18, reason: 'VP8X alpha and EXIF flags');
    expect(offset, bytes.length);
  });

  group('EXIF UserComment', () {
    test('reads the ASCII-prefixed envelope written by NovelAI', () {
      final result = UnifiedMetadataParser.parseFromImage(
        _withUserComment(asciiUserComment(_exifEnvelope)),
      );

      _expectExifMetadata(result);
      expect(result.metadata?.source, novelAiV45FullSource);
      expect(result.metadata?.software, 'NovelAI');
      expect(result.metadata?.model, ImageModels.animeDiffusionV45Full);
    });

    test('keeps non-ASCII UTF-8 text after the ASCII prefix', () {
      final result = UnifiedMetadataParser.parseFromImage(
        _withUserComment(asciiUserComment(_exifEnvelope)),
      );

      expect(result.metadata?.prompt, contains('中文提示词'));
      expect(result.rawData, _exifEnvelope);
    });

    test('decodes an UNDEFINED prefix of eight zero bytes as UTF-8', () {
      _expectExifMetadata(
        UnifiedMetadataParser.parseFromImage(
          _withUserComment(undefinedUserComment(_exifEnvelope)),
        ),
      );
    });

    test('decodes an unprefixed comment as UTF-8 like the web reader', () {
      _expectExifMetadata(
        UnifiedMetadataParser.parseFromImage(
          _withUserComment(utf8.encode(_exifEnvelope)),
        ),
      );
    });

    for (final (label, endian, byteOrderMark) in [
      ('little endian with BOM', Endian.little, true),
      ('big endian with BOM', Endian.big, true),
      ('big endian without BOM', Endian.big, false),
    ]) {
      test('decodes a UNICODE comment as UTF-16 $label', () {
        _expectExifMetadata(
          UnifiedMetadataParser.parseFromImage(
            _withUserComment(
              unicodeUserComment(
                _exifEnvelope,
                endian: endian,
                byteOrderMark: byteOrderMark,
              ),
            ),
          ),
        );
      });
    }

    test('maps both NovelAI IFD0 layouts to the same Source', () {
      for (final layout in NovelAiExifIfd0Layout.values) {
        final extraction = ExifMetadataExtractor.fromWebp(
          novelAiLayoutWebp(
            exif: novelAiExif(
              userComment: asciiUserComment(_exifEnvelope),
              layout: layout,
              prompt: _exifPrompt,
            ),
          ),
        );

        expect(
          extraction.textData['Source'],
          novelAiV45FullSource,
          reason: layout.name,
        );
      }
    });

    test('decodes UTF-8 IFD0 text instead of reading it byte-per-char', () {
      final extraction = ExifMetadataExtractor.fromWebp(
        novelAiLayoutWebp(
          exif: novelAiExif(
            userComment: asciiUserComment(_exifEnvelope),
            layout: NovelAiExifIfd0Layout.softwareAsSource,
            prompt: _exifPrompt,
          ),
        ),
      );

      expect(extraction.textData['Description'], _exifPrompt);
    });

    test('envelope attribution wins over the legacy IFD0 Software', () {
      final result = UnifiedMetadataParser.parseFromImage(
        novelAiLayoutWebp(
          exif: novelAiExif(
            userComment: asciiUserComment(_exifEnvelope),
            source: 'NovelAI',
          ),
        ),
      );

      expect(result.metadata?.source, novelAiV45FullSource);
    });

    test('the last EXIF chunk wins like the web reader', () {
      final earlier = _withUserComment(
        asciiUserComment(
          novelAiEnvelopeJson(prompt: 'earlier chunk', seed: _exifSeed),
        ),
      );
      final bytes = riffWebp([
        ...earlier.sublist(12),
        ...riffChunk(
          'EXIF',
          novelAiExif(userComment: asciiUserComment(_exifEnvelope)),
        ),
      ]);

      _expectExifMetadata(UnifiedMetadataParser.parseFromImage(bytes));
    });
  });

  group('stealth fallback', () {
    test('reads the alpha payload when EXIF was stripped', () {
      final bytes = novelAiLayoutWebp();

      expect(
        UnifiedMetadataParser.parseFromImageWithoutPixelDecode(bytes),
        isNull,
      );
      _expectStealthMetadata(UnifiedMetadataParser.parseFromImage(bytes));
    });

    test('reads the alpha payload when another tool rewrote EXIF', () {
      final bytes = novelAiLayoutWebp(exif: rewrittenCameraExif());

      expect(
        ExifMetadataExtractor.fromWebp(bytes).errorMessage,
        isNull,
        reason: 'a generic EXIF without UserComment is not damage',
      );
      expect(
        UnifiedMetadataParser.parseFromImageWithoutPixelDecode(bytes),
        isNull,
      );
      _expectStealthMetadata(UnifiedMetadataParser.parseFromImage(bytes));
    });

    test('falls back when the UserComment is not a metadata envelope', () {
      for (final comment in [
        asciiUserComment('not json at all'),
        [
          ...ascii.encode('JIS\u0000\u0000\u0000\u0000\u0000'),
          ...utf8.encode(_exifEnvelope),
        ],
      ]) {
        _expectStealthMetadata(
          UnifiedMetadataParser.parseFromImage(_withUserComment(comment)),
        );
      }
    });

    test('falls back when the EXIF chunk is not a TIFF structure', () {
      final result = UnifiedMetadataParser.parseFromImage(
        novelAiLayoutWebp(exif: ascii.encode('garbage exif payload')),
      );

      _expectStealthMetadata(result);
    });

    test('keeps the no-metadata diagnosis when pixels carry nothing', () {
      final plain = riffWebp([
        ...plainWebp.sublist(12),
        ...riffChunk('EXIF', rewrittenCameraExif()),
      ]);

      final result = UnifiedMetadataParser.parseFromImage(plain);

      expect(result.success, isFalse);
      expect(result.errorMessage, startsWith('No EXIF UserComment metadata'));
      expect(result.triedParsers, ['WebP EXIF']);
    });

    test('a truncated container fails before any pixel decode', () {
      final complete = _withUserComment(asciiUserComment(_exifEnvelope));
      final truncated = Uint8List.sublistView(complete, 0, complete.length - 9);

      final direct = UnifiedMetadataParser.parseFromImageWithoutPixelDecode(
        truncated,
      );

      expect(direct?.success, isFalse);
      expect(direct?.errorMessage, contains('Truncated WebP RIFF container'));
      expectSameParseResult(
        direct,
        UnifiedMetadataParser.parseFromImage(truncated),
      );
    });

    test('EXIF still wins over the stealth payload when both exist', () {
      final bytes = _withUserComment(asciiUserComment(_exifEnvelope));

      final direct = UnifiedMetadataParser.parseFromImageWithoutPixelDecode(
        bytes,
      );

      _expectExifMetadata(direct!);
      expectSameParseResult(
        direct,
        UnifiedMetadataParser.parseFromImage(bytes),
      );
    });
  });

  test(
    'file parsing reads the real layout through the gradual reader',
    () async {
      final directory = await Directory.systemTemp.createTemp('webp-layout-');
      addTearDown(() => directory.delete(recursive: true));
      final exifFile = File('${directory.path}/exif.webp')
        ..writeAsBytesSync(_withUserComment(asciiUserComment(_exifEnvelope)));
      final stealthFile = File('${directory.path}/stealth.webp')
        ..writeAsBytesSync(novelAiLayoutWebp(exif: rewrittenCameraExif()));

      _expectExifMetadata(UnifiedMetadataParser.parseFromFile(exifFile.path));
      _expectStealthMetadata(
        UnifiedMetadataParser.parseFromFile(stealthFile.path),
      );
    },
  );
}
