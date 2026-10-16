import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/algorithm_config.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/diy_category_references.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';

// 分支条件的取值写成场景名，按取值找到条件在副本里的变量键
ConditionalBranchConfig _branch(
  String owner, {
  List<String> targets = const [],
  Map<String, String> conditions = const {},
}) {
  return ConditionalBranchConfig(
    id: '${owner}_branches',
    name: owner,
    branches: [
      ConditionalBranch(
        name: owner,
        tagGroupIds: targets,
        conditions: conditions,
      ),
    ],
  );
}

VisibilityRule _visibility(String id, String source, String target) {
  return VisibilityRule(
    id: id,
    name: id,
    sourceCategoryId: source,
    targetCategoryId: target,
    conditionValue: 'portrait',
  );
}

final _source = RandomPreset(
  id: 'source',
  name: 'source',
  algorithmConfig: AlgorithmConfig(
    globalVisibilityRules: VisibilityRuleSet(
      rules: [_visibility('global', 'cat-hair', 'clothing')],
    ),
    globalPostProcessRules: const PostProcessRuleSet(
      rules: [
        PostProcessRule(
          id: 'global-post',
          name: 'global-post',
          targetCategoryIds: ['cat-outfit'],
        ),
      ],
    ),
  ),
  categories: [
    RandomCategory(
      id: 'cat-hair',
      name: '发色',
      key: 'hairColor',
      groups: [
        RandomTagGroup(
          id: 'owner',
          name: 'owner',
          nodeType: TagGroupNodeType.config,
          dependencyConfig: const DependencyConfig(
            sourceCategoryId: 'cat-outfit',
          ),
          visibilityRules: [
            _visibility('to-self', 'cat-hair', 'owner'),
            _visibility('to-gone', 'cat-hair', 'gone'),
          ],
          postProcessRules: const [
            PostProcessRule(
              id: 'post',
              name: 'post',
              triggerCategoryIds: ['cat-hair'],
              targetCategoryIds: ['clothing'],
            ),
          ],
          conditionalBranchConfig: _branch(
            'owner',
            targets: ['child', 'sibling', 'gone'],
            conditions: {
              'cat-outfit': '类别 ID',
              'sibling': '同类别词组 ID',
              'outfit-owner': '跨类别词组 ID',
              characterGenderVariable: '角色性别',
              characterCountReference: '角色数量',
              'clothing': '类别键名',
              'outfit owner': '词组名称',
            },
          ),
          children: [
            RandomTagGroup(
              id: 'child',
              name: 'child',
              conditionalBranchConfig: _branch(
                'child',
                targets: ['sibling'],
                conditions: {'owner': '父词组 ID'},
              ),
            ),
          ],
        ),
        RandomTagGroup(
          id: 'sibling',
          name: 'sibling',
          conditionalBranchConfig: _branch('sibling'),
        ),
      ],
    ),
    RandomCategory(
      id: 'cat-outfit',
      name: '服装',
      key: 'clothing',
      groups: [
        RandomTagGroup(
          id: 'outfit-owner',
          name: 'outfit owner',
          conditionalBranchConfig: _branch(
            'outfit-owner',
            conditions: {'owner': '其他类别引用本类别词组'},
          ),
        ),
      ],
    ),
  ],
);

Iterable<RandomTagGroup> _withChildren(RandomTagGroup group) sync* {
  yield group;
  for (final child in group.children) {
    yield* _withChildren(child);
  }
}

Iterable<RandomTagGroup> _allGroups(RandomPreset preset) => preset.categories
    .expand((category) => category.groups)
    .expand(_withChildren);

RandomTagGroup _group(RandomPreset preset, String name) =>
    _allGroups(preset).singleWhere((group) => group.name == name);

/// 实体名称在复制前后不变，借它找到源 ID 在副本里对应的 ID
String? _copiedId(RandomPreset copy, String sourceId) {
  final names = {
    for (final category in _source.categories) category.id: category.name,
    for (final group in _allGroups(_source)) group.id: group.name,
  };
  final name = names[sourceId];
  if (name == null) return null;
  return copy.categories.where((c) => c.name == name).firstOrNull?.id ??
      _group(copy, name).id;
}

