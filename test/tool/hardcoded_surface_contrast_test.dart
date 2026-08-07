import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 静态检查：写死背景色的容器，其内部前景色也必须写死。
///
/// 背景与前景取色来源不一致时必然在某个亮度下撞色：
/// - 底写死深色、图标/文字跟随主题 → 浅色主题下变成深底深字；
/// - 底写死浅色、图标/文字跟随主题 → 深色主题下变成浅底浅字。
///
/// 两种方向都出现过真实缺陷（反推面板缩略图的删除按钮、取色面板的交换
/// 按钮），且 widget test 很难覆盖——它们依赖具体主题下的继承结果。这里
/// 直接扫源码：找出写死背景色的容器子树里未显式指定颜色的 Icon / Text。
void main() {
  test('写死背景色的容器内不得有跟随主题的 Icon/Text', () {
    final offenders = <String>[];

    for (final file in _dartSources()) {
      final source = file.readAsStringSync();
      offenders.addAll(_scanFile(_relativePath(file), source));
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '以下位置的背景色写死、前景却跟随主题，会在某个主题亮度下撞色。\n'
          '请给 Icon/Text 显式指定与该背景匹配的颜色，或让背景改用主题槽位：\n'
          '${offenders.join('\n')}',
    );
  });
}

/// 能承载背景色的容器。
const _holders = <String>[
  'Container(',
  'Material(',
  'DecoratedBox(',
  'AnimatedContainer(',
  'ColoredBox(',
];

/// 这些容器自带主题化表面，其内部前景跟随主题是正确的，扫描到即截断。
const _themedContainers = <String>[
  'Card(',
  'Dialog(',
  'AlertDialog(',
  'ListTile(',
  'Scaffold(',
];

/// 写死深色背景：`Colors.blackNN` 或 `Colors.black.withValues(alpha: x)`。
final _darkBackground = RegExp(
  r'color:\s*Colors\.black(?:(\d+)|\.withValues\(\s*alpha:\s*([\d.]+))',
);

/// 写死浅色背景。
final _lightBackground = RegExp(r'color:\s*Colors\.(white|grey\.shade[12]00),');

/// 低于此不透明度的黑色压不暗前景，通常只是轻微阴影或分隔，忽略。
const double _minOpaqueAlpha = 0.25;

final _foreground = RegExp(r'\b(Icon|Text)\s*\(');
final _shadowContext = RegExp(r'(BoxShadow|Shadow)\s*\([^()]*$');

List<File> _dartSources() {
  final libDir = Directory('lib');
  expect(libDir.existsSync(), isTrue, reason: '未找到 lib 目录，请在项目根运行测试');
  return libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

String _relativePath(File file) => file.path.replaceAll(r'\', '/');

List<String> _scanFile(String path, String source) {
  final found = <String>[];
  final seen = <int>{};

  final backgrounds = <RegExpMatch>[
    // 深色底：需要够不透明才会压暗前景。
    ..._darkBackground.allMatches(source).where((m) {
      final shade = m.group(1);
      final alphaText = m.group(2);
      final alpha = alphaText != null
          ? double.parse(alphaText)
          : (shade != null ? int.parse(shade) / 100 : 1.0);
      return alpha >= _minOpaqueAlpha;
    }),
    // 浅色底：不透明度恒为 1，无需过滤。
    ..._lightBackground.allMatches(source),
  ];

  for (final match in backgrounds) {
    // 阴影不是背景，不影响前景可读性。
    final lookBehind = source.substring(
      match.start - 250 < 0 ? 0 : match.start - 250,
      match.start,
    );
    if (_shadowContext.hasMatch(lookBehind)) continue;

    final holder = _enclosingHolder(source, match.start);
    if (holder == null) continue;

    var subtree = source.substring(
      holder.start,
      _matchClose(source, holder.open),
    );
    // 子树里若又嵌了主题化容器，从那里起前景跟随主题是对的。
    var cut = subtree.length;
    for (final themed in _themedContainers) {
      final at = subtree.indexOf(themed);
      if (at != -1 && at < cut) cut = at;
    }
    subtree = subtree.substring(0, cut);

    for (final fg in _foreground.allMatches(subtree)) {
      final open = subtree.indexOf('(', fg.start);
      final body = subtree.substring(open, _matchClose(subtree, open));
      if (body.contains('color:') || body.contains('style:')) continue;

      final line =
          '\n'.allMatches(source.substring(0, holder.start)).length +
          '\n'.allMatches(subtree.substring(0, fg.start)).length +
          1;
      if (!seen.add(line)) continue;

      final snippet = body.replaceAll(RegExp(r'\s+'), ' ');
      found.add(
        '  $path:$line  [${fg.group(1)}] '
        '${snippet.length > 60 ? '${snippet.substring(0, 60)}…' : snippet}',
      );
    }
  }

  return found;
}

/// 从 [openParen] 处做括号配对，返回匹配的右括号下标。
int _matchClose(String text, int openParen) {
  var depth = 0;
  for (var i = openParen; i < text.length; i++) {
    if (text[i] == '(') {
      depth++;
    } else if (text[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return text.length;
}

/// 找到包住 [pos] 的最近容器。
({int start, int open})? _enclosingHolder(String text, int pos) {
  ({int start, int open})? best;
  for (final holder in _holders) {
    var idx = text.lastIndexOf(holder, pos);
    while (idx != -1) {
      final open = idx + holder.length - 1;
      if (_matchClose(text, open) > pos) {
        final current = best;
        if (current == null || idx > current.start) {
          best = (start: idx, open: open);
        }
        break;
      }
      idx = text.lastIndexOf(holder, idx - 1);
    }
  }
  return best;
}
