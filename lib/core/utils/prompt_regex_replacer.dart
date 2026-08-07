import '../../data/models/prompt/prompt_regex_rule.dart';
import 'app_logger.dart';

/// 正则替换执行结果
class PromptRegexResult {
  const PromptRegexResult({
    required this.text,
    this.appliedRules = const [],
    this.invalidRules = const [],
    this.aborted = false,
  });

  /// 替换后的文本；未发生任何有效替换时与输入相同
  final String text;

  /// 实际改变了文本的规则
  final List<PromptRegexRule> appliedRules;

  /// 正则语法非法、被跳过的规则
  final List<PromptRegexRule> invalidRules;

  /// 是否因长度保护中止（中止时 [text] 为原始输入）
  final bool aborted;

  /// 文本是否被改写
  bool get changed => appliedRules.isNotEmpty;
}

/// 提示词正则替换引擎
///
/// 按 [PromptRegexRule.sortOrder] 顺序依次把启用的规则作用于整段文本，
/// 前一条规则的输出是后一条规则的输入。
///
/// 与 [String.replaceAll] 不同，本引擎支持在替换目标中引用捕获组
/// （Dart 的 `replaceAll` 会把 `$1` 当作字面量）：
/// - `$1` / `$12`：按序号引用捕获组
/// - `${name}`：引用命名捕获组
/// - `$$`：字面量 `$`
class PromptRegexReplacer {
  PromptRegexReplacer._();

  /// 超过此长度的文本不做正则替换
  ///
  /// 用户可以写出会灾难性回溯的正则（如 `(a+)+b`），而 Dart 的 [RegExp]
  /// 是同步回溯实现、无法中途取消。限制输入长度是这里唯一可行的兜底。
  static const int maxInputLength = 20000;

  /// 中间结果超过此长度即判定规则失控，放弃全部替换
  static const int maxOutputLength = 60000;

  /// 对 [text] 依次应用 [rules]
  static PromptRegexResult apply(String text, List<PromptRegexRule> rules) {
    if (text.isEmpty || rules.isEmpty) {
      return PromptRegexResult(text: text);
    }
    if (text.length > maxInputLength) {
      AppLogger.w(
        'Prompt too long for regex replacement: ${text.length} chars',
        'PromptRegexReplacer',
      );
      return PromptRegexResult(text: text, aborted: true);
    }

    final applied = <PromptRegexRule>[];
    final invalid = <PromptRegexRule>[];
    var current = text;

    for (final rule in rules.sortedByOrder()) {
      if (!rule.enabled) continue;

      final regExp = rule.tryCompile();
      if (regExp == null) {
        invalid.add(rule);
        continue;
      }

      final next = current.replaceAllMapped(
        regExp,
        (match) => expandReplacement(rule.replacement, match),
      );

      if (next.length > maxOutputLength) {
        AppLogger.w(
          'Regex rule "${rule.displayLabel}" produced ${next.length} chars, '
              'aborting replacement',
          'PromptRegexReplacer',
        );
        return PromptRegexResult(
          text: text,
          invalidRules: invalid,
          aborted: true,
        );
      }

      if (next != current) {
        current = next;
        applied.add(rule);
      }
    }

    return PromptRegexResult(
      text: current,
      appliedRules: applied,
      invalidRules: invalid,
    );
  }

  /// 把替换模板中的捕获组引用展开为 [match] 中的实际内容
  ///
  /// 无法解析的引用（序号越界、命名组不存在）原样保留，
  /// 这样用户写错时看到的是自己的输入而不是被静默吞掉的空串。
  static String expandReplacement(String template, Match match) {
    if (!template.contains(r'$')) return template;

    final buffer = StringBuffer();
    var i = 0;

    while (i < template.length) {
      final char = template[i];
      if (char != r'$' || i + 1 >= template.length) {
        buffer.write(char);
        i++;
        continue;
      }

      final next = template[i + 1];

      // $$ -> 字面量 $
      if (next == r'$') {
        buffer.write(r'$');
        i += 2;
        continue;
      }

      // ${name} -> 命名捕获组
      if (next == '{') {
        final closeIndex = template.indexOf('}', i + 2);
        if (closeIndex > i + 2) {
          final name = template.substring(i + 2, closeIndex);
          final value = _namedGroup(match, name);
          if (value != null) {
            buffer.write(value);
            i = closeIndex + 1;
            continue;
          }
        }
        buffer.write(char);
        i++;
        continue;
      }

      // $1 / $12 -> 序号捕获组，优先按两位数解析
      final groupIndex = _readGroupIndex(template, i + 1, match.groupCount);
      if (groupIndex != null) {
        buffer.write(match.group(groupIndex.value) ?? '');
        i = groupIndex.endIndex;
        continue;
      }

      buffer.write(char);
      i++;
    }

    return buffer.toString();
  }

  /// 读取 `$` 之后的组序号，越界或非数字返回 null
  static _GroupRef? _readGroupIndex(
    String template,
    int start,
    int groupCount,
  ) {
    var end = start;
    while (end < template.length &&
        end - start < 2 &&
        _isDigit(template[end])) {
      end++;
    }
    if (end == start) return null;

    // 先按最长数字串解析，越界再退回一位（与 JS 替换模板的行为一致）
    for (var candidateEnd = end; candidateEnd > start; candidateEnd--) {
      final value = int.parse(template.substring(start, candidateEnd));
      if (value <= groupCount) {
        return _GroupRef(value: value, endIndex: candidateEnd);
      }
    }
    return null;
  }

  static String? _namedGroup(Match match, String name) {
    if (match is! RegExpMatch) return null;
    try {
      return match.namedGroup(name) ?? '';
    } on ArgumentError {
      return null;
    }
  }

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}

/// 解析出的捕获组引用
class _GroupRef {
  const _GroupRef({required this.value, required this.endIndex});

  final int value;
  final int endIndex;
}
