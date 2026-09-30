import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';

const _group = RandomTagGroup(
  id: 'owner',
  name: 'owner',
  nodeType: TagGroupNodeType.config,
  visibilityRules: [
    VisibilityRule(
      id: 'self',
      name: 'self',
      sourceCategoryId: 'cat-pose',
      targetCategoryId: 'owner',
      conditionValue: 'portrait',
    ),
    VisibilityRule(
      id: 'category',
      name: 'category',
      sourceCategoryId: 'cat-pose',
      targetCategoryId: 'cat-lower',
      conditionValue: 'portrait',
    ),
  ],
  conditionalBranchConfig: ConditionalBranchConfig(
    id: 'branch',
    name: 'branch',
    branches: [
      ConditionalBranch(
        name: 'uniform',
        tagGroupIds: ['uniform_child', 'missing_child'],
      ),
    ],
  ),
  children: [
    RandomTagGroup(id: 'uniform_child', name: 'uniform'),
    RandomTagGroup(id: 'casual_child', name: 'casual'),
  ],
);

void _expectGroupReferencesFollowCopy(
  RandomTagGroup copy, {
  required String categoryTarget,
}) {
  expect(copy.id, isNot('owner'));
  expect(copy.visibilityRules.first.targetCategoryId, copy.id);
  expect(copy.visibilityRules.last.targetCategoryId, categoryTarget);

  final childIds = copy.children.map((child) => child.id).toList();
  expect(childIds, isNot(contains('uniform_child')));
  expect(copy.conditionalBranchConfig!.branches.single.tagGroupIds, [
    childIds.first,
    'missing_child',
  ]);
}

void main() {
  test('深拷贝时以本词组为目标的可见性规则与分支引用指向副本', () {
    _expectGroupReferencesFollowCopy(
      _group.deepCopy(),
      categoryTarget: 'cat-lower',
    );
  });

  test('复制预设后词组级与类别级引用都指向副本', () {
    const source = RandomPreset(
      id: 'source',
      name: 'source',
      categories: [
        RandomCategory(
          id: 'cat-lower',
          name: 'lower',
          key: 'lower',
          groups: [_group],
        ),
      ],
    );

    final copy = RandomPreset.copyFrom(source, name: 'copy');
    final copiedCategory = copy.categories.single;

    _expectGroupReferencesFollowCopy(
      copiedCategory.groups.single,
      categoryTarget: copiedCategory.id,
    );
  });
}
