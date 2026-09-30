import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/conditional_branch.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/tag_library.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_slider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/category_card.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/category_card_list.dart';

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

class _FixedPresetNotifier extends RandomPresetNotifier {
  @override
  RandomPresetState build() => const RandomPresetState(
    presets: [
      RandomPreset(
        id: 'preset',
        name: 'Preset',
        categories: [
          _category,
          RandomCategory(id: 'cat-outfit', name: 'Outfit', key: 'custom2'),
        ],
      ),
    ],
    selectedPresetId: 'preset',
  );
}

class _EmptyLibraryNotifier extends TagLibraryNotifier {
  @override
  TagLibraryState build() => TagLibraryState(
    library: TagLibrary(
      id: 'catalog',
      name: 'Catalog',
      lastUpdated: DateTime.utc(2026),
      source: TagLibrarySource.catalog,
      dataVersion: 'test',
      sourceUrl: 'https://example.com/catalog.csv',
      sourceCommit: 'test',
      sourceLicense: 'Unlicense',
      sourceVersionDate: DateTime.utc(2026),
      sourceCatalogTagCount: 1,
      sourceCatalogAliasCount: 0,
      categories: const {},
    ),
  );
}

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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.reset);

  // 同一用例内逐个尺寸重建，展开状态不能沿用上一个尺寸
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomPresetNotifierProvider.overrideWith(_FixedPresetNotifier.new),
        tagLibraryNotifierProvider.overrideWith(_EmptyLibraryNotifier.new),
      ],
      child: MaterialApp(
        locale: _locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => InteractionPolicyScope(
          initialPolicy: InteractionPolicy.touchFirst,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        home: Scaffold(body: SafeArea(child: body)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 滚到控件后断言露出的部分在容器左右边界内且能被点中，按钮类命中区达标
///
/// 横向滚动条里的分段按钮在压力字体下可能比视口还宽，只要求露出的部分不越出容器
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
  final rect = tester.getRect(control);
  var visible = rect;
  final scrollables = find.ancestor(
    of: control,
    matching: find.byType(Scrollable),
  );
  for (var i = 0; i < scrollables.evaluate().length; i++) {
    visible = visible.intersect(tester.getRect(scrollables.at(i)));
  }
  expect(visible.width > 0 && visible.height > 0, isTrue, reason: reason);
  final bounds = tester.getRect(container);
  expect(visible.left, greaterThanOrEqualTo(bounds.left - 0.5), reason: reason);
  expect(visible.right, lessThanOrEqualTo(bounds.right + 0.5), reason: reason);

  final target = tester.renderObject(control);
  expect(
    tester
        .hitTestOnBinding(visible.center)
        .path
        .any((entry) => entry.target == target),
    isTrue,
    reason: '可点中 $reason',
  );
  if (touchTarget) {
    expect(
      rect.shortestSide,
      greaterThanOrEqualTo(_minTouchExtent),
      reason: '命中区 $reason',
    );
  }
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
    find
        .ancestor(
          of: find.text(_l10n.randomManager_addCategory),
          matching: find.byType(AnimatedContainer),
        )
        .first,
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
