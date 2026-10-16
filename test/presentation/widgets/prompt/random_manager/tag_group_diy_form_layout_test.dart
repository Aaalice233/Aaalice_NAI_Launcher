import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/data/models/prompt/post_process_rule.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/time_condition.dart';
import 'package:nai_launcher/data/models/prompt/visibility_rule.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/surface_ink_well.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/tag_group_card.dart';

import '../../../../helpers/adaptive_panel_expectations.dart';
import '../../../../helpers/random_preset_test_harness.dart';
import '../../../../helpers/reachability_expectations.dart';

// flutter_test 字体每个字形 1em，英文宽度约为真实两倍，作为最窄的压力场景
const _locale = Locale('en');
const _widths = [320.0, 600.0, 840.0, 1180.0, 1600.0];
const _textScales = [1.0, 3.0];
const _minTouchExtent = 44.0;

const _group = RandomTagGroup(
  id: 'group',
  name: 'Group',
  conditionalBranchConfig: ConditionalBranchConfig(
    id: 'branch',
    name: 'Branch',
    branches: [
      ConditionalBranch(
        name: 'Uniform',
        probability: 60,
        tagGroupIds: ['sailor', 'removed'],
        conditions: {'cat-outfit': 'uniform', 'character_gender': 'girl'},
      ),
      ConditionalBranch(name: 'Casual', probability: 40, enabled: false),
    ],
  ),
  dependencyConfig: DependencyConfig(
    sourceCategoryId: 'cat-hair',
    mappingRules: {'1': '0-3', '2': '0-2'},
  ),
  visibilityRules: [
    VisibilityRule(
      id: 'rule',
      name: 'Portrait hides outfit',
      sourceCategoryId: 'cat-hair',
      targetCategoryId: 'cat-outfit',
      conditionValue: 'portrait',
      enabled: false,
    ),
  ],
  // 关闭每年重复时才出现年份字段，布局矩阵覆盖字段最多的形态
  timeCondition: TimeCondition(
    id: 'time',
    name: 'Always',
    startMonth: 1,
    startDay: 1,
    endMonth: 12,
    endDay: 31,
    recurring: false,
    specificYear: 2026,
  ),
  postProcessRules: [
    PostProcessRule(
      id: 'post',
      name: 'Sleeping',
      triggerTags: ['sleeping'],
      action: PostProcessAction.removeCategory,
      targetCategoryIds: ['cat-outfit', 'gone'],
    ),
  ],
);

const _categories = [
  RandomCategory(
    id: 'cat-hair',
    name: '发色',
    key: 'hairColor',
    isBuiltin: true,
    groups: [
      _group,
      RandomTagGroup(id: 'sailor', name: 'Sailor uniform'),
      // 已输出本词组，再被选为目标会形成循环
      RandomTagGroup(
        id: 'blazer',
        name: 'Blazer',
        conditionalBranchConfig: ConditionalBranchConfig(
          id: 'blazer-branch',
          name: 'Blazer branch',
          branches: [
            ConditionalBranch(name: 'Back', tagGroupIds: ['group']),
          ],
        ),
      ),
    ],
  ),
  RandomCategory(id: 'cat-outfit', name: 'Outfit', key: 'custom2'),
];

final _l10n = lookupAppLocalizations(_locale);

Finder _formSurfaces() => find.byWidgetPredicate(
  (widget) =>
      widget.key == const ValueKey('adaptive-bottom-sheet') ||
      widget.key == const ValueKey('adaptive-centered-form'),
);

const _confirmKey = ValueKey('tag-group-diy-form-confirm');

// Material 3 的 IconButton 也是 ButtonStyleButton，按具体按钮族筛选；确认按钮单独校验
Finder _buttons() => find.byWidgetPredicate(
  (w) => (w is TextButton || w is FilledButton) && w.key != _confirmKey,
);
Finder _dropdowns() => find.byWidgetPredicate((w) => w is DropdownButton);

/// 一个 DIY 表单：入口标题、打开后需要展开的编辑区，以及展开后各类控件的数量
class _FormCase {
  const _FormCase({
    required this.title,
    required this.controls,
    this.expandText,
  });

  final String title;
  final String? expandText;
  final Map<Finder Function(), int> controls;
}

