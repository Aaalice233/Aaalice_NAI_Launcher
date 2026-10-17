import 'dart:convert';
import 'dart:typed_data';

/// 按 NovelAI 官网前端的规则解码 EXIF UserComment：`UNICODE` 前缀走 UTF-16，其余一律宽松 UTF-8。
abstract final class ExifUserCommentDecoder {
  static const int _prefixLength = 8;
  static const String _unicodePrefix = 'UNICODE\u0000';
  static const String _asciiPrefix = 'ASCII\u0000\u0000\u0000';
  static const String _undefinedPrefix =
      '\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000';
  static const int _byteOrderMark = 0xFEFF;
  static const int _replacementCharacter = 0xFFFD;

  /// 不足 8 字节或解码后为空时返回 null。
  static String? decode(Uint8List bytes) {
    if (bytes.length < _prefixLength) return null;
    final prefix = String.fromCharCodes(bytes, 0, _prefixLength);
    final body = Uint8List.sublistView(bytes, _prefixLength);
    final String text;
    if (prefix == _unicodePrefix) {
      text = _decodeUtf16(body);
    } else if (prefix == _asciiPrefix || prefix == _undefinedPrefix) {
      text = _decodeUtf8(body);
    } else {
      // 官网对未知前缀不剥离，整段按 UTF-8 解码
      text = _decodeUtf8(bytes);
    }
    final trimmed = _withoutTrailingNul(text);
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _decodeUtf8(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return text.startsWith(String.fromCharCode(_byteOrderMark))
        ? text.substring(1)
        : text;
  }

  /// 有 `FF FE` BOM 按小端，否则按大端；BOM 本身不进结果，残缺的代理对与奇数尾字节记为 U+FFFD。
  static String _decodeUtf16(Uint8List bytes) {
    final endian = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE
        ? Endian.little
        : Endian.big;
    final view = ByteData.sublistView(bytes);
    final output = StringBuffer();
    int? pendingLead;
    for (var offset = 0; offset + 1 < bytes.length; offset += 2) {
      final unit = view.getUint16(offset, endian);
      if (offset == 0 && unit == _byteOrderMark) continue;
      if (pendingLead != null) {
        final lead = pendingLead;
        pendingLead = null;
        if (_isTrailSurrogate(unit)) {
          output.writeCharCode(
            0x10000 + ((lead - 0xD800) << 10) + (unit - 0xDC00),
          );
          continue;
        }
        output.writeCharCode(_replacementCharacter);
      }
      if (_isLeadSurrogate(unit)) {
        pendingLead = unit;
      } else if (_isTrailSurrogate(unit)) {
        output.writeCharCode(_replacementCharacter);
      } else {
        output.writeCharCode(unit);
      }
    }
    if (pendingLead != null || bytes.length.isOdd) {
      output.writeCharCode(_replacementCharacter);
    }
    return output.toString();
  }

  static bool _isLeadSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  static bool _isTrailSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

  static String _withoutTrailingNul(String text) {
    var end = text.length;
    while (end > 0 && text.codeUnitAt(end - 1) == 0) {
      end--;
    }
    return text.substring(0, end);
  }
}
