import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 把 JSON 直接流式编码为 UTF-8 并计数或摘要，不在内存中拼出完整字符串与字节数组。
abstract final class JsonUtf8Stream {
  static const int _chunkSize = 64 * 1024;

  /// 与 `utf8.encode(jsonEncode(value)).length` 相同。
  static int byteLength(Object? value) {
    final counter = _ByteCounter();
    _encoder.startChunkedConversion(counter).add(value);
    return counter.length;
  }

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

final class _ByteCounter extends ByteConversionSink {
  int length = 0;

  @override
  void add(List<int> chunk) => length += chunk.length;

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) =>
      length += end - start;

  @override
  void close() {}
}
