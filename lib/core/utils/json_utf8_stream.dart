import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 把 JSON 直接流式编码为 UTF-8 并摘要，不在内存中拼出完整字符串与字节数组。
abstract final class JsonUtf8Stream {
  static const int _chunkSize = 64 * 1024;

  /// 与 `sha256.convert(utf8.encode(jsonEncode(value)))` 相同。
  static Digest sha256Digest(Object? value) {
    late Digest digest;
    final hashing = sha256.startChunkedConversion(
      ChunkedConversionSink.withCallback((digests) => digest = digests.single),
    );
    _encoder.startChunkedConversion(hashing).add(value);
    return digest;
  }

  static JsonUtf8Encoder get _encoder =>
      JsonUtf8Encoder(null, null, _chunkSize);
}
