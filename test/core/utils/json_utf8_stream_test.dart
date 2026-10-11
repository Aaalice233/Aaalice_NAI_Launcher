import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/json_utf8_stream.dart';

void main() {
  final values = <String, Object?>{
    'null': null,
    'scalars': [true, false, 0, -1, 1.5, 1e21, 0.1 + 0.2],
    'escapes': '"quote" \\ / \b\f\n\r\t \u0000 \u001f',
    'unicode': '中文 Ünïcödé 😀 \u{10FFFF}',
    'lone surrogates': '\ud800 lead, \udc00 trail, \udbff\ud800 reversed',
    'nested': {
      'list': [
        {'a': 1},
        [],
        {},
      ],
      'map': {'中': '文', '': ''},
    },
    'spans many chunks': 'x' * (200 * 1024 + 7),
  };

  for (final MapEntry(key: name, :value) in values.entries) {
    test('$name matches the materialized UTF-8 JSON', () {
      final bytes = utf8.encode(jsonEncode(value));

      expect(JsonUtf8Stream.byteLength(value), bytes.length);
      expect(JsonUtf8Stream.sha256Digest(value), sha256.convert(bytes));
    });
  }

  test('serializes objects through toJson like jsonEncode', () {
    const value = [_Encodable('a'), _Encodable('中')];
    final bytes = utf8.encode(jsonEncode(value));

    expect(JsonUtf8Stream.byteLength(value), bytes.length);
    expect(JsonUtf8Stream.sha256Digest(value), sha256.convert(bytes));
  });
}

final class _Encodable {
  const _Encodable(this.name);

  final String name;

  Map<String, Object?> toJson() => {'name': name};
}
