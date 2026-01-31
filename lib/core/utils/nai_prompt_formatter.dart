/// NAI 提示词格式化工具
/// 简化版：只做中文逗号转英文和空格转下划线
class NaiPromptFormatter {
  /// 格式化单个标签为 NAI 格式
  /// 将空格转换为下划线
  static String formatTag(String tag) {
    return _normalizeWhitespace(tag).trim().replaceAll(' ', '_');
  }

  /// 格式化整个提示词
  /// - 将中文逗号转换为英文逗号
  /// - 将标签中的空格转换为下划线（保留逗号后的空格）
  static String format(String prompt) {
    if (prompt.isEmpty) return prompt;

    var result = prompt;

    // 1. 统一空白字符：全角空格、连续空格 → 单个半角空格
    result = _normalizeWhitespace(result);

    // 2. 将中文逗号转换为英文逗号
    result = result.replaceAll('，', ',');

    // 3. 按逗号分割，对每个标签内部的空格转下划线，然后用 ", " 重新连接
    final tags = result.split(',');
    final formattedTags = tags.map((tag) {
      // 去掉标签前后的空格，然后将内部空格转下划线
      final trimmed = tag.trim();
      if (trimmed.isEmpty) return '';
      return trimmed.replaceAll(' ', '_');
    }).where((tag) => tag.isNotEmpty);

    return formattedTags.join(', ');
  }

  /// 统一空白字符
  /// - 全角空格 → 半角空格
  /// - 连续空白 → 单个空格
  static String _normalizeWhitespace(String text) {
    // 全角空格转半角
    var result = text.replaceAll('　', ' ');
    // 连续空白压缩为单个空格
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    return result;
  }
}
