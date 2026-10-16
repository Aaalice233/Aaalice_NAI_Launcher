import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/rule_tag_match.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';

void main() {
  test('比较键忽略权重写法、大小写，下划线与空格等价', () {
    for (final tag in [
      'full body',
      'Full_Body',
      '{{full body}}',
      '[full_body]',
      '1.2::full body::',
      '-0.5::Full Body::',
      '(full body:1.3)',
      '  FULL BODY  ',
    ]) {
      expect(ruleTagMatchKey(tag), 'full body', reason: tag);
    }
    expect(ruleTagMatchKeysOfList('{a, b}, c_d, [E]'), {'a b', 'c d', 'e'});
  });

  test('可见性条件按比较键匹配带权重的生成结果', () {
    VisibilityRule rule(VisibilityConditionType type, String value) =>
        VisibilityRule(
          id: 'rule',
          name: 'rule',
          conditionType: type,
          sourceCategoryId: 'pose',
          targetCategoryId: 'lower',
          conditionValue: value,
        );
    const context = {
      'pose': ['{{Full Body}}', '[sitting]'],
    };

    expect(
      rule(
        VisibilityConditionType.tagExists,
        'full_body',
      ).checkCondition(context),
      isTrue,
    );
    expect(
      rule(
        VisibilityConditionType.tagNotExists,
        'sitting',
      ).checkCondition(context),
      isFalse,
    );
    expect(
      rule(
        VisibilityConditionType.valueEquals,
        '1.1::full body::',
      ).checkCondition(context),
      isTrue,
    );
    expect(
      rule(
        VisibilityConditionType.valueInList,
        'portrait, (Sitting:1.2)',
      ).checkCondition(context),
      isTrue,
    );
    expect(
      rule(
        VisibilityConditionType.valueNotInList,
        'portrait, cowboy_shot',
      ).checkCondition(context),
      isTrue,
    );
  });

  test('后处理的触发与目标标签按比较键匹配，替换与移除作用在原始标签上', () {
    const tags = ['{{Sleeping}}', '[blue eyes]', '1.1::smile::'];

    const remove = PostProcessRule(
      id: 'remove',
      name: 'remove',
      triggerTags: ['sleeping'],
      targetTags: ['Blue_Eyes'],
    );
    expect(remove.isTriggered(selectedTags: tags, context: const {}), isTrue);
    expect(remove.apply(tags, const {}), ['{{Sleeping}}', '1.1::smile::']);

    const replace = PostProcessRule(
      id: 'replace',
      name: 'replace',
      triggerTags: ['SLEEPING'],
      action: PostProcessAction.replace,
      targetTags: ['smile'],
      replacementTag: 'closed mouth',
    );
    expect(replace.apply(tags, const {}), [
      '{{Sleeping}}',
      '[blue eyes]',
      'closed mouth',
    ]);
  });

  test('值依赖的映射键与带权重的已选值按比较键匹配', () {
    const config = DependencyConfig(
      type: DependencyType.value,
      sourceCategoryId: 'pose',
      mappingRules: {'Full_Body': '2'},
    );

    expect(
      config.getResultForSource(
        sourceCount: 1,
        sourceValues: ['(full body:1.2)'],
      ),
      '2',
    );
  });
}
