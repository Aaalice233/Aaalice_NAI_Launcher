/// DText 格式解析器
///
/// Danbooru wiki 使用 DText 标记语言
/// 参考: https://danbooru.donmai.us/wiki_pages/help:dtext
///
/// 主要用于解析 tag_group wiki 页面内容，提取：
/// - 标签链接 [[tag_name]] 或 [[tag_name|display_text]]
/// - 子分组链接 [[tag_group:xxx]]
class DTextParser {
  /// 提取所有标签链接
  ///
  /// 支持格式:
  /// - [[tag_name]]
  /// - [[tag_name|display_text]]
  /// - [[tag_name|]]  (使用标签名作为显示文本)
  ///
  /// 返回去重后的标签名列表（下划线格式）
  static List<String> extractTagLinks(String dtext) {
    // 匹配 [[xxx]] 或 [[xxx|yyy]] 格式
    final regex = RegExp(r'\[\[([^\]|]+)(?:\|[^\]]*)?]]');
    final matches = regex.allMatches(dtext);

    final tags = <String>{};
    for (final match in matches) {
      final tag = match.group(1);
      if (tag == null) continue;

      // 标准化标签名
      final normalized = normalizeTagName(tag);

      // 排除非标签链接
      if (_shouldExcludeLink(normalized)) continue;

      tags.add(normalized);
    }

    return tags.toList();
  }

  /// 提取所有 tag_group 子分组链接
  ///
  /// 返回 tag_group 标题列表（如 "tag_group:hair_color"）
  static List<String> extractChildGroupLinks(String dtext) {
    // 匹配 [[tag_group:xxx]] 格式
    final regex = RegExp(r'\[\[(tag_group:[^\]|]+)(?:\|[^\]]*)?]]');
    final matches = regex.allMatches(dtext);

    final groups = <String>{};
    for (final match in matches) {
      final group = match.group(1);
      if (group != null) {
        groups.add(group.toLowerCase().replaceAll(' ', '_'));
      }
    }

    return groups.toList();
  }

  /// 提取 wiki 页面中的标题层级
  ///
  /// DText 使用 h1. h2. h3. 等表示标题
  /// 返回 Map<标题文本, 层级(1-6)>
  static Map<String, int> extractHeadings(String dtext) {
    final headings = <String, int>{};

    // 匹配 h1. 到 h6. 格式的标题
    final regex = RegExp(r'^h([1-6])\.\s*(.+)$', multiLine: true);
    final matches = regex.allMatches(dtext);

    for (final match in matches) {
      final level = int.parse(match.group(1)!);
      final text = match.group(2)!.trim();
      headings[text] = level;
    }

    return headings;
  }

  /// 提取列表项
  ///
  /// DText 使用 * 表示无序列表项
  /// 返回列表项文本列表
  static List<String> extractListItems(String dtext) {
    final items = <String>[];

    // 匹配 * 开头的行
    final regex = RegExp(r'^\*+\s*(.+)$', multiLine: true);
    final matches = regex.allMatches(dtext);

    for (final match in matches) {
      final item = match.group(1)!.trim();
      items.add(item);
    }

    return items;
  }

  /// 标准化标签名
  ///
  /// - 转换为小写
  /// - 将空格替换为下划线
  /// - 移除多余的空白字符
  static String normalizeTagName(String tag) {
    return tag
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// 从标签名生成显示名称
  ///
  /// - 将下划线替换为空格
  /// - 保持原有大小写（如果有）
  static String tagToDisplayName(String tag) {
    return tag.replaceAll('_', ' ');
  }

  /// 判断链接是否应该被排除
  ///
  /// 排除以下类型的链接：
  /// - tag_group: 子分组链接
  /// - help: 帮助页面
  /// - howto: 教程页面
  /// - about: 关于页面
  /// - forum_topic: 论坛主题
  /// - user: 用户页面
  static bool _shouldExcludeLink(String normalized) {
    const excludePrefixes = [
      'tag_group:', // tag_group 子分组链接（带冒号）
      'tag_groups', // tag_groups 主页面链接（不带冒号）
      'help:',
      'howto:',
      'about:',
      'forum_topic:',
      'user:',
      'pool:',
      'post:',
      'comment:',
      'note:',
      'wiki:',
      'artist:',
      'http://',
      'https://',
    ];

    for (final prefix in excludePrefixes) {
      if (normalized.startsWith(prefix)) {
        return true;
      }
    }

    // 排除包含特殊字符的链接（可能是 URL 或其他非标签内容）
    if (normalized.contains('/') || normalized.contains('#')) {
      return true;
    }

    return false;
  }

  /// 解析 wiki 页面的完整结构
  ///
  /// 返回一个结构化的解析结果
  static DTextParseResult parse(String dtext) {
    return DTextParseResult(
      tags: extractTagLinks(dtext),
      childGroups: extractChildGroupLinks(dtext),
      headings: extractHeadings(dtext),
      listItems: extractListItems(dtext),
    );
  }

  /// 清理 DText 中的标记，返回纯文本
  static String stripMarkup(String dtext) {
    var text = dtext;

    // 移除链接标记，保留显示文本或链接目标
    text = text.replaceAllMapped(
      RegExp(r'\[\[([^\]|]+)(?:\|([^\]]*))?\]\]'),
      (match) => match.group(2)?.isNotEmpty == true
          ? match.group(2)!
          : match.group(1)!,
    );

    // 移除加粗标记 [b]...[/b]
    text = text.replaceAll(RegExp(r'\[b\](.*?)\[/b\]'), r'$1');

    // 移除斜体标记 [i]...[/i]
    text = text.replaceAll(RegExp(r'\[i\](.*?)\[/i\]'), r'$1');

    // 移除标题标记
    text = text.replaceAll(RegExp(r'^h[1-6]\.\s*', multiLine: true), '');

    // 移除列表标记
    text = text.replaceAll(RegExp(r'^\*+\s*', multiLine: true), '');

    return text.trim();
  }
}

/// DText 解析结果
class DTextParseResult {
  /// 提取的标签列表
  final List<String> tags;

  /// 提取的子分组列表
  final List<String> childGroups;

  /// 提取的标题及其层级
  final Map<String, int> headings;

  /// 提取的列表项
  final List<String> listItems;

  const DTextParseResult({
    this.tags = const [],
    this.childGroups = const [],
    this.headings = const {},
    this.listItems = const [],
  });

  /// 是否有标签
  bool get hasTags => tags.isNotEmpty;

  /// 是否有子分组
  bool get hasChildGroups => childGroups.isNotEmpty;

  /// 标签数量
  int get tagCount => tags.length;

  /// 子分组数量
  int get childGroupCount => childGroups.length;
}
