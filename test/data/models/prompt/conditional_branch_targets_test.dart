import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch_targets.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';

RandomTagGroup _owner(
  String id,
  List<ConditionalBranch> branches, {
  bool enabled = true,
  bool configEnabled = true,
}) {
  return RandomTagGroup(
    id: id,
    name: id,
    enabled: enabled,
    conditionalBranchConfig: ConditionalBranchConfig(
      id: '${id}_config',
      name: id,
      enabled: configEnabled,
      branches: branches,
    ),
  );
}

RandomCategory _category(List<RandomTagGroup> groups) =>
    RandomCategory(id: 'outfit', name: 'Outfit', key: 'outfit', groups: groups);

void main() {
  test('只有启用词组里启用配置的启用分支才让目标退出常规抽取', () {
    final category = _category([
      _owner('type', const [
        ConditionalBranch(name: 'uniform', tagGroupIds: ['uniform', 'gone']),
        ConditionalBranch(
          name: 'casual',
          tagGroupIds: ['casual'],
          enabled: false,
        ),
        ConditionalBranch(name: 'self', tagGroupIds: ['type']),
      ]),
      _owner('off', const [
        ConditionalBranch(name: 'x', tagGroupIds: ['swimsuit']),
      ], enabled: false),
      _owner('config_off', const [
        ConditionalBranch(name: 'y', tagGroupIds: ['bodysuit']),
      ], configEnabled: false),
      const RandomTagGroup(id: 'uniform', name: 'uniform'),
      const RandomTagGroup(id: 'casual', name: 'casual'),
      const RandomTagGroup(id: 'swimsuit', name: 'swimsuit'),
      const RandomTagGroup(id: 'bodysuit', name: 'bodysuit'),
    ]);

    expect(category.branchOwnedGroupIds, {'uniform'});

    final all = category.branchReferences();
    expect(all.keys, containsAll(['uniform', 'casual', 'swimsuit', 'bodysuit']));
    expect(all, isNot(contains('gone')));
    expect(all, isNot(contains('type')));
    expect(all['casual']!.single.branchIndex, 1);
  });

  test('目标经由任何分支（含停用的）能回到自身即为循环', () {
    final category = _category([
      _owner('a', const [
        ConditionalBranch(name: 'to b', tagGroupIds: ['b']),
      ]),
      _owner('b', const [
        ConditionalBranch(name: 'to c', tagGroupIds: ['c'], enabled: false),
      ]),
      _owner('c', const []),
      const RandomTagGroup(id: 'd', name: 'd'),
    ]);

    expect(category.branchTargetCreatesCycle('c', 'a'), isTrue);
    expect(category.branchTargetCreatesCycle('b', 'a'), isTrue);
    expect(category.branchTargetCreatesCycle('a', 'a'), isTrue);
    expect(category.branchTargetCreatesCycle('a', 'd'), isFalse);
    expect(category.branchTargetCreatesCycle('c', 'd'), isFalse);
  });

  test('复制类别与预设时分支改为指向副本里的同类别词组', () {
    final category = _category([
      _owner('type', const [
        ConditionalBranch(name: 'uniform', tagGroupIds: ['uniform', 'gone']),
      ]),
      const RandomTagGroup(id: 'uniform', name: 'uniform'),
    ]);

    void expectRemapped(RandomCategory copy) {
      final copiedUniform = copy.groups[1];
      expect(copiedUniform.id, isNot('uniform'));
      expect(
        copy.groups.first.conditionalBranchConfig!.branches.single.tagGroupIds,
        [copiedUniform.id, 'gone'],
      );
    }

    expectRemapped(category.deepCopy());
    expectRemapped(
      RandomPreset.copyFrom(
        RandomPreset(id: 'p', name: 'p', categories: [category]),
        name: 'copy',
      ).categories.single,
    );
  });

  test('分支条件在类别变量中按标签比较键判断包含，与/或逻辑生效', () {
    const context = {
      'cat-eyes': '{Blue Eyes}, long hair',
      'character_gender': 'girl',
    };

    expect(
      const ConditionalBranch(
        name: 'b',
        conditions: {'cat-eyes': 'blue_eyes'},
      ).checkCondition(context),
      isTrue,
    );
    expect(
      const ConditionalBranch(
        name: 'b',
        conditions: {'cat-eyes': 'blue', 'character_gender': 'girl'},
      ).checkCondition(context),
      isFalse,
    );
    expect(
      const ConditionalBranch(
        name: 'b',
        conditions: {'cat-eyes': 'blue', 'character_gender': 'girl'},
        logicType: LogicType.or,
      ).checkCondition(context),
      isTrue,
    );
    expect(
      const ConditionalBranch(
        name: 'b',
        conditions: {'missing': 'x'},
      ).checkCondition(context),
      isFalse,
    );
  });
}
