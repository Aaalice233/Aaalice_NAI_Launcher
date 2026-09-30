import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/tag_group_card.dart';

import '../../../../helpers/ink_expectations.dart';

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

class _FixedRandomPresetNotifier extends RandomPresetNotifier {
  @override
  RandomPresetState build() => const RandomPresetState(
    presets: [
      RandomPreset(id: 'preset', name: 'Preset', categories: [_category]),
    ],
    selectedPresetId: 'preset',
  );
}

void main() {
  testWidgets('全部 DIY 配置在最窄屏、放大文字和键盘组合下均走自适应表单', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _FixedRandomPresetNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewPadding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
              viewInsets: const EdgeInsets.only(bottom: 160),
              textScaler: const TextScaler.linear(3),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: TagGroupCard(
              tagGroup: _group,
              categoryId: 'category',
              categoryKey: 'category',
              presetId: 'preset',
            ),
          ),
        ),
      ),
    );

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

  testWidgets('依赖配置表单在最窄屏、3x 文字、安全区和键盘组合下字段与动作均可达，失效引用不崩溃', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(
      tester,
      mediaQuery: (data) => data.copyWith(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
        viewPadding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
        viewInsets: const EdgeInsets.only(bottom: 180),
        textScaler: const TextScaler.linear(3),
      ),
    );
    await _openDiyForm(tester, '依赖配置');

    final sheets = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    expect(sheets, findsNWidgets(2));
    final form = sheets.last;
    final formRect = tester.getRect(form);
    expect(formRect.left, greaterThanOrEqualTo(0));
    expect(formRect.right, lessThanOrEqualTo(320));
    // 夹具的源类别 'source' 不是当前预设里的类别
    expect(
      find.descendant(of: form, matching: find.text('已失效：source')),
      findsOneWidget,
    );

    for (final target in [
      find.byType(DropdownButtonFormField<String>),
      find.byType(EditableText),
      find.byIcon(Icons.block_rounded),
      find.byIcon(Icons.add_rounded),
      find.byType(Switch),
    ]) {
      final inForm = find.descendant(of: form, matching: target).first;
      await tester.ensureVisible(inForm);
      await tester.pump();
      expect(tester.getRect(inForm).overlaps(formRect), isTrue);
      expect(inForm.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    final confirm = find.descendant(of: form, matching: find.text('确定'));
    await tester.scrollUntilVisible(
      confirm,
      200,
      scrollable: find
          .descendant(of: form, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pump();
    expect(confirm.hitTestable(), findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(sheets, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('依赖源下拉以类别 ID 选中并显示名称，改选后保存的是 ID', (tester) async {
    final notifier = _EditablePresetNotifier(_referenceCategories);
    await _pumpReferenceCard(
      tester,
      notifier: notifier,
      group: _referenceGroup.copyWith(
        dependencyConfig: const DependencyConfig(sourceCategoryId: 'cat-hair'),
      ),
    );
    await _openDiyForm(tester, '依赖配置', groupName: _referenceGroup.name);

    final form = _formSurfaces().last;
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
      notifier.savedGroup.dependencyConfig?.sourceCategoryId,
      'cat-outfit',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('按类别名称保存的存量引用在打开编辑器时换成 ID，保存后生效', (tester) async {
    final notifier = _EditablePresetNotifier(_referenceCategories);
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
    final saved = notifier.savedGroup;
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
    final notifier = _EditablePresetNotifier(_referenceCategories);
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
    final rule = notifier.savedGroup.visibilityRules.single;
    expect(rule.sourceCategoryId, 'cat-hair');
    expect(rule.targetCategoryId, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('以本词组 ID 为目标的存量可见性规则显示为本词组，也可重新选作目标', (tester) async {
    final notifier = _EditablePresetNotifier(_referenceCategories);
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
      notifier.savedGroup.visibilityRules.single.targetCategoryId,
      'reference',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('后处理移除类别按 ID 多选，已失效的目标可以移除', (tester) async {
    final notifier = _EditablePresetNotifier(_referenceCategories);
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
    expect(notifier.savedGroup.postProcessRules.single.targetCategoryIds, [
      'cat-outfit',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏 DIY 配置表单使用受限宽度的居中弹窗并保留确认动作', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCard(tester);
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _FixedRandomPresetNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TagGroupCard(
              tagGroup: group,
              categoryId: 'category',
              categoryKey: 'category',
              presetId: 'preset',
            ),
          ),
        ),
      ),
    );

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
    tester.view.physicalSize = const Size(1180, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _FixedRandomPresetNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TagGroupCard(
              tagGroup: _group,
              categoryId: 'category',
              categoryKey: 'category',
              presetId: 'preset',
            ),
          ),
        ),
      ),
    );
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
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpCard(
        tester,
        locale: const Locale('en'),
        mediaQuery: (data) =>
            data.copyWith(textScaler: const TextScaler.linear(3)),
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

  testWidgets('编辑弹窗标签栏的悬停反馈画在分组底色之上', (tester) async {
    tester.view.physicalSize = const Size(1180, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
  Locale locale = const Locale('zh'),
  MediaQueryData Function(MediaQueryData data)? mediaQuery,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomPresetNotifierProvider.overrideWith(
          _FixedRandomPresetNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: (mediaQuery ?? (data) => data)(MediaQuery.of(context)),
          child: child!,
        ),
        home: Scaffold(
          body: TagGroupCard(
            tagGroup: group,
            categoryId: 'category',
            categoryKey: 'category',
            presetId: 'preset',
          ),
        ),
      ),
    ),
  );
}

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

/// 保存只更新内存状态，不触碰持久化存储
class _EditablePresetNotifier extends RandomPresetNotifier {
  _EditablePresetNotifier(this._categories);

  final List<RandomCategory> _categories;

  RandomTagGroup get savedGroup => state.selectedPreset!.categories.first.groups
      .firstWhere((group) => group.id == _referenceGroup.id);

  @override
  RandomPresetState build() => RandomPresetState(
    presets: [
      RandomPreset(id: 'preset', name: 'Preset', categories: _categories),
    ],
    selectedPresetId: 'preset',
  );

  @override
  Future<void> updateCategory(RandomCategory category) async {
    state = state.copyWith(
      presets: [state.selectedPreset!.updateCategory(category)],
    );
  }
}

Future<void> _pumpReferenceCard(
  WidgetTester tester, {
  required _EditablePresetNotifier notifier,
  required RandomTagGroup group,
}) async {
  tester.view.physicalSize = const Size(1180, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [randomPresetNotifierProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TagGroupCard(
            tagGroup: group,
            categoryId: 'cat-hair',
            categoryKey: 'hairColor',
            presetId: 'preset',
          ),
        ),
      ),
    ),
  );
}

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
