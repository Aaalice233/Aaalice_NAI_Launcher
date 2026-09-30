/// L2 元数据缓存值编码：`t<写入毫秒>|<元数据 JSON>`。
///
/// 旧版本直接存元数据 JSON，照常可读，写入时间按最旧处理。
abstract final class MetadataCacheEntryCodec {
  static const int legacyWrittenAtMillis = 0;

  static const String _timestampTag = 't';
  static const String _separator = '|';
  static const String _legacyJsonStart = '{';
  // 头部最多是标记 + 16 位毫秒 + 分隔符，超出后不再向 JSON 里查找
  static const int _maxHeaderLength = 18;

  static String encode(String metadataJson, {required int writtenAtMillis}) =>
      '$_timestampTag$writtenAtMillis$_separator$metadataJson';

  /// 元数据 JSON；无法识别的值返回 null
  static String? metadataJsonOf(String raw) {
    if (raw.startsWith(_legacyJsonStart)) return raw;
    final separator = _separatorIndex(raw);
    return separator < 0 ? null : raw.substring(separator + 1);
  }

  /// 写入时间；旧格式与无法识别的值视为最旧
  static int writtenAtMillisOf(String raw) {
    final separator = _separatorIndex(raw);
    if (separator < 0) return legacyWrittenAtMillis;
    return int.tryParse(raw.substring(_timestampTag.length, separator)) ??
        legacyWrittenAtMillis;
  }

  static int _separatorIndex(String raw) {
    if (!raw.startsWith(_timestampTag)) return -1;
    final end = raw.length < _maxHeaderLength ? raw.length : _maxHeaderLength;
    for (var index = _timestampTag.length; index < end; index++) {
      if (raw[index] == _separator) return index;
    }
    return -1;
  }
}
