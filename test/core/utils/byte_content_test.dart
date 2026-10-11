import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/byte_content.dart';

Uint8List _pattern(int length) =>
    Uint8List.fromList([for (var i = 0; i < length; i++) (i * 31 + 7) & 0xff]);

/// 同内容但起始偏移不是 8 的倍数的视图，用来覆盖非对齐读取。
Uint8List _unalignedCopy(Uint8List source, {int offset = 3}) {
  final backing = Uint8List(source.length + offset)..setAll(offset, source);
  return Uint8List.sublistView(backing, offset);
}

void main() {
  group('ByteContent.equals', () {
    test('同一实例与两侧都为 null 视为相等，单侧为 null 不等', () {
      final bytes = _pattern(16);

      expect(ByteContent.equals(bytes, bytes), isTrue);
      expect(ByteContent.equals(null, null), isTrue);
      expect(ByteContent.equals(bytes, null), isFalse);
      expect(ByteContent.equals(null, bytes), isFalse);
    });

    test('跨字长与尾段的各种长度下，内容相同的不同实例相等', () {
      for (final length in [0, 1, 7, 8, 9, 31, 32, 33, 100]) {
        final bytes = _pattern(length);

        expect(
          ByteContent.equals(bytes, Uint8List.fromList(bytes)),
          isTrue,
          reason: 'length $length',
        );
        expect(
          ByteContent.equals(bytes, _unalignedCopy(bytes)),
          isTrue,
          reason: 'unaligned length $length',
        );
      }
    });

    test('长度不同或任一字节不同都不相等', () {
      final bytes = _pattern(37);

      expect(ByteContent.equals(bytes, _pattern(36)), isFalse);
      for (final index in [0, 7, 8, 31, 32, 36]) {
        final changed = Uint8List.fromList(bytes)..[index] ^= 0x01;
        expect(
          ByteContent.equals(bytes, changed),
          isFalse,
          reason: 'byte $index',
        );
        expect(
          ByteContent.equals(_unalignedCopy(bytes), changed),
          isFalse,
          reason: 'unaligned byte $index',
        );
      }
    });
  });

  group('ByteContent.fingerprint', () {
    test('与 xxHash64 官方测试向量一致', () {
      int hashOf(String text) =>
          ByteContent.fingerprint(Uint8List.fromList(utf8.encode(text)));

      expect(hashOf(''), 0xEF46DB3751D8E999);
      expect(hashOf('a'), 0xD24EC4F1A98C6E5B);
      expect(hashOf('abc'), 0x44BC2CF5AD770999);
      expect(
        hashOf('Nobody inspects the spammish repetition'),
        0xFBCEA83C8A378BF1,
      );
    });

    test('覆盖 8 字节尾段与多段边界的长度与参考实现一致', () {
      const expected = {
        8: 0x3DA5C7AA269683E0,
        16: 0xA19AD429B02BC413,
        40: 0x49B45332E280F187,
        63: 0x5C320A0D2707057F,
        64: 0x7BBABBC45729D17E,
        65: 0xF3980C34BAE65DC1,
        100: 0xEFA0AD2D3E70C151,
      };
      for (final MapEntry(key: length, value: hash) in expected.entries) {
        expect(
          ByteContent.fingerprint(_pattern(length)),
          hash,
          reason: 'length $length',
        );
        expect(
          ByteContent.fingerprint(_unalignedCopy(_pattern(length))),
          hash,
          reason: 'unaligned length $length',
        );
      }
    });

    test('单个比特变化会改变指纹', () {
      final bytes = _pattern(100);
      final changed = Uint8List.fromList(bytes)..[57] ^= 0x80;

      expect(
        ByteContent.fingerprint(changed),
        isNot(ByteContent.fingerprint(bytes)),
      );
    });
  });
}
