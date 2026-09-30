import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';

VisibilityRule _rule(
  String id,
  String conditionValue, {
  bool visibleWhenMatched = true,
  int priority = 0,
  bool enabled = true,
  String target = 'shoes',
}) => VisibilityRule(
  id: id,
  name: id,
  sourceCategoryId: 'pose',
  targetCategoryId: target,
  conditionValue: conditionValue,
  visibleWhenMatched: visibleWhenMatched,
  priority: priority,
  enabled: enabled,
);

bool _visible(List<VisibilityRule> rules, List<String> poseTags) =>
    VisibilityRuleSet(
      rules: rules,
    ).isCategoryVisible('shoes', {'pose': poseTags});

void main() {
  group('VisibilityRuleSet.isCategoryVisible', () {
    test('只有隐藏规则时，命中才隐藏', () {
      final rules = [_rule('hide', 'portrait', visibleWhenMatched: false)];

      expect(_visible(rules, ['portrait']), isFalse);
      expect(_visible(rules, ['full body']), isTrue);
    });

    test('条件匹配时可见的规则在条件不成立时隐藏目标', () {
      final rules = [_rule('show', 'full body')];

      expect(_visible(rules, ['full body']), isTrue);
      expect(_visible(rules, ['portrait']), isFalse);
    });

    test('多条可见规则任一成立即可见', () {
      final rules = [
        _rule('full', 'full body'),
        _rule('cowboy', 'cowboy shot'),
      ];

      expect(_visible(rules, ['cowboy shot']), isTrue);
      expect(_visible(rules, ['portrait']), isFalse);
    });

    test('同一优先级同时命中可见与隐藏规则时隐藏，与规则顺序无关', () {
      final show = _rule('show', 'full body');
      final hide = _rule('hide', 'sitting', visibleWhenMatched: false);

      expect(_visible([show, hide], ['full body', 'sitting']), isFalse);
      expect(_visible([hide, show], ['full body', 'sitting']), isFalse);
    });

    test('更高优先级的命中规则覆盖低优先级规则', () {
      final hide = _rule('hide', 'sitting', visibleWhenMatched: false);
      final show = _rule('show', 'kneeling', priority: 10);

      expect(_visible([hide, show], ['sitting', 'kneeling']), isTrue);
      expect(_visible([hide, show], ['sitting']), isFalse);
    });

    test('停用或指向其他目标的规则不参与判断', () {
      final rules = [
        _rule('disabled', 'full body', enabled: false),
        _rule('other', 'full body', target: 'hat'),
      ];

      expect(_visible(rules, ['portrait']), isTrue);
    });
  });
}