final _formCases = <_FormCase>[
  _FormCase(
    title: _l10n.randomManager_conditionalBranch,
    expandText: 'Uniform',
    controls: {
      _buttons: 2,
      () => find.byType(IconButton): 6,
      () => find.byType(SurfaceInkWell): 2,
      () => find.byType(Slider): 1,
      () => find.byType(FilterChip): 2,
      () => find.byType(InputChip): 1,
      () => find.byType(ChoiceChip): 2,
      _dropdowns: 2,
      () => find.byType(Switch): 1,
      () => find.byType(EditableText): 3,
    },
  ),
  _FormCase(
    title: _l10n.randomManager_dependencyConfig,
    controls: {
      _buttons: 2,
      () => find.byType(IconButton): 3,
      () => find.byType(SurfaceInkWell): 4,
      _dropdowns: 1,
      () => find.byType(Switch): 1,
      () => find.byType(EditableText): 1,
    },
  ),
  _FormCase(
    title: _l10n.randomManager_visibilityRules,
    expandText: 'Portrait hides outfit',
    controls: {
      _buttons: 1,
      () => find.byType(IconButton): 3,
      _dropdowns: 3,
      () => find.byType(Switch): 2,
      () => find.byType(EditableText): 2,
    },
  ),
  _FormCase(
    title: _l10n.randomManager_timeCondition,
    controls: {
      () => find.byType(IconButton): 1,
      () => find.byType(SurfaceInkWell): 3,
      _dropdowns: 5,
      () => find.byType(Switch): 2,
      () => find.byType(EditableText): 1,
    },
  ),
  _FormCase(
    title: _l10n.randomManager_postProcessRules,
    expandText: 'Sleeping',
    controls: {
      _buttons: 1,
      () => find.byType(IconButton): 3,
      () => find.byType(SurfaceInkWell): 2,
      _dropdowns: 1,
      () => find.byType(FilterChip): 2,
      () => find.byType(InputChip): 1,
      () => find.byType(Switch): 1,
      () => find.byType(EditableText): 2,
    },
  ),
];

void main() {
  for (final formCase in _formCases) {
    for (final textScale in _textScales) {
      testWidgets(
        '${formCase.title} 在 320–1600 宽度、${textScale}x 文字下无溢出且全部控件可达',
        (tester) async {
          for (final width in _widths) {
            await _openForm(
              tester,
              formCase,
              size: Size(width, 900),
              textScale: textScale,
            );
            await _expectFormUsable(
              tester,
              formCase,
              reason: 'width=$width scale=$textScale',
            );
          }
        },
      );
    }

    testWidgets('${formCase.title} 在短横屏、软键盘与安全区下可滚动到全部控件', (tester) async {
      for (final textScale in _textScales) {
        await _openForm(
          tester,
          formCase,
          size: const Size(740, 360),
          textScale: textScale,
          padding: const FakeViewPadding(left: 32, right: 32, bottom: 16),
          keyboardInset: 160,
        );
        await _expectFormUsable(
          tester,
          formCase,
          reason: 'landscape scale=$textScale',
        );
      }
    });
  }
}

Future<void> _openForm(
  WidgetTester tester,
  _FormCase formCase, {
  required Size size,
  required double textScale,
  FakeViewPadding padding = FakeViewPadding.zero,
  double keyboardInset = 0,
}) async {
  await pumpRandomManager(
    tester,
    size: size,
    textScale: textScale,
    padding: padding,
    presets: () => TestRandomPresetNotifier.categories(_categories),
    home: const Scaffold(
      body: TagGroupCard(
        tagGroup: _group,
        categoryId: 'cat-hair',
        categoryKey: 'hairColor',
        presetId: 'preset',
      ),
    ),
  );

  await tester.tap(find.text(_group.name));
  await tester.pumpAndSettle();
  final diyTab = find.byIcon(Icons.account_tree_outlined);
  await tester.ensureVisible(diyTab);
  await tester.pumpAndSettle();
  await tester.tap(diyTab);
  await tester.pumpAndSettle();

  final action = find.byKey(ValueKey('tag-group-diy-action-${formCase.title}'));
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(_formSurfaces(), findsNWidgets(2));

  final expandText = formCase.expandText;
  if (expandText != null) {
    final item = find
        .descendant(of: _formSurfaces().last, matching: find.text(expandText))
        .last;
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  // 软键盘在 DIY 表单内编辑字段时才弹出，只作用于当前路由
  if (keyboardInset > 0) {
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
    await tester.pumpAndSettle();
  }
}

Future<void> _expectFormUsable(
  WidgetTester tester,
  _FormCase formCase, {
  required String reason,
}) async {
  final form = _formSurfaces().last;
  final body = find
      .descendant(of: form, matching: find.byType(Scrollable))
      .first;
  expect(tester.takeException(), isNull, reason: 'open $reason');
  expectPanelHeaderScrollsWithContent(tester);

  for (final entry in formCase.controls.entries) {
    final controls = find.descendant(of: form, matching: entry.key());
    expect(
      controls,
      findsNWidgets(entry.value),
      reason: '${entry.key()} $reason',
    );
    for (var i = 0; i < entry.value; i++) {
      final control = controls.at(i);
      await revealOnScreen(tester, control);
      final widget = tester.widget(control);
      final touchControl =
          widget is! SurfaceInkWell &&
          widget is! Slider &&
          widget is! EditableText;
      expectReachable(
        tester,
        control,
        reason: '${widget.runtimeType} #$i $reason',
        within: form,
        minExtent: touchControl ? _minTouchExtent : 0,
      );
    }
  }

  // 确认按钮随正文滚动，列表按需构建，滚到末尾才会出现
  final confirm = find.descendant(of: form, matching: find.byKey(_confirmKey));
  await tester.scrollUntilVisible(confirm, 200, scrollable: body);
  await tester.pump();
  expect(confirm.hitTestable(), findsOneWidget, reason: 'confirm $reason');
  expect(
    tester.getSize(confirm).shortestSide,
    greaterThanOrEqualTo(_minTouchExtent),
    reason: 'confirm $reason',
  );
  expect(tester.takeException(), isNull, reason: reason);
}
