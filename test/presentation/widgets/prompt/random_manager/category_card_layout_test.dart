import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_slider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/category_card.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/category_card_list.dart';

import '../../../../helpers/random_preset_test_harness.dart';
import '../../../../helpers/reachability_expectations.dart';
import '../../../../helpers/text_layout_expectations.dart';

// flutter_test 字体每个字形 1em，英文宽度约为真实两倍，作为最窄的压力场景
const _locale = Locale('en');
const _widths = [320.0, 600.0, 840.0, 1180.0, 1600.0];
const _textScales = [1.0, 3.0];
const _minTouchExtent = 44.0;
const _landscape = Size(740, 360);
const _landscapePadding = FakeViewPadding(left: 32, right: 32, bottom: 16);
const _keyboardInset = 160.0;

final _l10n = lookupAppLocalizations(_locale);

const _category = RandomCategory(
  id: 'cat-hair',
  name: 'Hair colour',
  key: 'hairColor',
  groups: [
    RandomTagGroup(
      id: 'group',
      name: 'Group',
      tags: [WeightedTag(tag: 'blonde_hair', weight: 1)],
    ),
    // 让 Group 只经由分支输出，列表里显示说明徽标
    RandomTagGroup(
      id: 'owner',
      name: 'Owner',
      conditionalBranchConfig: ConditionalBranchConfig(
        id: 'owner-branches',
        name: 'Owner branches',
        branches: [
          ConditionalBranch(name: 'Pick', tagGroupIds: ['group']),
        ],
      ),
    ),
  ],
);

TestRandomPresetNotifier _presets() =>
    TestRandomPresetNotifier.categories(const [
      _category,
      RandomCategory(id: 'cat-outfit', name: 'Outfit', key: 'custom2'),
    ]);

Finder _card() =>
    find.byKey(ValueKey('random-manager-category-${_category.id}'));

Finder _overview() =>
    find.byKey(const ValueKey('random-manager-overview-card'));

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required Widget body,
  FakeViewPadding padding = FakeViewPadding.zero,
}) => pumpRandomManager(
  tester,
  size: size,
  textScale: textScale,
  padding: padding,
  presets: _presets,
  home: Scaffold(body: SafeArea(child: body)),
);

Future<void> _expectReachable(
  WidgetTester tester,
  Finder control, {
  required Finder container,
  required String reason,
  bool touchTarget = true,
}) async {
  expect(control, findsOneWidget, reason: reason);
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  expectReachable(
    tester,
    control,
    reason: reason,
    within: container,
    minExtent: touchTarget ? _minTouchExtent : 0,
  );
}

Future<void> _expectTextComplete(
  WidgetTester tester,
  Finder text, {
  required Finder container,
  required String reason,
}) async {
  await tester.ensureVisible(text);
  await tester.pumpAndSettle();
  expectFullyVisible(tester, text, reason: reason);
  final rect = tester.getRect(text);
  final bounds = tester.getRect(container);
  expect(rect.left, greaterThanOrEqualTo(bounds.left - 0.5), reason: reason);
  expect(rect.right, lessThanOrEqualTo(bounds.right + 0.5), reason: reason);
}

Future<void> _expectCategoryCardUsable(
  WidgetTester tester, {
  required String reason,
}) async {
  expect(tester.takeException(), isNull, reason: 'collapsed $reason');
  final header = find
      .ancestor(of: find.text(_category.name), matching: find.byType(InkWell))
      .first;
  await _expectReachable(
    tester,
    header,
    container: _card(),
    reason: 'header $reason',
  );
  await tester.tap(header);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'expanded $reason');

  for (final scope in [
    _l10n.scope_all,
    _l10n.randomManager_global,
    _l10n.scope_character,
  ]) {
    await _expectReachable(
      tester,
      _button(scope),
      container: _card(),
      reason: 'scope $scope $reason',
    );
  }
  await _expectReachable(
    tester,
    find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is NamedSlider &&
            widget.label == _l10n.randomManager_probability,
      ),
      matching: find.byType(Slider),
    ),
    container: _card(),
    touchTarget: false,
    reason: 'probability $reason',
  );
  await _expectTextComplete(
    tester,
    find.text(_l10n.randomManager_tagGroupList),
    container: _card(),
    reason: 'group list title $reason',
  );
  await _expectReachable(
    tester,
    _button(_l10n.randomManager_addTagGroup),
    container: _card(),
    reason: 'add group $reason',
  );
  final groupRow = find.ancestor(
    of: find.text('Group'),
    matching: find.byType(Row),
  );
  await _expectReachable(
    tester,
    find.descendant(of: groupRow.first, matching: find.byType(Switch)),
    container: _card(),
    reason: 'group switch $reason',
  );
  await _expectReachable(
    tester,
    find
        .ancestor(
          of: find.byIcon(Icons.more_horiz_rounded),
          matching: find.byType(IconButton),
        )
        .first,
    container: _card(),
    reason: 'group menu $reason',
  );
  final badge = _l10n.randomManager_branchOutputBadge('Owner');
  await _expectTextComplete(
    tester,
    find.text(badge),
    container: _card(),
    reason: 'branch badge text $reason',
  );
  await _expectReachable(
    tester,
    _button(badge),
    container: _card(),
    reason: 'branch badge $reason',
  );
  expect(tester.takeException(), isNull, reason: reason);
}

Future<void> _expectOverviewUsable(
  WidgetTester tester, {
  required String reason,
}) async {
  expect(tester.takeException(), isNull, reason: reason);
  await _expectTextComplete(
    tester,
    find.textContaining(_l10n.randomManager_categories),
    container: _overview(),
    reason: 'metrics $reason',
  );
  await _expectTextComplete(
    tester,
    find.text(_l10n.randomManager_addCategory),
    container: _overview(),
    reason: 'add category label $reason',
  );
  await _expectReachable(
    tester,
    find.byType(AddCategoryButton),
    container: _overview(),
    reason: 'add category $reason',
  );
  expect(tester.takeException(), isNull, reason: reason);
}

Widget _cardPage() => ListView(
  padding: const EdgeInsets.all(12),
  children: const [CategoryCard(category: _category, presetId: 'preset')],
);

void main() {
  for (final textScale in _textScales) {
    testWidgets('类别卡片在 320–1600 宽度、${textScale}x 文字下折叠与展开均不溢出且全部操作可达', (
      tester,
    ) async {
      for (final width in _widths) {
        await _pump(
          tester,
          size: Size(width, 900),
          textScale: textScale,
          body: _cardPage(),
        );
        await _expectCategoryCardUsable(
          tester,
          reason: 'width=$width scale=$textScale',
        );
      }
    });

    testWidgets('类别总览在 320–1600 宽度、${textScale}x 文字下计数与新增类别完整可达', (
      tester,
    ) async {
      for (final width in _widths) {
        await _pump(
          tester,
          size: Size(width, 900),
          textScale: textScale,
          body: const CategoryCardList(overviewHeader: SizedBox.shrink()),
        );
        await _expectOverviewUsable(
          tester,
          reason: 'width=$width scale=$textScale',
        );
      }
    });
  }

  testWidgets('类别卡片在短横屏、安全区与软键盘下折叠与展开的操作全部可滚到并点中', (tester) async {
    for (final textScale in _textScales) {
      await _pump(
        tester,
        size: _landscape,
        textScale: textScale,
        body: _cardPage(),
        padding: _landscapePadding,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardInset);
      await tester.pumpAndSettle();
      await _expectCategoryCardUsable(
        tester,
        reason: 'landscape keyboard scale=$textScale',
      );
    }
  });
}
