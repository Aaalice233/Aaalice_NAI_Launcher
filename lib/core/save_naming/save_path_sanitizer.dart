import 'package:flutter/widgets.dart' show StringCharacters;

/// 把模板渲染结果清洗成可跨 Windows / macOS / Android 落盘的单段文件或目录名。
abstract final class SavePathSanitizer {
  static const int maxCodePoints = 180;

  // ext4、APFS 单段上限 255 字节，留出 "-999" 重名序号与 ".png"。
  static const int maxUtf8Bytes = 240;

  static final RegExp _illegal = RegExp(r'[\x00-\x1F\x7F"%*/:<>?\\|]');
  static final RegExp _trailingDotsAndSpaces = RegExp(r'[. ]+$');
  static final RegExp _reservedDeviceName = RegExp(
    r'^(CON|PRN|AUX|NUL|COM[0-9¹²³]|LPT[0-9¹²³])(\..*)?$',
    caseSensitive: false,
  );

  /// 返回空串表示该段没有可用内容，由调用方决定跳过或回落。
  ///
  /// [raw] 以 [protectedSuffix] 结尾时只截短前面的部分；前面为空时同样返回空串。
  static String segment(
    String raw, {
    int maxCodePoints = SavePathSanitizer.maxCodePoints,
    int maxUtf8Bytes = SavePathSanitizer.maxUtf8Bytes,
    String protectedSuffix = '',
  }) {
    if (protectedSuffix.isNotEmpty && raw.endsWith(protectedSuffix)) {
      final base = segment(
        raw.substring(0, raw.length - protectedSuffix.length),
        maxCodePoints: maxCodePoints - protectedSuffix.runes.length,
        maxUtf8Bytes: maxUtf8Bytes - utf8Length(protectedSuffix),
      );
      return base.isEmpty ? '' : '$base$protectedSuffix';
    }
    final replaced = raw.replaceAll(_illegal, '_').trim();
    final truncated = truncate(
      replaced,
      maxCodePoints: maxCodePoints,
      maxUtf8Bytes: maxUtf8Bytes,
    );
    // Windows 会静默去掉结尾的点和空格，落盘路径就与记录的不一致。
    final stripped = truncated.replaceFirst(_trailingDotsAndSpaces, '').trim();
    if (stripped.isEmpty) return '';
    return _reservedDeviceName.hasMatch(stripped) ? '_$stripped' : stripped;
  }

  /// 按字素截断，不拆开 emoji 或组合字符；任一上限为 null 时不限制该单位。
  static String truncate(
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
      final runes = grapheme.runes;
      codePoints += runes.length;
      utf8Bytes += runes.fold(0, (sum, rune) => sum + _utf8Length(rune));
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
    final fitted = truncate(
      base,
      maxUtf16Units: budget,
    ).replaceFirst(_trailingDotsAndSpaces, '').trim();
    return fitted.isEmpty ? stem : '$fitted$suffix';
  }

  static int utf8Length(String text) =>
      text.runes.fold(0, (sum, rune) => sum + _utf8Length(rune));

  static int _utf8Length(int rune) {
    if (rune < 0x80) return 1;
    if (rune < 0x800) return 2;
    if (rune < 0x10000) return 3;
    return 4;
  }
}
