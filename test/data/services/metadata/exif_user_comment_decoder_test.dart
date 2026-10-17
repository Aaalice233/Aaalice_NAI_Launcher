import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/metadata/exif_user_comment_decoder.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

List<int> _utf16(List<int> units, Endian endian) {
  final data = ByteData(units.length * 2);
  for (var index = 0; index < units.length; index++) {
    data.setUint16(index * 2, units[index], endian);
  }
  return data.buffer.asUint8List();
}

final List<int> _unicodePrefix = ascii.encode('UNICODE\u0000');

void main() {
  group('ExifUserCommentDecoder', () {
    test('strips the ASCII prefix and decodes the rest as UTF-8', () {
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([
            ...ascii.encode('ASCII\u0000\u0000\u0000'),
            ...utf8.encode('{"prompt":"中文"}'),
          ]),
        ),
        '{"prompt":"中文"}',
      );
    });

    test('strips an UNDEFINED prefix of eight zero bytes', () {
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([...List.filled(8, 0), ...utf8.encode('{"a":1}')]),
        ),
        '{"a":1}',
      );
    });

    test('decodes unknown prefixes together with the prefix bytes', () {
      expect(
        ExifUserCommentDecoder.decode(_bytes(utf8.encode('{"prompt":"x"}'))),
        '{"prompt":"x"}',
      );
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([...ascii.encode('JIS\u0000\u0000\u0000\u0000\u0000'), 0x41]),
        ),
        'JIS\u0000\u0000\u0000\u0000\u0000A',
      );
    });

    test('replaces malformed UTF-8 instead of failing', () {
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([...ascii.encode('ASCII\u0000\u0000\u0000'), 0x41, 0xff]),
        ),
        'A\uFFFD',
      );
    });

    test('drops a UTF-8 byte order mark after the prefix', () {
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([
            ...ascii.encode('ASCII\u0000\u0000\u0000'),
            0xef,
            0xbb,
            0xbf,
            0x41,
          ]),
        ),
        'A',
      );
    });

    test('decodes UNICODE as UTF-16 chosen by the byte order mark', () {
      const text = '中文 😀';
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([
            ..._unicodePrefix,
            ..._utf16([0xfeff, ...text.codeUnits], Endian.little),
          ]),
        ),
        text,
      );
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([
            ..._unicodePrefix,
            ..._utf16([0xfeff, ...text.codeUnits], Endian.big),
          ]),
        ),
        text,
      );
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([..._unicodePrefix, ..._utf16(text.codeUnits, Endian.big)]),
        ),
        text,
      );
    });

    test('replaces lone surrogates and an odd trailing byte', () {
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([
            ..._unicodePrefix,
            ..._utf16([0x0041, 0xd800, 0x0042, 0xdc00], Endian.big),
            0x43,
          ]),
        ),
        'A\uFFFDB\uFFFD\uFFFD',
      );
    });

    test('trims trailing NUL characters', () {
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([...ascii.encode('ASCII\u0000\u0000\u0000'), 0x41, 0, 0]),
        ),
        'A',
      );
      expect(
        ExifUserCommentDecoder.decode(
          _bytes([
            ..._unicodePrefix,
            ..._utf16([0x0041, 0x0000], Endian.big),
          ]),
        ),
        'A',
      );
    });

    test('returns null for short or empty comments', () {
      expect(
        ExifUserCommentDecoder.decode(_bytes(ascii.encode('ASCII'))),
        isNull,
      );
      expect(
        ExifUserCommentDecoder.decode(
          _bytes(ascii.encode('ASCII\u0000\u0000\u0000')),
        ),
        isNull,
      );
      expect(ExifUserCommentDecoder.decode(_bytes(List.filled(12, 0))), isNull);
    });
  });
}
