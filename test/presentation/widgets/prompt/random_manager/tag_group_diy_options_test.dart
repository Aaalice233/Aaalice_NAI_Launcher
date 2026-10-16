import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/diy_category_references.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/diy_category_field.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/branch_conditions_editor.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/tag_group_diy_options.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

RandomTagGroup _branching(String id, String name, List<String> targets) =>
    RandomTagGroup(
      id: id,
      name: name,
      conditionalBranchConfig: ConditionalBranchConfig(
        id: '$id-branches',
        name: name,
        branches: [ConditionalBranch(name: 'pick', tagGroupIds: targets)],
      ),
    );

TagGroupDiyOptions _options({
  required List<RandomCategory> categories,
  required RandomTagGroup editing,
  String categoryId = 'cat-outfit',
}) => TagGroupDiyOptions(
  l10n: _l10n,
  presetCategories: categories,
  categoryId: categoryId,
  editingGroup: editing,
);

void main() {
  test('候选类别按 ID 去重并跳过空 ID，同名类别附上键名区分', () {
    final options = _options(
      categories: const [
        RandomCategory(id: 'hair', name: 'Hair', key: 'hairColor'),
        RandomCategory(id: 'hair', name: 'Hair', key: 'hairColor'),
        RandomCategory(id: 'outfit', name: 'Outfit', key: 'clothing'),
        RandomCategory(id: 'uniform', name: 'Outfit', key: 'custom2'),
        RandomCategory(id: '', name: 'Draft', key: 'draft'),
      ],
      editing: const RandomTagGroup(id: 'editing', name: 'Editing'),
    );

    expect(options.categoryOptions, const [
      DiyCategoryOption(id: 'hair', label: 'Hair'),
      DiyCategoryOption(id: 'outfit', label: 'Outfit (clothing)'),
      DiyCategoryOption(id: 'uniform', label: 'Outfit (custom2)'),
    ]);
  });

  test('分支目标是本词组的子词组与同类别其他词组，回到本词组的词组标为循环', () {
    const editing = RandomTagGroup(
      id: 'editing',
      name: 'Editing',
      children: [RandomTagGroup(id: 'child', name: 'Child')],
    );
    final options = _options(
      categories: [
        RandomCategory(
          id: 'cat-outfit',
          name: 'Outfit',
          key: 'clothing',
          groups: [
            editing,
            const RandomTagGroup(id: 'sailor', name: 'Sailor'),
            _branching('blazer', 'Blazer', ['editing']),
          ],
        ),
        const RandomCategory(
          id: 'cat-hair',
          name: 'Hair',
          key: 'hairColor',
          groups: [RandomTagGroup(id: 'elsewhere', name: 'Elsewhere')],
        ),
      ],
      editing: editing,
    );

    expect(options.branchTargetOptions.map((option) => option.id), [
      'child',
      'sailor',
      'blazer',
    ]);
    expect(
      options.branchTargetOptions.first.label,
      _l10n.diy_branchTargetChild('Child'),
    );
    expect(options.cyclicBranchTargetIds, {'editing', 'blazer'});
  });

  test('条件来源包含类别、角色性别、角色数量与其他带分支的词组', () {
    final options = _options(
      categories: [
        RandomCategory(
          id: 'cat-outfit',
          name: 'Outfit',
          key: 'clothing',
          groups: [
            const RandomTagGroup(id: 'editing', name: 'Editing'),
            _branching('mood', 'Mood', const []),
            const RandomTagGroup(id: 'plain', name: 'Plain'),
          ],
        ),
      ],
      editing: const RandomTagGroup(id: 'editing', name: 'Editing'),
    );

    expect(
      options.branchConditionSources.map((source) => (source.id, source.kind)),
      [
        ('cat-outfit', BranchConditionSourceKind.category),
        (characterGenderVariable, BranchConditionSourceKind.characterGender),
        (characterCountReference, BranchConditionSourceKind.characterCount),
        ('mood', BranchConditionSourceKind.branch),
      ],
    );
  });

  test('按键名、类别名称或词组名称保存的存量条件对应到同一来源，重名的不解析', () {
    const editing = RandomTagGroup(
      id: 'editing',
      name: 'Editing',
      conditionalBranchConfig: ConditionalBranchConfig(
        id: 'editing-branches',
        name: 'Editing',
        branches: [
          ConditionalBranch(
            name: 'legacy',
            conditions: {
              'clothing': 'uniform',
              'Hair': 'blonde',
              'shared': 'x',
              'Mood': 'happy',
              'Twin': 'y',
              'gone': 'z',
            },
          ),
        ],
      ),
    );
    final options = _options(
      categories: [
        RandomCategory(
          id: 'cat-outfit',
          name: 'Outfit',
          key: 'clothing',
          groups: [
            editing,
            _branching('mood', 'Mood', const []),
            _branching('twin-a', 'Twin', const []),
            _branching('twin-b', 'Twin', const []),
          ],
        ),
        const RandomCategory(id: 'cat-hair', name: 'Hair', key: 'hairColor'),
        const RandomCategory(id: 'cat-a', name: 'A', key: 'shared'),
        const RandomCategory(id: 'cat-b', name: 'B', key: 'shared'),
      ],
      editing: editing,
    );

    final storedKeys = editing
        .conditionalBranchConfig!
        .branches
        .single
        .conditions
        .keys
        .toSet();
    final legacy = {
      for (final source in options.branchConditionSources)
        if (storedKeys.contains(source.id))
          source.id: (source.label, source.kind),
    };
    expect(legacy, {
      'clothing': ('Outfit', BranchConditionSourceKind.category),
      'Hair': ('Hair', BranchConditionSourceKind.category),
      'Mood': (
        _l10n.diy_conditionSourceBranch('Mood'),
        BranchConditionSourceKind.branch,
      ),
    });
  });
}
