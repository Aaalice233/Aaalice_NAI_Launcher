import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/data/services/metadata/image_metadata_container_codec.dart';

void main() {
  late Uint8List source;
  setUp(() {
    final image = img.Image(width: 16, height: 12, numChannels: 4);
    image.setPixelRgba(3, 4, 12, 34, 56, 128);
    source = Uint8List.fromList(img.encodePng(image));
  });

  test('updates all fields once and preserves other chunks verbatim', () {
    final custom = _chunk(
      'tEXt',
      Uint8List.fromList(latin1.encode('Custom\x00untouched')),
    );
    final exif = _chunk(
      'eXIf',
      Uint8List.fromList([73, 73, 42, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    );
    source = _beforeEnd(source, [custom, exif]);
    final snapshot = Uint8List.fromList(source);
    final fields = {
      'Comment': '{"seed":123}',
      'Description': 'description',
      'Software': 'NovelAI',
      'Source': 'test',
    };
    final result = ImageMetadataContainerCodec.embedTextChunks(source, fields);
    expect(
      ImageMetadataContainerCodec.extractPngTextData(result),
      containsPair('Custom', 'untouched'),
    );
    for (final field in fields.entries) {
      expect(
        ImageMetadataContainerCodec.extractPngTextData(result)[field.key],
        field.value,
      );
    }
    final originalChunks = _chunks(source);
    final outputChunks = _chunks(result);
    for (final chunk in originalChunks) {
      expect(outputChunks.any((other) => _equal(chunk.raw, other.raw)), isTrue);
    }
    final idat = outputChunks.indexWhere((chunk) => chunk.type == 'IDAT');
    expect(
      outputChunks.take(idat).where((chunk) => chunk.type == 'tEXt').length,
      4,
    );
    expect(img.decodePng(result)!.getPixel(3, 4).a, 128);
    expect(source, orderedEquals(snapshot));
    _verifyCrcs(result);
  });

  test('removes duplicate tEXt iTXt zTXt values for replaced keywords', () {
    source = _beforeEnd(source, [
      _chunk('tEXt', Uint8List.fromList(latin1.encode('Comment\x00old'))),
      _chunk(
        'iTXt',
        Uint8List.fromList([
          ...latin1.encode('Comment'),
          0,
          0,
          0,
          0,
          0,
          ...utf8.encode('older'),
        ]),
      ),
      _chunk(
        'zTXt',
        Uint8List.fromList([
          ...latin1.encode('Comment'),
          0,
          0,
          ...ZLibCodec().encode(utf8.encode('oldest')),
        ]),
      ),
    ]);
    final result = ImageMetadataContainerCodec.embedTextChunks(source, {
      'Comment': 'new',
    });
    expect(
      _chunks(result)
          .where((chunk) => const {'tEXt', 'iTXt', 'zTXt'}.contains(chunk.type))
          .length,
      1,
    );
    expect(
      ImageMetadataContainerCodec.extractPngTextData(result)['Comment'],
      'new',
    );
    _verifyCrcs(result);
  });

  test('writes Unicode as iTXt and Latin-1 as tEXt', () {
    final result = ImageMetadataContainerCodec.embedTextChunks(source, {
      'Description': '\u4e2d\u6587\u306e\u753b\u50cf',
      'Software': 'NovelAI',
    });
    expect(_chunks(result).where((chunk) => chunk.type == 'iTXt').length, 1);
    expect(_chunks(result).where((chunk) => chunk.type == 'tEXt').length, 1);
    expect(
      ImageMetadataContainerCodec.extractPngTextData(result)['Description'],
      '\u4e2d\u6587\u306e\u753b\u50cf',
    );
    _verifyCrcs(result);
  });

  test('empty update is a no-op', () {
    expect(
      identical(
        ImageMetadataContainerCodec.embedTextChunks(source, {}),
        source,
      ),
      isTrue,
    );
  });

  test('rejects damaged CRC without changing the input', () {
    source[source.length - 1] ^= 1;
    final snapshot = Uint8List.fromList(source);
    expect(
      () => ImageMetadataContainerCodec.embedTextChunks(source, {
        'Comment': 'new',
      }),
      throwsFormatException,
    );
    expect(source, orderedEquals(snapshot));
  });

  test(
    'rejects missing end, trailing bytes, truncated payload and non-PNG',
    () {
      for (final invalid in [
        Uint8List.sublistView(source, 0, source.length - 12),
        Uint8List.fromList([...source, 0]),
        Uint8List.sublistView(source, 0, 20),
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([
          ...source.take(8),
          ...source.skip(source.length - 12),
        ]),
      ]) {
        expect(
          () => ImageMetadataContainerCodec.embedTextChunks(invalid, {
            'Comment': 'new',
          }),
          throwsFormatException,
        );
      }
    },
  );

  test('rejects invalid keywords', () {
    for (final keyword in ['', 'A\x00B', '\u4e2d', 'a' * 80]) {
      expect(
        () => ImageMetadataContainerCodec.embedTextChunks(source, {
          keyword: 'new',
        }),
        throwsArgumentError,
      );
    }
  });
}

List<({String type, Uint8List raw})> _chunks(Uint8List png) {
  final result = <({String type, Uint8List raw})>[];
  final view = ByteData.sublistView(png);
  var offset = 8;
  while (offset + 12 <= png.length) {
    final end = offset + 12 + view.getUint32(offset);
    result.add((
      type: latin1.decode(png.sublist(offset + 4, offset + 8)),
      raw: Uint8List.sublistView(png, offset, end),
    ));
    offset = end;
  }
  return result;
}

Uint8List _chunk(String type, Uint8List data) {
  final raw = Uint8List(data.length + 12);
  final view = ByteData.sublistView(raw);
  view.setUint32(0, data.length);
  raw.setRange(4, 8, latin1.encode(type));
  raw.setRange(8, 8 + data.length, data);
  view.setUint32(
    raw.length - 4,
    getCrc32(Uint8List.sublistView(raw, 4, raw.length - 4)),
  );
  return raw;
}

Uint8List _beforeEnd(Uint8List png, List<Uint8List> chunks) =>
    (BytesBuilder()
          ..add(Uint8List.sublistView(png, 0, png.length - 12))
          ..add(chunks.expand((chunk) => chunk).toList())
          ..add(Uint8List.sublistView(png, png.length - 12)))
        .takeBytes();

bool _equal(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void _verifyCrcs(Uint8List png) {
  for (final chunk in _chunks(png)) {
    expect(
      ByteData.sublistView(chunk.raw).getUint32(chunk.raw.length - 4),
      getCrc32(Uint8List.sublistView(chunk.raw, 4, chunk.raw.length - 4)),
    );
  }
}
