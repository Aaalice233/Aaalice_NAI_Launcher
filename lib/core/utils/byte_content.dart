import 'dart:typed_data';

/// 整张原图在 UI isolate 上的内容判等与指纹：按 8 字节字长处理，避免逐元素泛型比较与 SHA-256。
abstract final class ByteContent {
  /// 两侧都为 null 时视为相等。
  static bool equals(Uint8List? left, Uint8List? right) {
    if (identical(left, right)) return true;
    if (left == null || right == null || left.length != right.length) {
      return false;
    }
    final length = left.length;
    final wordEnd = length - length % 8;
    final leftWords = ByteData.sublistView(left);
    final rightWords = ByteData.sublistView(right);
    for (var offset = 0; offset < wordEnd; offset += 8) {
      if (leftWords.getUint64(offset, Endian.host) !=
          rightWords.getUint64(offset, Endian.host)) {
        return false;
      }
    }
    for (var offset = wordEnd; offset < length; offset++) {
      if (left[offset] != right[offset]) return false;
    }
    return true;
  }

  /// xxHash64（seed 0）。只用于内存内的去重与缓存键，不能替代持久化的校验摘要。
  static int fingerprint(Uint8List bytes) {
    final length = bytes.length;
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    int hash;
    if (length >= 32) {
      var lane1 = _prime1 + _prime2;
      var lane2 = _prime2;
      var lane3 = 0;
      var lane4 = -_prime1;
      final stripeEnd = length - length % 32;
      for (; offset < stripeEnd; offset += 32) {
        lane1 = _round(lane1, data.getUint64(offset, Endian.little));
        lane2 = _round(lane2, data.getUint64(offset + 8, Endian.little));
        lane3 = _round(lane3, data.getUint64(offset + 16, Endian.little));
        lane4 = _round(lane4, data.getUint64(offset + 24, Endian.little));
      }
      hash =
          _rotateLeft(lane1, 1) +
          _rotateLeft(lane2, 7) +
          _rotateLeft(lane3, 12) +
          _rotateLeft(lane4, 18);
      hash = _mergeLane(hash, lane1);
      hash = _mergeLane(hash, lane2);
      hash = _mergeLane(hash, lane3);
      hash = _mergeLane(hash, lane4);
    } else {
      hash = _prime5;
    }
    hash += length;
    for (; offset + 8 <= length; offset += 8) {
      final lane = _round(0, data.getUint64(offset, Endian.little));
      hash = _rotateLeft(hash ^ lane, 27) * _prime1 + _prime4;
    }
    if (offset + 4 <= length) {
      final word = data.getUint32(offset, Endian.little);
      hash = _rotateLeft(hash ^ (word * _prime1), 23) * _prime2 + _prime3;
      offset += 4;
    }
    for (; offset < length; offset++) {
      hash = _rotateLeft(hash ^ (bytes[offset] * _prime5), 11) * _prime1;
    }
    hash ^= hash >>> 33;
    hash *= _prime2;
    hash ^= hash >>> 29;
    hash *= _prime3;
    return hash ^ (hash >>> 32);
  }

  static const int _prime1 = 0x9E3779B185EBCA87;
  static const int _prime2 = 0xC2B2AE3D27D4EB4F;
  static const int _prime3 = 0x165667B19E3779F9;
  static const int _prime4 = 0x85EBCA77C2B2AE63;
  static const int _prime5 = 0x27D4EB2F165667C5;

  static int _rotateLeft(int value, int bits) =>
      (value << bits) | (value >>> (64 - bits));

  static int _round(int lane, int input) =>
      _rotateLeft(lane + input * _prime2, 31) * _prime1;

  static int _mergeLane(int hash, int lane) =>
      (hash ^ _round(0, lane)) * _prime1 + _prime4;
}
