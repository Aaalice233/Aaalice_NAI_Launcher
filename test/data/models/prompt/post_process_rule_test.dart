import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';

void main() {
  test('移除类别时保留触发规则的标签', () {
    final rule = PostProcessRule.sleepingRule(targetCategoryIds: ['eyes']);
    const context = {
      'eyes': ['blue eyes', 'closed eyes'],
    };

    expect(rule.apply(['closed eyes', 'blue eyes', 'smile'], context), [
      'closed eyes',
      'smile',
    ]);
  });

  test('预设规则的目标由调用方按当前预设给出', () {
    expect(PostProcessRule.sleepingRule().targetCategoryIds, isEmpty);
    expect(
      PostProcessRule.mermaidRule(
        targetCategoryIds: ['legs'],
      ).targetCategoryIds,
      ['legs'],
    );
    expect(PostProcessRule.sleepingTargetCategoryKeys, ['eyeColor']);
    expect(PostProcessRule.mermaidTargetCategoryKeys, isEmpty);
  });

  test('同优先级的规则按列表顺序依次改写标签', () {
    // List.sort 超过 32 条后不保证稳定，用链式替换检验执行顺序
    final rules = [
      for (var i = 0; i < 40; i++)
        PostProcessRule(
          id: 'step$i',
          name: 'step$i',
          triggerTags: ['t$i'],
          action: PostProcessAction.replace,
          targetTags: ['t$i'],
          replacementTag: 't${i + 1}',
        ),
    ];

    expect(PostProcessRuleSet(rules: rules).applyAll(['t0'], const {}), [
      't40',
    ]);
  });

  test('高优先级规则先执行', () {
    const rules = [
      PostProcessRule(
        id: 'remove',
        name: 'remove',
        triggerTags: ['b'],
        targetTags: ['b'],
      ),
      PostProcessRule(
        id: 'replace',
        name: 'replace',
        triggerTags: ['a'],
        action: PostProcessAction.replace,
        targetTags: ['a'],
        replacementTag: 'b',
        priority: 1,
      ),
    ];

    expect(
      const PostProcessRuleSet(rules: rules).applyAll(['a'], const {}),
      isEmpty,
    );
  });
}
