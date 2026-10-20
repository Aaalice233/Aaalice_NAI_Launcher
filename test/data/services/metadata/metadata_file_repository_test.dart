import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';
import 'package:nai_launcher/data/services/metadata/image_metadata_parser_service.dart';
import 'package:nai_launcher/data/services/metadata/metadata_file_repository.dart';
import 'package:nai_launcher/data/services/metadata/metadata_parse_result.dart';

import '../../../helpers/novelai_exif_fixture.dart';
import '../../../helpers/novelai_webp_layout_fixture.dart';
import '../../../helpers/riff_webp_builder.dart';

void main() {
  const thresholds = MetadataFileRepository.gradualReadThresholds;
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('gradual-read-');
  });

  tearDown(() => directory.delete(recursive: true));

  /// 记录每次交给解析器的字节长度，即渐进读取实际读了哪几段。
  ({MetadataParseResult result, List<int> reads}) parseFile(
    String name,
    Uint8List bytes,
  ) {
    final file = File('${directory.path}/$name')..writeAsBytesSync(bytes);
    final service = ImageMetadataParserService();
    final reads = <int>[];
    final result = const MetadataFileRepository().parse(
      file.path,
      parseBytes: (prefix, path) {
        reads.add(prefix.length);
        return service.parseFromImage(prefix, filePathForLog: path);
      },
      statistics: ParseStatistics(),
    );
    return (result: result, reads: reads);
  }

  test('a WebP prefix jumps straight to the whole file', () {
    final webp = _paddedLayoutWebp(
      novelAiExif(
        userComment: asciiUserComment(
          novelAiEnvelopeJson(prompt: 'end of file prompt', seed: 8),
        ),
      ),
      padding: thresholds[1],
    );
    expect(webp.length, inInclusiveRange(thresholds[1], thresholds[2]));

    final (:result, :reads) = parseFile('large.webp', webp);

    expect(result.success, isTrue);
    expect(result.metadata!.prompt, 'end of file prompt');
    expect(reads, [thresholds[0], webp.length]);
  });

  test('a PNG past its leading chunks reads the whole file next', () {
    final png = _noisePng(side: 600);
    expect(png.length, inInclusiveRange(thresholds[1], thresholds[2]));

    final (:result, :reads) = parseFile('stealth-candidate.png', png);

    expect(result.success, isFalse);
    expect(reads, [thresholds[0], png.length]);
  });

  test('a PNG text chunk longer than the prefix keeps growing it', () {
    final prompt = 'long prompt ${'x' * (thresholds[0] * 2)}';
    final png = ImageMetadataContainerCodec.embedTextChunkOnly(
      _noisePng(side: 600),
      'Comment',
      jsonEncode({'prompt': prompt, 'seed': 3}),
    );
    expect(png.length, greaterThan(thresholds[1]));

    final (:result, :reads) = parseFile('long-text.png', png);

    expect(result.success, isTrue);
    expect(result.metadata!.prompt, prompt);
    expect(reads, [thresholds[0], thresholds[1]]);
  });

  test('a prefix cut inside a text chunk fails cleanly on its own buffer', () {
    final png = ImageMetadataContainerCodec.embedTextChunkOnly(
      _noisePng(side: 64),
      'Comment',
      jsonEncode({'prompt': 'x' * (thresholds[0] * 2)}),
    );
    // 独立 buffer 与文件读出的前缀一致；视图背后的完整数据会掩盖越界读取
    final prefix = Uint8List.fromList(png.sublist(0, thresholds[0]));

    final result = ImageMetadataParserService().parseFromImage(prefix);

    expect(result.success, isFalse);
    expect(
      result.errorMessage,
      'No parser could extract metadata from 0 fields',
    );
    expect(result.prefixVerdict, MetadataPrefixVerdict.needsMoreBytes);
  });

  test('pngReachesEnd needs the whole IEND chunk', () {
    final png = _noisePng(side: 16);

    expect(ImageMetadataContainerCodec.pngReachesEnd(png), isTrue);
    expect(
      ImageMetadataContainerCodec.pngReachesEnd(
        Uint8List.sublistView(png, 0, png.length - 1),
      ),
      isFalse,
    );
  });

  test('pngReachesImageData only answers once IDAT has started', () {
    final png = _noisePng(side: 64);
    final idat = _firstChunkOffset(png, 'IDAT');

    expect(
      ImageMetadataContainerCodec.pngReachesImageData(
        Uint8List.sublistView(png, 0, idat + 8),
      ),
      isTrue,
    );
    expect(
      ImageMetadataContainerCodec.pngReachesImageData(
        Uint8List.sublistView(png, 0, idat + 7),
      ),
      isFalse,
    );
  });
}

/// 官网块顺序的 WebP，EXIF 之前插一段未知块把文件撑大。
Uint8List _paddedLayoutWebp(List<int> exif, {required int padding}) {
  final chunks = Uint8List.fromList(novelAiStealthWebp.sublist(12));
  chunks[8] |= 0x08;
  return riffWebp([
    ...chunks,
    ...riffChunk('XPAD', Uint8List(padding)),
    ...riffChunk('EXIF', exif),
  ]);
}

/// 随机像素压不下去，边长决定文件大小。
Uint8List _noisePng({required int side}) {
  final random = math.Random(side);
  final image = img.Image(width: side, height: side, numChannels: 4);
  for (final pixel in image) {
    pixel.setRgba(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      255,
    );
  }
  return Uint8List.fromList(img.encodePng(image));
}

int _firstChunkOffset(Uint8List png, String type) {
  final view = ByteData.sublistView(png);
  var offset = 8;
  while (latin1.decode(png.sublist(offset + 4, offset + 8)) != type) {
    offset += 12 + view.getUint32(offset);
  }
  return offset;
}
