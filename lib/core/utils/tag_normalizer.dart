/// 标签标准化工具函数
///
/// 统一处理标签的存储格式和显示格式转换
/// 解决项目中 "显示格式"（空格）和 "存储格式"（下划线）的不一致问题
class TagNormalizer {
  TagNormalizer._();

  /// 统一标准化标签（用于存储和查询）
  ///
  /// 转换规则：
  /// 1. 转为小写
  /// 2. 去除首尾空格
  /// 3. 空格替换为下划线
  ///
  /// 示例：
  /// ```dart
  /// TagNormalizer.normalize('Simple Background') // 'simple_background'
  /// TagNormalizer.normalize('simple background')  // 'simple_background'
  /// TagNormalizer.normalize('  SOLO  ')           // 'solo'
  /// ```
  static String normalize(String tag) {
    return tag.toLowerCase().trim().replaceAll(' ', '_');
  }

  /// 批量标准化标签
  static List<String> normalizeList(List<String> tags) {
    return tags.map(normalize).toList();
  }

  /// 转换为显示格式（下划线转空格）
  ///
  /// 示例：
  /// ```dart
  /// TagNormalizer.toDisplay('simple_background') // 'simple background'
  /// TagNormalizer.toDisplay('solo')              // 'solo'
  /// ```
  static String toDisplay(String tag) {
    return tag.replaceAll('_', ' ');
  }

  /// 批量转换为显示格式
  static List<String> toDisplayList(List<String> tags) {
    return tags.map(toDisplay).toList();
  }

  /// 检查标签是否已标准化
  ///
  /// 已标准化：全小写、无首尾空格、无空格字符
  static bool isNormalized(String tag) {
    return tag == tag.toLowerCase().trim() && !tag.contains(' ');
  }

  /// 标准化并去重
  static Set<String> normalizeToSet(List<String> tags) {
    return tags.map(normalize).toSet();
  }
}
