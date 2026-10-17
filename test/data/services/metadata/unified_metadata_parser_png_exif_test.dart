import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/metadata_file_repository.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/exif_orientation_fixture.dart' show withPngExif;
import '../../../helpers/metadata_parse_result_expectations.dart';
import '../../../helpers/novelai_exif_fixture.dart';
import '../../../helpers/novelai_jpeg_layout_fixture.dart';
import '../../../helpers/novelai_webp_layout_fixture.dart';
import '../../../helpers/stealth_png_fixture.dart';

const _exifPrompt = '1girl, png exif prompt, 中文提示词';
const _exifSeed = 864209753;
const _exifFormat = 'NovelAI PNG EXIF';

Uint8List _plainPng() =>
    Uint8List.fromList(img.encodePng(img.Image(width: 16, height: 16)));

Uint8List _naiExifTiff(String prompt) => Uint8List.fromList(
  novelAiExif(
    userComment: asciiUserComment(
      novelAiEnvelopeJson(prompt: prompt, seed: _exifSeed),
    ),
  ),
);

void _expectExifMetadata(MetadataParseResult result, {String? prompt}) {
  expect(result.success, isTrue, reason: result.errorMessage);
  expect(result.sourceFormat, _exifFormat);
  expect(result.metadata?.prompt, prompt ?? _exifPrompt);
  expect(result.metadata?.seed, _exifSeed);
  expect(result.metadata?.source, novelAiV45FullSource);
}

void main() {
  test('reads the UserComment of an eXIf chunk when no text chunk exists', () {
    final bytes = withPngExif(_plainPng(), _naiExifTiff(_exifPrompt));

    final direct = UnifiedMetadataParser.parseFromImageWithoutPixelDecode(
      bytes,
    );

    _expectExifMetadata(direct!);
    expectSameParseResult(direct, UnifiedMetadataParser.parseFromImage(bytes));
  });

  group('derived PNGs that carry only the source EXIF', () {
    test('a NovelAI JPEG source stays readable', () {
      final derived = UnifiedMetadataParser.copySupportedMetadata(
        source: novelAiLayoutJpeg(exifTiffs: [_naiExifTiff(_exifPrompt)]),
        targetPng: _plainPng(),
      );

      _expectExifMetadata(UnifiedMetadataParser.parseFromImage(derived));
    });

    test('a NovelAI WebP source stays readable', () {
      final derived = UnifiedMetadataParser.copySupportedMetadata(
        source: novelAiLayoutWebp(exif: _naiExifTiff(_exifPrompt)),
        targetPng: _plainPng(),
      );

      _expectExifMetadata(UnifiedMetadataParser.parseFromImage(derived));
    });
  });

  group('order against the other PNG sources', () {
    test('text chunks with generation data win over eXIf', () {
      final bytes = withPngExif(
        UnifiedMetadataParser.embedTextChunkOnly(
          _plainPng(),
          'Comment',
          jsonEncode({'prompt': 'text chunk prompt', 'seed': 3, 'steps': 28}),
        ),
        _naiExifTiff(_exifPrompt),
      );

      final result = UnifiedMetadataParser.parseFromImage(bytes);

      expect(result.success, isTrue, reason: result.errorMessage);
      expect(result.sourceFormat, isNot(_exifFormat));
      expect(result.metadata?.prompt, 'text chunk prompt');
    });

    test('text chunks without generation data do not hide eXIf', () {
      final bytes = withPngExif(
        UnifiedMetadataParser.embedTextChunkOnly(
          _plainPng(),
          'Software',
          'GIMP 2.10',
        ),
        _naiExifTiff(_exifPrompt),
      );

      _expectExifMetadata(UnifiedMetadataParser.parseFromImage(bytes));
    });

    test(
      'eXIf without a UserComment falls through to the stealth payload',
      () async {
        final bytes = withPngExif(
          await stealthOnlyNovelAiPng('stealth prompt'),
          Uint8List.fromList(cameraExifTiff()),
        );

        expect(
          UnifiedMetadataParser.parseFromImageWithoutPixelDecode(bytes),
          isNull,
        );
        final result = UnifiedMetadataParser.parseFromImage(bytes);
        expect(result.sourceFormat, 'NovelAI stealth_pngcomp');
        expect(result.metadata?.prompt, 'stealth prompt');
      },
    );

    test('the last eXIf chunk wins like the web reader', () {
      final bytes = withPngExif(
        withPngExif(_plainPng(), _naiExifTiff('first chunk')),
        _naiExifTiff('last chunk'),
      );

      _expectExifMetadata(
        UnifiedMetadataParser.parseFromImage(bytes),
        prompt: 'last chunk',
      );
    });
  });

  test('a large PNG answers from the first gradual prefix', () async {
    final directory = await Directory.systemTemp.createTemp('png-exif-');
    addTearDown(() => directory.delete(recursive: true));
    final random = math.Random(7);
    final noise = img.Image(width: 300, height: 300, numChannels: 4);
    for (final pixel in noise) {
      pixel.setRgba(
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
        255,
      );
    }
    final bytes = withPngExif(
      Uint8List.fromList(img.encodePng(noise)),
      _naiExifTiff(_exifPrompt),
    );
    final firstPrefix = MetadataFileRepository.gradualReadThresholds.first;
    expect(bytes.length, greaterThan(firstPrefix));
    final file = File('${directory.path}/large.png')..writeAsBytesSync(bytes);

    final result = UnifiedMetadataParser.parseFromFile(file.path);

    _expectExifMetadata(result);
    expect(result.bytesRead, firstPrefix);
  });
}
