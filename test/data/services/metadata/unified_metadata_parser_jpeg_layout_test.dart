import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/api_constants.dart';
import 'package:nai_launcher/core/utils/exif_container.dart';
import 'package:nai_launcher/data/services/metadata/metadata_file_repository.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

import '../../../helpers/metadata_parse_result_expectations.dart';
import '../../../helpers/novelai_exif_fixture.dart';
import '../../../helpers/novelai_jpeg_layout_fixture.dart';

const _exifPrompt = '1girl, jpeg exif prompt, 中文提示词';
const _exifSeed = 1029384756;
const _exifFormat = 'NovelAI JPEG EXIF';

final String _exifEnvelope = novelAiEnvelopeJson(
  prompt: _exifPrompt,
  seed: _exifSeed,
);

Uint8List _withUserComment(
  List<int> userComment, {
  Endian endian = Endian.big,
}) => novelAiLayoutJpeg(
  exifTiffs: [novelAiExif(userComment: userComment, endian: endian)],
);

/// 没有 Software/Source 的信封，模型来源只能取自 IFD0。
String _envelopeWithoutAttribution(String prompt) {
  final envelope =
      jsonDecode(novelAiEnvelopeJson(prompt: prompt, seed: _exifSeed))
            as Map<String, dynamic>
        ..remove('Software')
        ..remove('Source');
  return jsonEncode(envelope);
}

List<int> _naiExifTiff(String prompt) => novelAiExif(
  userComment: asciiUserComment(
    novelAiEnvelopeJson(prompt: prompt, seed: _exifSeed),
  ),
);

/// 截到 [marker] 段的第 [into] 个字节；该段不存在时抛出。
Uint8List _cutInside(Uint8List jpeg, int marker, {int into = 3}) {
  var offset = 2;
  while (offset + 4 <= jpeg.length) {
    if (jpeg[offset + 1] == marker) {
      return Uint8List.sublistView(jpeg, 0, offset + into);
    }
    offset += 2 + ((jpeg[offset + 2] << 8) | jpeg[offset + 3]);
  }
  throw StateError('JPEG has no segment 0x${marker.toRadixString(16)}');
}

void _expectExifMetadata(MetadataParseResult result, {String? prompt}) {
  expect(result.success, isTrue, reason: result.errorMessage);
  expect(result.sourceFormat, _exifFormat);
  expect(result.metadata?.prompt, prompt ?? _exifPrompt);
  expect(result.metadata?.seed, _exifSeed);
}

void _expectNoMetadata(MetadataParseResult result) {
  expect(result.success, isFalse);
  expect(result.errorMessage, startsWith('No EXIF UserComment metadata'));
  expect(result.triedParsers, ['JPEG EXIF']);
}

