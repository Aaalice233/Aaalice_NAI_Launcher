import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/prompt_regex_replacer.dart';
import 'package:nai_launcher/data/models/prompt/prompt_regex_rule.dart';

PromptRegexRule rule({
  String id = 'r1',
  String pattern = '',
  String replacement = '',
  bool enabled = true,
  bool caseSensitive = false,
  int sortOrder = 0,
}) {
  return PromptRegexRule(
    id: id,
    pattern: pattern,
    replacement: replacement,
    enabled: enabled,
    caseSensitive: caseSensitive,
    sortOrder: sortOrder,
  );
}

void main() {
  group('PromptRegexReplacer.apply', () {
    test('替换所有匹配并记录生效规则', () {
      final result = PromptRegexReplacer.apply(
        '1girl, blue_hair, blue_hair, smile',
        [rule(pattern: 'blue_hair', replacement: 'aqua hair')],
      );

      expect(result.text, '1girl, aqua hair, aqua hair, smile');
      expect(result.changed, isTrue);
      expect(result.appliedRules, hasLength(1));
      expect(result.invalidRules, isEmpty);
    });

    test('未匹配时文本不变且不计入生效规则', () {
      final result = PromptRegexReplacer.apply('1girl, smile', [
        rule(pattern: 'blue_hair', replacement: 'aqua hair'),
      ]);

      expect(result.text, '1girl, smile');
      expect(result.changed, isFalse);
      expect(result.appliedRules, isEmpty);
    });

    test('按 sortOrder 顺序链式应用，前一条的输出是后一条的输入', () {
      final result = PromptRegexReplacer.apply('a', [
        rule(id: 'second', pattern: 'b', replacement: 'c', sortOrder: 1),
        rule(id: 'first', pattern: 'a', replacement: 'b', sortOrder: 0),
      ]);

      expect(result.text, 'c');
      expect(result.appliedRules.map((r) => r.id), ['first', 'second']);
    });

    test('禁用的规则被跳过', () {
      final result = PromptRegexReplacer.apply('blue_hair', [
        rule(pattern: 'blue_hair', replacement: 'aqua hair', enabled: false),
      ]);

      expect(result.text, 'blue_hair');
      expect(result.changed, isFalse);
    });

    test('默认忽略大小写，开启后区分', () {
      const source = 'Blue_Hair';
      final insensitive = PromptRegexReplacer.apply(source, [
        rule(pattern: 'blue_hair', replacement: 'aqua hair'),
      ]);
      final sensitive = PromptRegexReplacer.apply(source, [
        rule(
          pattern: 'blue_hair',
          replacement: 'aqua hair',
          caseSensitive: true,
        ),
      ]);

      expect(insensitive.text, 'aqua hair');
      expect(sensitive.text, 'Blue_Hair');
    });

    test('非法正则被跳过并单独报告，不影响其它规则', () {
      final result = PromptRegexReplacer.apply('1girl, smile', [
        rule(id: 'broken', pattern: '(unclosed', sortOrder: 0),
        rule(id: 'ok', pattern: 'smile', replacement: 'grin', sortOrder: 1),
      ]);

      expect(result.text, '1girl, grin');
      expect(result.invalidRules.map((r) => r.id), ['broken']);
      expect(result.appliedRules.map((r) => r.id), ['ok']);
    });

    test('空匹配式视为非法规则', () {
      final result = PromptRegexReplacer.apply('1girl', [
        rule(pattern: '', replacement: 'x'),
      ]);

      expect(result.text, '1girl');
      expect(result.invalidRules, hasLength(1));
    });

    test('超长文本跳过替换并标记中止', () {
      final longText = 'a' * (PromptRegexReplacer.maxInputLength + 1);
      final result = PromptRegexReplacer.apply(longText, [
        rule(pattern: 'a', replacement: 'b'),
      ]);

      expect(result.text, longText);
      expect(result.aborted, isTrue);
      expect(result.changed, isFalse);
    });

    test('结果膨胀超限时放弃全部替换', () {
      final source = 'a' * 1000;
      final result = PromptRegexReplacer.apply(source, [
        rule(pattern: 'a', replacement: 'b' * 100),
      ]);

      expect(result.text, source);
      expect(result.aborted, isTrue);
    });

    test('空输入或空规则集原样返回', () {
      expect(
        PromptRegexReplacer.apply('', [
          rule(pattern: 'a', replacement: 'b'),
        ]).text,
        '',
      );
      expect(PromptRegexReplacer.apply('1girl', const []).text, '1girl');
    });
  });

  group('PromptRegexReplacer 捕获组展开', () {
    test(r'$1 引用序号捕获组', () {
      final result = PromptRegexReplacer.apply('blue_hair, red_eyes', [
        rule(pattern: r'(\w+)_hair', replacement: r'$1 hair'),
      ]);

      expect(result.text, 'blue hair, red_eyes');
    });

    test('多个捕获组按序展开', () {
      final result = PromptRegexReplacer.apply('blue_hair', [
        rule(pattern: r'(\w+)_(\w+)', replacement: r'$2 of $1'),
      ]);

      expect(result.text, 'hair of blue');
    });

    test('命名捕获组通过 name 引用', () {
      final result = PromptRegexReplacer.apply('blue_hair', [
        rule(pattern: r'(?<color>\w+)_hair', replacement: r'${color} hair'),
      ]);

      expect(result.text, 'blue hair');
    });

    test(r'$$ 转义为字面量 $', () {
      final result = PromptRegexReplacer.apply('cost', [
        rule(pattern: 'cost', replacement: r'$$5'),
      ]);

      expect(result.text, r'$5');
    });

    test('序号越界时保留字面量而不是吞掉', () {
      final result = PromptRegexReplacer.apply('blue_hair', [
        rule(pattern: r'(\w+)_hair', replacement: r'$1$9'),
      ]);

      expect(result.text, r'blue$9');
    });

    test('不存在的命名组保留字面量', () {
      final result = PromptRegexReplacer.apply('blue_hair', [
        rule(pattern: r'(?<color>\w+)_hair', replacement: r'${missing}'),
      ]);

      expect(result.text, r'${missing}');
    });

    test('两位数组号优先按两位解析', () {
      // 12 个捕获组，$12 应命中第 12 组而不是「第 1 组 + 字面量 2」
      final result = PromptRegexReplacer.apply('abcdefghijkl', [
        rule(
          pattern: r'(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)(k)(l)',
          replacement: r'$12',
        ),
      ]);

      expect(result.text, 'l');
    });

    test('未参与匹配的可选组展开为空串', () {
      final result = PromptRegexReplacer.apply('hair', [
        rule(pattern: r'(blue)?hair', replacement: r'[$1]'),
      ]);

      expect(result.text, '[]');
    });
  });
}
