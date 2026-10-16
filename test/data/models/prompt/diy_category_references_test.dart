import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/diy_category_references.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';

const _hair = RandomCategory(id: 'cat-hair', name: '发色', key: 'hairColor');
const _outfit = RandomCategory(id: 'cat-outfit', name: '服装', key: 'clothing');

RandomTagGroup _branchGroup(
  String id,
  String name, {
  Map<String, String> conditions = const {},
  List<RandomTagGroup> children = const [],
}) {
  return RandomTagGroup(
    id: id,
    name: name,
    children: children,
    conditionalBranchConfig: ConditionalBranchConfig(
      id: '${id}_branches',
      name: name,
      branches: [ConditionalBranch(name: name, conditions: conditions)],
    ),
  );
}

// 分支词组名称与类别名称、类别键名、其他分支词组名称各有一处重名
final _conditionCategories = [
  _hair.copyWith(groups: [_branchGroup('g-hair', '发色')]),
  _outfit.copyWith(
    groups: [
      _branchGroup(
        'g-type',
        'type',
        children: [_branchGroup('g-dup-child', 'dup')],
      ),
      _branchGroup('g-dup', 'dup'),
      _branchGroup('g-clothing', 'clothing'),
      const RandomTagGroup(id: 'g-plain', name: 'plain'),
    ],
  ),
  const RandomCategory(id: 'cat-dup', name: 'dup', key: 'dupKey'),
];

void main() {
  group('DiyCategoryReferenceResolver', () {
    final resolver = DiyCategoryReferenceResolver(const [_hair, _outfit]);

    test('按 ID、键名、名称的顺序定位类别并统一返回 ID', () {
      expect(resolver.canonicalId('cat-hair'), 'cat-hair');
      expect(resolver.canonicalId('clothing'), 'cat-outfit');
      expect(resolver.canonicalId('发色'), 'cat-hair');
    });

    test('找不到或为空的引用原样保留', () {
      expect(resolver.canonicalId('gone'), 'gone');
      expect(resolver.canonicalId(''), '');
      expect(resolver.resolve(''), isNull);
    });

    test('重名的名称或键名无法确定指向时不解析', () {
      final ambiguous = DiyCategoryReferenceResolver(const [
        _hair,
        RandomCategory(id: 'cat-hair-2', name: '发色', key: 'hairColor'),
        RandomCategory(id: 'cat-hair-3', name: '发色', key: 'hairColor'),
      ]);

      expect(ambiguous.canonicalId('发色'), '发色');
      expect(ambiguous.canonicalId('hairColor'), 'hairColor');
      expect(ambiguous.canonicalId('cat-hair-2'), 'cat-hair-2');
    });
  });

  group('分支条件变量键', () {
    final resolver = DiyCategoryReferenceResolver(_conditionCategories);

    for (final (key, expected, scenario) in const [
      (characterGenderVariable, characterGenderVariable, '角色性别变量'),
      (characterCountReference, characterCountReference, '角色数量变量'),
      (
        characterCountCategoryVariable,
        characterCountCategoryVariable,
        '人数分类变量',
      ),
      ('cat-hair', 'cat-hair', '类别 ID'),
      ('hairColor', 'cat-hair', '类别键名'),
      ('clothing', 'cat-outfit', '类别键名先于同名的分支词组'),
      ('g-type', 'g-type', '词组 ID'),
      ('type', 'g-type', '分支词组名称'),
      ('发色', 'g-hair', '分支词组名称先于同名类别，生成器从不按类别名称写入变量'),
      ('服装', 'cat-outfit', '类别名称'),
      ('dup', 'dup', '分支词组重名时不解析，也不退回同名类别'),
      ('plain', 'plain', '未配置分支的词组不写入变量'),
      ('gone', 'gone', '找不到的引用'),
      ('', '', '空键'),
    ]) {
      test(scenario, () {
        expect(resolver.canonicalConditionKey(key), expected);
      });
    }
  });

  test('统一引用时规则按类别解析、分支条件按变量解析，子词组一并处理', () {
    final resolver = DiyCategoryReferenceResolver(_conditionCategories);
    final group =
        _branchGroup(
          'owner',
          'owner',
          conditions: {'hairColor': 'blonde', 'type': 'uniform'},
          children: [
            _branchGroup('child', 'child', conditions: {'发色': 'short'}),
          ],
        ).copyWith(
          dependencyConfig: const DependencyConfig(sourceCategoryId: '发色'),
        );

    final canonical = group.canonicalizeReferences(resolver);

    expect(canonical.dependencyConfig?.sourceCategoryId, 'cat-hair');
    expect(canonical.conditionalBranchConfig!.branches.single.conditions, {
      'cat-hair': 'blonde',
      'g-type': 'uniform',
    });
    expect(
      canonical
          .children
          .single
          .conditionalBranchConfig!
          .branches
          .single
          .conditions,
      {'g-hair': 'short'},
    );
  });

  test('两个条件改写后会合并成同一个键时保留原条件', () {
    final resolver = DiyCategoryReferenceResolver(_conditionCategories);
    const conditions = {'hairColor': 'blonde', 'cat-hair': 'long hair'};

    final canonical = _branchGroup(
      'owner',
      'owner',
      conditions: conditions,
    ).canonicalizeReferences(resolver);

    expect(
      canonical.conditionalBranchConfig!.branches.single.conditions,
      conditions,
    );
  });

  test('词组的依赖、可见性与后处理引用连同子词组一起映射，角色人数保持不变', () {
    const group = RandomTagGroup(
      id: 'group',
      name: 'group',
      dependencyConfig: DependencyConfig(sourceCategoryId: 'old-hair'),
      visibilityRules: [
        VisibilityRule(
          id: 'rule',
          name: 'rule',
          sourceCategoryId: 'old-hair',
          targetCategoryId: 'old-outfit',
          conditionValue: 'portrait',
        ),
      ],
      postProcessRules: [
        PostProcessRule(
          id: 'post',
          name: 'post',
          triggerCategoryIds: ['old-hair'],
          targetCategoryIds: ['old-outfit', 'kept'],
        ),
      ],
      children: [
        RandomTagGroup(
          id: 'child',
          name: 'child',
          dependencyConfig: DependencyConfig(
            sourceCategoryId: characterCountReference,
          ),
        ),
        RandomTagGroup(
          id: 'child-2',
          name: 'child-2',
          dependencyConfig: DependencyConfig(sourceCategoryId: 'old-outfit'),
        ),
      ],
    );
    const ids = {'old-hair': 'new-hair', 'old-outfit': 'new-outfit'};

    final mapped = group.mapCategoryReferences((ref) => ids[ref] ?? ref);

    expect(mapped.dependencyConfig?.sourceCategoryId, 'new-hair');
    expect(mapped.visibilityRules.single.sourceCategoryId, 'new-hair');
    expect(mapped.visibilityRules.single.targetCategoryId, 'new-outfit');
    expect(mapped.postProcessRules.single.triggerCategoryIds, ['new-hair']);
    expect(mapped.postProcessRules.single.targetCategoryIds, [
      'new-outfit',
      'kept',
    ]);
    expect(
      mapped.children.first.dependencyConfig?.sourceCategoryId,
      characterCountReference,
    );
    expect(
      mapped.children.last.dependencyConfig?.sourceCategoryId,
      'new-outfit',
    );
  });
}
