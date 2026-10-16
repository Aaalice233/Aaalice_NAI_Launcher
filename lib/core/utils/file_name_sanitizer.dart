import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:path/path.dart' as p;

/// 把任意文本清洗成可跨 Windows / macOS / Android 落盘的单段文件或目录名。
abstract final class FileNameSanitizer {
  static const int _maxCodePoints = 180;

  // ext4、APFS 单段上限 255 字节，留出调用方再接的扩展名与重名序号。
  static const int _maxUtf8Bytes = 255 - 32;

  static final RegExp _illegal = RegExp(r'[\x00-\x1F\x7F"%*/:<>?\\|]');
  static final RegExp _trailingDotsAndSpaces = RegExp(r'[. ]+$');
  static final RegExp _reservedDeviceName = RegExp(
    r'^(CON|PRN|AUX|NUL|COM[0-9¹²³]|LPT[0-9¹²³])(\..*)?$',
    caseSensitive: false,
  );
  static final RegExp _extension = RegExp(r'^\.[A-Za-z0-9]{1,24}$');

  /// 清洗后没有可用内容时返回 [fallback]；默认空串，由调用方决定跳过或回落。
  ///
  /// [raw] 以 [protectedSuffix] 结尾时只截短前面的部分。
  static String segment(
    String raw, {
    String fallback = '',
    int maxCodePoints = _maxCodePoints,
    String protectedSuffix = '',
  }) {
    final suffix = raw.endsWith(protectedSuffix) ? protectedSuffix : '';
    final cleaned = _clean(
      raw.substring(0, raw.length - suffix.length),
      maxCodePoints: maxCodePoints - suffix.runes.length,
      maxUtf8Bytes: _maxUtf8Bytes - _utf8Length(suffix),
    );
    final base = cleaned.isEmpty ? fallback : cleaned;
    return base.isEmpty ? '' : '$base$suffix';
  }

  /// 任意来源的文件名：只取末段，形如扩展名的结尾转小写后保留。
  static String fileName(String name, {required String fallback}) {
    final leaf = p.basename(name);
    final extension = p.extension(leaf);
    if (!_extension.hasMatch(extension)) {
      return segment(leaf, fallback: fallback);
    }
    final lowerExtension = extension.toLowerCase();
    return segment(
      p.setExtension(leaf, lowerExtension),
      fallback: fallback,
      protectedSuffix: lowerExtension,
    );
  }

  /// 截短 [stem] 直到 UTF-16 长度不超过 [maxUtf16Units]，[protectedSuffix] 原样保留。
  static String fitLength(
    String stem,
    int maxUtf16Units, {
    String protectedSuffix = '',
  }) {
    if (stem.length <= maxUtf16Units) return stem;
    final hasSuffix =
        protectedSuffix.isNotEmpty && stem.endsWith(protectedSuffix);
    final suffix = hasSuffix ? protectedSuffix : '';
    final base = stem.substring(0, stem.length - suffix.length);
    final budget = maxUtf16Units - suffix.length;
    if (budget <= 0) return stem;
    final fitted = _truncate(
      base,
      maxUtf16Units: budget,
    ).replaceFirst(_trailingDotsAndSpaces, '').trim();
    return fitted.isEmpty ? stem : '$fitted$suffix';
  }

  static String _clean(
    String raw, {
    required int maxCodePoints,
    required int maxUtf8Bytes,
  }) {
    final truncated = _truncate(
      raw.replaceAll(_illegal, '_').trim(),
      maxCodePoints: maxCodePoints,
      maxUtf8Bytes: maxUtf8Bytes,
    );
    // Windows 会静默去掉结尾的点和空格，落盘路径就与记录的不一致。
    final stripped = truncated.replaceFirst(_trailingDotsAndSpaces, '').trim();
    if (stripped.isEmpty) return '';
    return _reservedDeviceName.hasMatch(stripped) ? '_$stripped' : stripped;
  }

  /// 按字素截断，不拆开 emoji 或组合字符；任一上限为 null 时不限制该单位。
  static String _truncate(
    String text, {
    int? maxCodePoints,
    int? maxUtf8Bytes,
    int? maxUtf16Units,
  }) {
    var codePoints = 0;
    var utf8Bytes = 0;
    var utf16Units = 0;
    final kept = StringBuffer();
    for (final grapheme in text.characters) {
      codePoints += grapheme.runes.length;
      utf8Bytes += _utf8Length(grapheme);
      utf16Units += grapheme.length;
      if ((maxCodePoints != null && codePoints > maxCodePoints) ||
          (maxUtf8Bytes != null && utf8Bytes > maxUtf8Bytes) ||
          (maxUtf16Units != null && utf16Units > maxUtf16Units)) {
        break;
      }
      kept.write(grapheme);
    }
    return kept.toString().trim();
  }

  static int _utf8Length(String text) => text.runes.fold(
    0,
    (sum, rune) =>
        sum +
        switch (rune) {
          < 0x80 => 1,
          < 0x800 => 2,
          < 0x10000 => 3,
          _ => 4,
        },
  );
}