String _conditionKey(RandomPreset preset, String owner, String scenario) {
  return _group(preset, owner)
      .conditionalBranchConfig!
      .branches
      .single
      .conditions
      .entries
      .singleWhere((condition) => condition.value == scenario)
      .key;
}

typedef _Reference = ({String scenario, String Function(RandomPreset) read});

final _references = <_Reference>[
  (
    scenario: '依赖源类别 ID',
    read: (p) => _group(p, 'owner').dependencyConfig!.sourceCategoryId,
  ),
  (
    scenario: '可见性来源类别 ID',
    read: (p) => _group(p, 'owner').visibilityRules.first.sourceCategoryId,
  ),
  (
    scenario: '可见性目标为本词组',
    read: (p) => _group(p, 'owner').visibilityRules.first.targetCategoryId,
  ),
  (
    scenario: '可见性目标已失效',
    read: (p) => _group(p, 'owner').visibilityRules.last.targetCategoryId,
  ),
  (
    scenario: '后处理触发类别 ID',
    read: (p) =>
        _group(p, 'owner').postProcessRules.single.triggerCategoryIds.single,
  ),
  (
    scenario: '后处理目标为存量类别键名',
    read: (p) =>
        _group(p, 'owner').postProcessRules.single.targetCategoryIds.single,
  ),
  (
    scenario: '全局可见性来源类别 ID',
    read: (p) =>
        p.algorithmConfig.globalVisibilityRules!.rules.single.sourceCategoryId,
  ),
  (
    scenario: '全局可见性目标为存量类别键名',
    read: (p) =>
        p.algorithmConfig.globalVisibilityRules!.rules.single.targetCategoryId,
  ),
  (
    scenario: '全局后处理目标类别 ID',
    read: (p) => p
        .algorithmConfig
        .globalPostProcessRules!
        .rules
        .single
        .targetCategoryIds
        .single,
  ),
  for (final (index, scenario) in const [
    '分支输出子词组',
    '分支输出同类别词组',
    '分支输出已失效',
  ].indexed)
    (
      scenario: scenario,
      read: (p) => _group(
        p,
        'owner',
      ).conditionalBranchConfig!.branches.single.tagGroupIds[index],
    ),
  (
    scenario: '子词组的分支输出同类别词组',
    read: (p) => _group(
      p,
      'child',
    ).conditionalBranchConfig!.branches.single.tagGroupIds.single,
  ),
  for (final scenario in const [
    '类别 ID',
    '同类别词组 ID',
    '跨类别词组 ID',
    '角色性别',
    '角色数量',
    '类别键名',
    '词组名称',
  ])
    (
      scenario: '分支条件：$scenario',
      read: (p) => _conditionKey(p, 'owner', scenario),
    ),
  (scenario: '分支条件：父词组 ID', read: (p) => _conditionKey(p, 'child', '父词组 ID')),
  (
    scenario: '分支条件：其他类别引用本类别词组',
    read: (p) => _conditionKey(p, 'outfit owner', '其他类别引用本类别词组'),
  ),
];

void main() {
  final copy = RandomPreset.copyFrom(_source, name: 'copy');

  test('副本里的类别与各层词组都换了新 ID', () {
    final sourceIds = {
      for (final category in _source.categories) category.id,
      for (final group in _allGroups(_source)) group.id,
    };
    final copiedIds = {
      for (final category in copy.categories) category.id,
      for (final group in _allGroups(copy)) group.id,
    };

    expect(copiedIds, hasLength(sourceIds.length));
    expect(copiedIds.intersection(sourceIds), isEmpty);
  });

  group('复制预设后按 ID 的引用指向副本，其他引用原样保留', () {
    for (final reference in _references) {
      test(reference.scenario, () {
        final original = reference.read(_source);

        expect(
          reference.read(copy),
          _copiedId(copy, original) ?? original,
          reason: '源引用 $original',
        );
      });
    }
  });
}
