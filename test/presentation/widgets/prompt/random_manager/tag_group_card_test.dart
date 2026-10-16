import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch_targets.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/tag_group_card.dart';

import '../../../../helpers/ink_expectations.dart';
import '../../../../helpers/random_preset_test_harness.dart';

const _group = RandomTagGroup(
  id: 'group',
  name: '包含全部复杂配置的超长词组名称',
  conditionalBranchConfig: ConditionalBranchConfig(
    id: 'conditional',
    name: 'conditional',
  ),
  dependencyConfig: DependencyConfig(sourceCategoryId: 'source'),
  visibilityRules: [
    VisibilityRule(
      id: 'visibility',
      name: 'visibility',
      targetCategoryId: 'category',
      sourceCategoryId: 'source',
      conditionValue: 'portrait',
    ),
  ],
  timeCondition: TimeCondition(
    id: 'time',
    name: 'time',
    startMonth: 1,
    startDay: 1,
    endMonth: 12,
    endDay: 31,
  ),
  postProcessRules: [PostProcessRule(id: 'post', name: 'post')],
  emphasisProbability: 0.1,
);

const _category = RandomCategory(
  id: 'category',
  name: 'Category',
  key: 'category',
  groups: [_group],
);

void main() {
  testWidgets('全部 DIY 配置在最窄屏、放大文字和键盘组合下均走自适应表单', (tester) async {
    await _pumpCard(
      tester,
      size: const Size(320, 568),
      textScale: 3,
      padding: const FakeViewPadding(left: 12, top: 24, right: 12, bottom: 16),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    await tester.pumpAndSettle();

    await tester.tap(find.text('包含全部复杂配置的超长词组名称'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    final diyTab = find.byIcon(Icons.account_tree_outlined);
    await tester.ensureVisible(diyTab);
    await tester.pumpAndSettle();
    await tester.tap(diyTab);
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsNWidgets(5));
    expect(tester.takeException(), isNull);

    final firstEdit = find.byKey(const ValueKey('tag-group-diy-action-条件分支'));
    await tester.ensureVisible(firstEdit);
    await tester.pumpAndSettle();
    expect(
      firstEdit.hitTestable(),
      findsOneWidget,
      reason:
          'action=${tester.getRect(firstEdit)} scroll=${tester.getRect(find.byKey(const ValueKey('tag-group-editor-scroll')))}',
    );
    await tester.tap(firstEdit);
    await tester.pumpAndSettle();

    expect(find.text('条件分支'), findsWidgets);
    expect(
      find.byKey(const ValueKey('adaptive-bottom-sheet')),
      findsNWidgets(2),
    );
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('依赖源指向预设中不存在的类别时显示为已失效，表单照常打开', (tester) async {
    await _pumpCard(tester);
    await _openDiyForm(tester, '依赖配置');

    // 夹具的源类别 'source' 不是当前预设里的类别
    expect(
      find.descendant(
        of: _formSurfaces().last,
        matching: find.text('已失效：source'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('依赖配置只在表单标题显示一次名称；依赖源下拉以类别 ID 选中并显示名称，改选后保存的是 ID', (
    tester,
  ) async {
    final notifier = TestRandomPresetNotifier.categories(_referenceCategories);
    await _pumpReferenceCard(
      tester,
      notifier: notifier,
      group: _referenceGroup.copyWith(
        dependencyConfig: const DependencyConfig(sourceCategoryId: 'cat-hair'),
      ),
    );
    await _openDiyForm(tester, '依赖配置', groupName: _referenceGroup.name);

    final form = _formSurfaces().last;
    expect(find.descendant(of: form, matching: find.text('依赖配置')), findsOne);
    final dropdown = find.descendant(
      of: form,
      matching: find.byType(DropdownButtonFormField<String>),
    );
    expect(
      find.descendant(of: dropdown, matching: find.text('发色')),
      findsOneWidget,
    );

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('服装').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: dropdown, matching: find.text('服装')),
      findsOneWidget,
    );

    await _confirmAndSave(tester);
    expect(
      notifier
          .savedGroup(_referenceGroup.id)
          .dependencyConfig
          ?.sourceCategoryId,
      'cat-outfit',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('按类别名称保存的存量引用在打开编辑器时换成 ID，保存后生效', (tester) async {
    final notifier = TestRandomPresetNotifier.categories(_referenceCategories);
    await _pumpReferenceCard(
      tester,
      notifier: notifier,
      group: _referenceGroup.copyWith(
        dependencyConfig: const DependencyConfig(sourceCategoryId: '发色'),
        visibilityRules: const [
          VisibilityRule(
            id: 'legacy',
            name: 'legacy',
            sourceCategoryId: 'hairColor',
            targetCategoryId: '服装',
            conditionValue: 'portrait',
          ),
        ],
        postProcessRules: const [
          PostProcessRule(
            id: 'legacy-post',
            name: 'legacy-post',
            action: PostProcessAction.removeCategory,
            targetCategoryIds: ['服装', 'gone'],
          ),
        ],
      ),
    );
    await _openDiyForm(tester, '依赖配置', groupName: _referenceGroup.name);

    final dropdown = find.descendant(
      of: _formSurfaces().last,
      matching: find.byType(DropdownButtonFormField<String>),
    );
    expect(
      find.descendant(of: dropdown, matching: find.text('发色')),
      findsOneWidget,
    );

    await _confirmAndSave(tester);
    final saved = notifier.savedGroup(_referenceGroup.id);
    expect(saved.dependencyConfig?.sourceCategoryId, 'cat-hair');
    expect(saved.visibilityRules.single.sourceCategoryId, 'cat-hair');
    expect(saved.visibilityRules.single.targetCategoryId, 'cat-outfit');
    // 找不到对应类别的旧值原样保留，界面标记为已失效
    expect(saved.postProcessRules.single.targetCategoryIds, [
      'cat-outfit',
      'gone',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('可见性规则新增后立即可编辑，所选类别按 ID 保存', (tester) async {
    final notifier = TestRandomPresetNotifier.categories(_referenceCategories);
    await _pumpReferenceCard(
      tester,
      notifier: notifier,
      group: _referenceGroup,
    );
    await _openDiyForm(tester, '可见性规则', groupName: _referenceGroup.name);

    final form = _formSurfaces().last;
    await tester.tap(find.descendant(of: form, matching: find.text('添加规则')));
    await tester.pumpAndSettle();

    final dropdowns = find.descendant(
      of: form,
      matching: find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdowns, findsNWidgets(2));
    expect(
      find.descendant(of: dropdowns.first, matching: find.text('未设置')),
      findsOneWidget,
    );
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('发色').last);
    await tester.pumpAndSettle();

    await _confirmAndSave(tester);
    final rule = notifier.savedGroup(_referenceGroup.id).visibilityRules.single;
    expect(rule.sourceCategoryId, 'cat-hair');
    expect(rule.targetCategoryId, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('以本词组 ID 为目标的存量可见性规则显示为本词组，也可重新选作目标', (tester) async {
    final notifier = TestRandomPresetNotifier.categories(_referenceCategories);
    await _pumpReferenceCard(
      tester,
      notifier: notifier,
      group: _referenceGroup.copyWith(
        visibilityRules: const [
          VisibilityRule(
            id: 'self',
            name: '只控制本词组',
            sourceCategoryId: 'cat-hair',
            targetCategoryId: 'reference',
            conditionValue: 'portrait',
          ),
        ],
      ),
    );
    await _openDiyForm(tester, '可见性规则', groupName: _referenceGroup.name);

    final form = _formSurfaces().last;
    expect(find.descendant(of: form, matching: find.text('本词组')), findsOne);
    expect(
      find.descendant(of: form, matching: find.textContaining('已失效')),
      findsNothing,
    );

    await tester.tap(find.descendant(of: form, matching: find.text('只控制本词组')));
    await tester.pumpAndSettle();
    final target = find
        .descendant(
          of: form,
          matching: find.byType(DropdownButtonFormField<String>),
        )
        .last;
    expect(find.descendant(of: target, matching: find.text('本词组')), findsOne);

    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.tap(find.text('服装').last);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    await tester.tap(find.text('本词组').last);
    await tester.pumpAndSettle();

    await _confirmAndSave(tester);
    expect(
      notifier
          .savedGroup(_referenceGroup.id)
          .visibilityRules
          .single
          .targetCategoryId,
      'reference',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('后处理移除类别按 ID 多选，已失效的目标可以移除', (tester) async {
    final notifier = TestRandomPresetNotifier.categories(_referenceCategories);
    await _pumpReferenceCard(
      tester,
      notifier: notifier,
      group: _referenceGroup.copyWith(
        postProcessRules: const [
          PostProcessRule(
            id: 'post',
            name: '移除服装',
            action: PostProcessAction.removeCategory,
            targetCategoryIds: ['gone'],
          ),
        ],
      ),
    );
    await _openDiyForm(tester, '后处理规则', groupName: _referenceGroup.name);

    final form = _formSurfaces().last;
    await tester.tap(find.descendant(of: form, matching: find.text('移除服装')));
    await tester.pumpAndSettle();

    final stale = find.widgetWithText(InputChip, '已失效：gone');
    expect(stale, findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, '服装'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: stale, matching: find.byTooltip('删除')),
    );
    await tester.pumpAndSettle();
    expect(stale, findsNothing);

    await _confirmAndSave(tester);
    expect(
      notifier
          .savedGroup(_referenceGroup.id)
          .postProcessRules
          .single
          .targetCategoryIds,
      ['cat-outfit'],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏 DIY 配置表单使用受限宽度的居中弹窗并保留确认动作', (tester) async {
    await _pumpCard(tester, size: const Size(1600, 900));
    await _openDiyForm(tester, '条件分支');

    final forms = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(forms, findsNWidgets(2));
    final formRect = tester.getRect(forms.last);
    expect(formRect.width, lessThanOrEqualTo(620));
    expect(formRect.center.dx, moreOrLessEquals(800));
    expect(
      find.descendant(of: forms.last, matching: find.text('确定')).hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('概率滑块以字段名朗读，读数与界面一致且按四舍五入显示', (tester) async {
    // 0.1 分 10 格的第 7 格插值结果，截断取整会显示成 6%
    const group = RandomTagGroup(
      id: 'rounding',
      name: '取整词组',
      probability: 0.35,
      emphasisProbability: 0.06999999999999999,
    );
    await _pumpCard(tester, group: group);

    await tester.tap(find.text('取整词组'));
    await tester.pumpAndSettle();
    expect(_sliderNode('概率').value, '35%');
    expect(find.text('35%'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_tree_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('7%'));
    await tester.pumpAndSettle();

    final emphasis = _sliderNode('强调概率');
    expect(emphasis.value, '7%');
    expect(emphasis.increasedValue, '8%');
    expect(find.text('6%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选择模式下拉框的悬停反馈画在分组底色之上', (tester) async {
    await _pumpCard(tester);
    await tester.tap(find.text('包含全部复杂配置的超长词组名称'));
    await tester.pumpAndSettle();

    final selector = find.byType(DropdownButton<SelectionMode>);
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    final section = find.byKey(const ValueKey('tag-group-editor-surface'));
    final theme = Theme.of(tester.element(selector));
    await hoverOver(tester, selector);
    expectInkOnTop(
      tester,
      section,
      ink: theme.hoverColor,
      below: sectionSurfaceColor(theme.colorScheme),
    );
  });

  testWidgets('删除词组确认在短横屏与最窄屏放大文字下正文可滚动、取消与删除均可点', (tester) async {
    // flutter_test 字体下英文约为真实宽度两倍，确认正文最长，作为压力场景
    final l10n = lookupAppLocalizations(const Locale('en'));
    for (final size in const [Size(740, 360), Size(320, 568)]) {
      await _pumpCard(
        tester,
        size: size,
        textScale: 3,
        locale: const Locale('en'),
      );

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      final deleteItem = find.text(l10n.common_delete).last;
      await tester.ensureVisible(deleteItem);
      await tester.pumpAndSettle();
      await tester.tap(deleteItem);
      await tester.pumpAndSettle();

      final reason = 'size=$size';
      expect(
        find.text(l10n.randomManager_deleteTagGroupTitle),
        findsOneWidget,
        reason: reason,
      );
      expect(tester.takeException(), isNull, reason: reason);
      for (final label in [l10n.common_cancel, l10n.common_delete]) {
        final button = find.ancestor(
          of: find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(label),
          ),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        );
        expect(button.hitTestable(), findsOneWidget, reason: '$label $reason');
      }
      await tester.tap(find.text(l10n.common_cancel));
      await tester.pumpAndSettle();
    }
  });

  group('条件分支输出同类别词组', () {
    const owner = RandomTagGroup(
      id: 'reference',
      name: '引用词组',
      conditionalBranchConfig: ConditionalBranchConfig(
        id: 'outfit',
        name: '服装类型',
        branches: [
          ConditionalBranch(name: '制服', tagGroupIds: ['sailor', 'deleted']),
        ],
      ),
    );
    const sailor = RandomTagGroup(id: 'sailor', name: '水手服');
    // 已输出引用词组，再被它选为目标会形成循环
    const blazer = RandomTagGroup(
      id: 'blazer',
      name: '西装',
      conditionalBranchConfig: ConditionalBranchConfig(
        id: 'back',
        name: 'back',
        branches: [
          ConditionalBranch(name: '回到引用词组', tagGroupIds: ['reference']),
        ],
      ),
    );
    const categories = [
      RandomCategory(
        id: 'cat-hair',
        name: '发色',
        key: 'hairColor',
        groups: [owner, sailor, blazer],
      ),
      RandomCategory(id: 'cat-outfit', name: '服装', key: 'custom2'),
    ];

    testWidgets('分支可选同类别词组与条件，循环目标不可选，已删除的目标显示为已失效', (tester) async {
      final notifier = TestRandomPresetNotifier.categories(categories);
      await _pumpReferenceCard(tester, notifier: notifier, group: owner);
      await _openDiyForm(tester, '条件分支', groupName: owner.name);

      final form = _formSurfaces().last;
      await tester.tap(
        find.descendant(of: form, matching: find.text('制服')).last,
      );
      await tester.pumpAndSettle();

      FilterChip chip(String label) => tester.widget<FilterChip>(
        find.ancestor(of: find.text(label), matching: find.byType(FilterChip)),
      );
      expect(chip('水手服').selected, isTrue);
      expect(chip('西装').onSelected, isNull);
      expect(find.byTooltip('会形成循环引用'), findsOneWidget);
      expect(find.text('灰色的词组已经直接或间接输出本词组，选择会形成循环引用'), findsOneWidget);

      final missing = find.ancestor(
        of: find.text('已失效：deleted'),
        matching: find.byType(InputChip),
      );
      await tester.ensureVisible(missing);
      await tester.tap(
        find.descendant(of: missing, matching: find.byTooltip('删除')),
      );
      await tester.pumpAndSettle();
      expect(find.text('已失效：deleted'), findsNothing);

      final addCondition = find.text('添加条件');
      await tester.ensureVisible(addCondition);
      await tester.tap(addCondition);
      await tester.pumpAndSettle();
      expect(find.text('请填写条件值'), findsOneWidget);
      await tester.enterText(
        find.descendant(of: form, matching: find.byType(EditableText)).last,
        'blonde',
      );
      await tester.pumpAndSettle();

      await _confirmAndSave(tester);
      final branch = notifier
          .savedGroup(_referenceGroup.id)
          .conditionalBranchConfig!
          .branches
          .single;
      expect(branch.tagGroupIds, ['sailor']);
      expect(branch.conditions, {'cat-hair': 'blonde'});
      expect(tester.takeException(), isNull);
    });

    testWidgets('被分支输出的词组显示徽标，点按打开引用它的分支', (tester) async {
      final notifier = TestRandomPresetNotifier.categories(categories);
      final references = categories.first.branchReferences(activeOnly: true);
      await _pumpReferenceCard(
        tester,
        notifier: notifier,
        group: sailor,
        branchOutputBy: references['sailor']!,
      );

      final badge = find.text('由「引用词组」的条件分支输出');
      expect(badge, findsOneWidget);
      expect(
        find.byTooltip(
          '这个词组不参与类别的常规抽取，只在引用它的分支被选中时输出；停用或删除这些分支后恢复常规抽取。点按可跳转到该分支',
        ),
        findsOneWidget,
      );

      await tester.tap(badge);
      await tester.pumpAndSettle();

      expect(find.text('编辑：制服'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('删除被分支引用的词组前提示引用它的分支会显示为已失效', (tester) async {
      final notifier = TestRandomPresetNotifier.categories(categories);
      await _pumpReferenceCard(tester, notifier: notifier, group: sailor);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除').last);
      await tester.pumpAndSettle();

      expect(
        find.text('「引用词组」的条件分支引用了这个词组，删除后这些分支里的这一项会显示为已失效'),
        findsOneWidget,
      );
    });
  });

  testWidgets('编辑弹窗标签栏的悬停反馈画在分组底色之上', (tester) async {
    await _pumpCard(tester);
    await tester.tap(find.text('包含全部复杂配置的超长词组名称'));
    await tester.pumpAndSettle();

    final diyTab = find.descendant(
      of: find.byType(TabBar),
      matching: find.byIcon(Icons.account_tree_outlined),
    );
    final colors = Theme.of(tester.element(diyTab)).colorScheme;
    await hoverOver(tester, diyTab);
    // 固定标签栏自带不透明底色，墨水必须画在这层底色之上
    expectInkOnTop(
      tester,
      find
          .ancestor(of: find.byType(TabBar), matching: find.byType(ColoredBox))
          .first,
      // Material 3 标签栏未选中项的默认悬停色
      ink: colors.onSurface.withValues(alpha: 0.08),
      below: sectionSurfaceColor(colors),
    );
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  RandomTagGroup group = _group,
  Size size = const Size(1180, 900),
  double textScale = 1,
  FakeViewPadding padding = FakeViewPadding.zero,
  Locale locale = const Locale('zh'),
}) => pumpRandomManager(
  tester,
  size: size,
  textScale: textScale,
  padding: padding,
  locale: locale,
  presets: () => TestRandomPresetNotifier.categories(const [_category]),
  home: Scaffold(
    body: TagGroupCard(
      tagGroup: group,
      categoryId: 'category',
      categoryKey: 'category',
      presetId: 'preset',
    ),
  ),
);

const _referenceGroup = RandomTagGroup(id: 'reference', name: '引用词组');

const _referenceCategories = [
  RandomCategory(
    id: 'cat-hair',
    name: '发色',
    key: 'hairColor',
    groups: [_referenceGroup],
  ),
  RandomCategory(id: 'cat-outfit', name: '服装', key: 'custom2'),
];

Future<void> _pumpReferenceCard(
  WidgetTester tester, {
  required TestRandomPresetNotifier notifier,
  required RandomTagGroup group,
  List<BranchReference> branchOutputBy = const [],
}) => pumpRandomManager(
  tester,
  locale: const Locale('zh'),
  presets: () => notifier,
  home: Scaffold(
    body: TagGroupCard(
      tagGroup: group,
      categoryId: 'cat-hair',
      categoryKey: 'hairColor',
      presetId: 'preset',
      branchOutputBy: branchOutputBy,
    ),
  ),
);

Finder _formSurfaces() => find.byWidgetPredicate(
  (widget) =>
      widget.key == const ValueKey('adaptive-bottom-sheet') ||
      widget.key == const ValueKey('adaptive-centered-form'),
);

Future<void> _confirmAndSave(WidgetTester tester) async {
  final form = _formSurfaces().last;
  final confirm = find.descendant(of: form, matching: find.text('确定'));
  await tester.scrollUntilVisible(
    confirm,
    200,
    scrollable: find
        .descendant(of: form, matching: find.byType(Scrollable))
        .first,
  );
  await tester.tap(confirm);
  await tester.pumpAndSettle();
  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();
}

Future<void> _openDiyForm(
  WidgetTester tester,
  String section, {
  String groupName = '包含全部复杂配置的超长词组名称',
}) async {
  await tester.tap(find.text(groupName));
  await tester.pumpAndSettle();

  final diyTab = find.byIcon(Icons.account_tree_outlined);
  await tester.ensureVisible(diyTab);
  await tester.pumpAndSettle();
  await tester.tap(diyTab);
  await tester.pumpAndSettle();

  final action = find.byKey(ValueKey('tag-group-diy-action-$section'));
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

SemanticsNode _sliderNode(String label) {
  final slider = find.semantics.byPredicate(
    (node) => node.flagsCollection.isSlider && node.label == label,
  );
  expect(slider, findsOne, reason: label);
  return slider.evaluate().single;
}
