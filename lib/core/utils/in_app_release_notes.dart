/// 提取适合在应用内展示的更新日志正文。
///
/// Release 页面还包含平台下载和文件校验等发布信息。应用已经提供当前平台的
/// 更新入口，因此当 Release body 包含“更新内容”章节时，只展示该章节正文。
/// 不符合发布模板的历史 Release 保持原样，避免误删自定义更新日志。
String extractInAppReleaseNotes(String releaseBody) {
  final normalizedBody = releaseBody.replaceAll('\r\n', '\n').trim();
  if (normalizedBody.isEmpty) return normalizedBody;

  final lines = normalizedBody.split('\n');
  final headingPattern = RegExp(r'^\s{0,3}(#{1,6})[ \t]+(.+?)[ \t]*#*[ \t]*$');

  for (var index = 0; index < lines.length; index++) {
    final heading = headingPattern.firstMatch(lines[index]);
    if (heading == null || !heading.group(2)!.contains('更新内容')) continue;

    final headingLevel = heading.group(1)!.length;
    var end = lines.length;
    for (var next = index + 1; next < lines.length; next++) {
      final nextHeading = headingPattern.firstMatch(lines[next]);
      if (nextHeading != null && nextHeading.group(1)!.length <= headingLevel) {
        end = next;
        break;
      }
    }

    final content = lines.sublist(index + 1, end).join('\n').trim();
    if (content.isNotEmpty) return _normalizeGitHubAlerts(content);
  }

  return _normalizeGitHubAlerts(normalizedBody);
}

/// flutter_markdown_plus 目前会把 GitHub Alert 标记解析成多个匿名 inline，
/// 随后在构建 blockquote 时因假定只有一个 inline 而抛出 StateError。
/// 转成语义等价的普通粗体引用，既保留强调效果，也避免整个更新弹窗崩溃。
String _normalizeGitHubAlerts(String markdown) {
  final alertPattern = RegExp(
    r'^(\s{0,3}>\s*)\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\]\s*$',
    multiLine: true,
    caseSensitive: false,
  );
  return markdown.replaceAllMapped(
    alertPattern,
    (match) => '${match.group(1)}**${match.group(2)!.toUpperCase()}**',
  );
}