void main() {
  test('fixture keeps the libjpeg segment order with EXIF after JFIF', () {
    final bytes = _withUserComment(asciiUserComment(_exifEnvelope));

    expect(
      [
        for (final (:marker, payload: _) in ExifContainer.jpegHeaderSegments(
          bytes,
        ))
          marker,
      ],
      [0xE0, 0xE1, 0xDB, 0xC0, 0xC4, 0xDA],
    );
    expect(bytes.sublist(bytes.length - 2), [0xFF, 0xD9]);
  });

  group('EXIF UserComment', () {
    test('reads the ASCII-prefixed envelope NovelAI writes', () {
      final result = UnifiedMetadataParser.parseFromImage(
        _withUserComment(asciiUserComment(_exifEnvelope)),
      );

      _expectExifMetadata(result);
      expect(result.rawData, _exifEnvelope);
      expect(result.metadata?.source, novelAiV45FullSource);
      expect(result.metadata?.software, 'NovelAI');
      expect(result.metadata?.model, ImageModels.animeDiffusionV45Full);
      expect(result.metadata?.prompt, contains('中文提示词'));
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

    test('reads a little-endian TIFF rewritten by another tool', () {
      _expectExifMetadata(
        UnifiedMetadataParser.parseFromImage(
          _withUserComment(
            asciiUserComment(_exifEnvelope),
            endian: Endian.little,
          ),
        ),
      );
    });

    test('takes Source from either NovelAI IFD0 layout', () {
      for (final layout in NovelAiExifIfd0Layout.values) {
        final result = UnifiedMetadataParser.parseFromImage(
          novelAiLayoutJpeg(
            exifTiffs: [
              novelAiExif(
                userComment: asciiUserComment(
                  _envelopeWithoutAttribution(_exifPrompt),
                ),
                layout: layout,
                prompt: _exifPrompt,
              ),
            ],
          ),
        );

        _expectExifMetadata(result);
        expect(
          result.metadata?.source,
          novelAiV45FullSource,
          reason: layout.name,
        );
      }
    });

    test('answers without a pixel decode exactly like the full parser', () {
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

  group('without NovelAI EXIF', () {
    test('a JPEG without EXIF reports no metadata without pixels', () {
      final bytes = novelAiLayoutJpeg();

      final direct = UnifiedMetadataParser.parseFromImageWithoutPixelDecode(
        bytes,
      );

      _expectNoMetadata(direct!);
      expectSameParseResult(
        direct,
        UnifiedMetadataParser.parseFromImage(bytes),
      );
      expect(UnifiedMetadataParser.readsStealthPayload(bytes), isTrue);
    });

    test('a camera EXIF without UserComment is not damage', () {
      _expectNoMetadata(
        UnifiedMetadataParser.parseFromImage(
          novelAiLayoutJpeg(exifTiffs: [cameraExifTiff()]),
        ),
      );
    });

    test('a comment that is not a metadata envelope fails the decoders', () {
      final result = UnifiedMetadataParser.parseFromImage(
        _withUserComment(asciiUserComment('not json at all')),
      );

      expect(result.success, isFalse);
      expect(result.triedParsers.first, 'JPEG EXIF');
      expect(result.errorMessage, contains('No parser could extract'));
    });
  });

  group('picks the EXIF segment the web reader picks', () {
    test('an APP1 that is not a TIFF structure loses to a valid one', () {
      final result = UnifiedMetadataParser.parseFromImage(
        novelAiLayoutJpeg(
          exifTiffs: [
            ascii.encode('garbage exif payload'),
            _naiExifTiff(_exifPrompt),
          ],
        ),
      );

      _expectExifMetadata(result);
    });

    test('equal directories prefer the longer segment, then the first', () {
      const short = 'short prompt';
      const long = 'a considerably longer prompt that makes a longer segment';

      for (final order in [
        [short, long],
        [long, short],
      ]) {
        final result = UnifiedMetadataParser.parseFromImage(
          novelAiLayoutJpeg(
            exifTiffs: [for (final p in order) _naiExifTiff(p)],
          ),
        );
        _expectExifMetadata(result, prompt: long);
      }

      final tie = UnifiedMetadataParser.parseFromImage(
        novelAiLayoutJpeg(
          exifTiffs: [_naiExifTiff('prompt one'), _naiExifTiff('prompt two')],
        ),
      );
      _expectExifMetadata(tie, prompt: 'prompt one');
    });

    test('more IFD0 entries win even without a UserComment', () {
      _expectNoMetadata(
        UnifiedMetadataParser.parseFromImage(
          novelAiLayoutJpeg(
            exifTiffs: [_naiExifTiff(_exifPrompt), cameraExifTiff()],
          ),
        ),
      );
    });
  });

  group('truncated files', () {
    test('missing image data keeps the header metadata', () {
      final complete = _withUserComment(asciiUserComment(_exifEnvelope));

      _expectExifMetadata(
        UnifiedMetadataParser.parseFromImage(
          Uint8List.sublistView(complete, 0, complete.length - 40),
        ),
      );
    });

    test('a header cut after the EXIF segment still yields it', () {
      _expectExifMetadata(
        UnifiedMetadataParser.parseFromImage(
          _cutInside(_withUserComment(asciiUserComment(_exifEnvelope)), 0xDB),
        ),
      );
    });

    test('a header cut inside the EXIF segment fails', () {
      final result = UnifiedMetadataParser.parseFromImage(
        _cutInside(
          _withUserComment(asciiUserComment(_exifEnvelope)),
          0xE1,
          into: 40,
        ),
      );

      expect(result.success, isFalse);
      expect(result.triedParsers, ['JPEG EXIF']);
    });
  });

  group('gradual file reads', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('jpeg-layout-');
    });

    tearDown(() => directory.delete(recursive: true));

    final firstPrefix = MetadataFileRepository.gradualReadThresholds[0];
    final secondPrefix = MetadataFileRepository.gradualReadThresholds[1];

    /// 熵编码数据之后补零，模拟大图；头部之外的字节不影响元数据。
    String writeJpeg(String name, Uint8List jpeg, {required int size}) {
      final file = File('${directory.path}/$name')
        ..writeAsBytesSync([...jpeg, ...Uint8List(size - jpeg.length)]);
      return file.path;
    }

    test('the first prefix answers a JPEG with EXIF', () {
      final result = UnifiedMetadataParser.parseFromFile(
        writeJpeg(
          'exif.jpg',
          _withUserComment(asciiUserComment(_exifEnvelope)),
          size: secondPrefix + 1024,
        ),
      );

      _expectExifMetadata(result);
      expect(result.bytesRead, firstPrefix);
    });

    test('a complete header without EXIF ends the reads at once', () {
      final result = UnifiedMetadataParser.parseFromFile(
        writeJpeg('plain.jpg', novelAiLayoutJpeg(), size: secondPrefix + 1024),
      );

      _expectNoMetadata(result);
      expect(result.bytesRead, firstPrefix);
    });

    test('a header longer than the prefix reads on to the EXIF', () {
      final padding = [
        for (var index = 0; index < 2; index++) ...[
          0xFF,
          0xE2,
          0xFF,
          0xFF,
          ...Uint8List(0xFFFF - 2),
        ],
      ];
      final jpeg = novelAiLayoutJpeg(
        exifTiffs: [novelAiExif(userComment: asciiUserComment(_exifEnvelope))],
      );
      final padded = Uint8List.fromList([
        ...jpeg.sublist(0, 2),
        ...padding,
        ...jpeg.sublist(2),
      ]);

      final result = UnifiedMetadataParser.parseFromFile(
        writeJpeg('long-header.jpg', padded, size: secondPrefix + 1024),
      );

      _expectExifMetadata(result);
      expect(result.bytesRead, secondPrefix);
    });
  });
}
