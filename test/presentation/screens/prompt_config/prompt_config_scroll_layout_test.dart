import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/default_categories.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/tag_library.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_group_sync_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_provider.dart';
import 'package:nai_launcher/presentation/screens/prompt_config/prompt_config_screen.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/category_card.dart';

import '../../../helpers/adaptive_panel_expectations.dart';
import '../../../helpers/reachability_expectations.dart';
import '../../../helpers/viewport_scenarios.dart';

const _landscape = Size(740, 360);
const _portrait = Size(412, 900);
const _keyboardInset = 160.0;

final _preset = RandomPreset(
  id: 'custom',
  name: '测试预设',
  categories: DefaultCategories.createDefault(),
);

class _Presets extends RandomPresetNotifier {
  @override
  RandomPresetState build() =>
      RandomPresetState(presets: [_preset], selectedPresetId: _preset.id);
}

class _Library extends TagLibraryNotifier {
  @override
  TagLibraryState build() => TagLibraryState(
    library: TagLibrary(
      id: 'test-catalog',
      name: 'Test catalog',
      lastUpdated: DateTime.utc(2026),
      source: TagLibrarySource.catalog,
      dataVersion: 'test-v1',
      categories: const {},
    ),
  );
}

class _FailedLibrary extends TagLibraryNotifier {
  @override
  TagLibraryState build() => TagLibraryState(
    error: List.filled(12, 'catalog database could not be opened').join(' '),
  );
}

class _IdleSync extends TagGroupSyncNotifier {
  @override
  TagGroupSyncState build() => const TagGroupSyncState();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  String locale = 'zh',
  FakeViewPadding padding = FakeViewPadding.zero,
  double keyboard = 0,
  TagLibraryNotifier Function() library = _Library.new,
}) async {
  applyViewport(tester, (size: size, keyboard: keyboard, padding: padding));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        randomPresetNotifierProvider.overrideWith(_Presets.new),
        tagLibraryNotifierProvider.overrideWith(library),
        tagGroupSyncNotifierProvider.overrideWith(_IdleSync.new),
      ],
      child: localizedTestApp(
        locale: Locale(locale),
        textScale: textScale,
        interactionPolicy: InteractionPolicy.touchFirst,
        home: const PromptConfigScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _resize(
  WidgetTester tester, {
  Size? size,
  double? keyboard,
}) async {
  if (size != null) tester.view.physicalSize = size;
  if (keyboard != null) {
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(PromptConfigScreen)))!;

Finder _key(String key) => find.byKey(ValueKey(key), skipOffstage: false);

Finder _searchField() => find.descendant(
  of: _key('random-manager-overview-card'),
  matching: find.byType(TextField, skipOffstage: false),
);

Finder _categoryScrollable() => find
    .descendant(
      of: _key('random-manager-category-scroll'),
      matching: find.byType(Scrollable, skipOffstage: false),
    )
    .first;

ScrollPosition _categoryPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_categoryScrollable()).position;

Finder _categoryToggle(RandomCategory category) => find
    .descendant(
      of: _key('random-manager-category-${category.id}'),
      matching: find.byType(InkWell, skipOffstage: false),
    )
    .first;

bool _isExpanded(WidgetTester tester, RandomCategory category) =>
    tester
        .widget<AnimatedRotation>(
          find.descendant(
            of: _key('random-manager-category-${category.id}'),
            matching: find.byType(AnimatedRotation, skipOffstage: false),
          ),
        )
        .turns ==
    0.5;

Future<void> _expectChromeUsable(WidgetTester tester, String reason) async {
  for (final key in [
    'random-manager-more-actions',
    'random-manager-preset-selector',
  ]) {
    await revealOnScreen(tester, _key(key));
    expectReachable(tester, _key(key), reason: '$reason $key');
  }
}

Future<void> _expectRecipeUsable(WidgetTester tester, String reason) async {
  await revealOnScreen(tester, _searchField());
  expectReachable(tester, _searchField(), reason: '$reason 搜索框');
  final addCategory = find.byType(AddCategoryButton, skipOffstage: false);
  await revealOnScreen(tester, addCategory);
  expectReachable(tester, addCategory, reason: '$reason 新增类别');
  for (final category in [_preset.categories.first, _preset.categories.last]) {
    await scrollUntilBuilt(
      tester,
      _key('random-manager-category-${category.id}'),
      _categoryScrollable(),
    );
    await revealOnScreen(tester, _categoryToggle(category));
    expectReachable(
      tester,
      _categoryToggle(category),
      reason: '$reason 类别 ${category.key}',
    );
  }
}

Future<void> _expectPreviewUsable(WidgetTester tester, String reason) async {
  final generate = _key('random-manager-generate-sample');
  await revealOnScreen(tester, generate);
  expectReachable(tester, generate, reason: '$reason 生成样例');
}

Future<void> _expectAlgorithmUsable(WidgetTester tester, String reason) async {
  final globalSettings = buttonLabeled(
    _l10n(tester).randomManager_globalPeopleSettings,
  );
  await revealOnScreen(tester, globalSettings);
  expectReachable(tester, globalSettings, reason: '$reason 全局人数设置');
}

Future<void> _selectSection(WidgetTester tester, String label) async {
  final segment = find
      .ancestor(
        of: find.descendant(
          of: _key('random-manager-compact-sections'),
          matching: find.text(label, skipOffstage: false),
        ),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
          skipOffstage: false,
        ),
      )
      .first;
  await revealOnScreen(tester, segment);
  expectReachable(tester, segment, reason: '分区 $label');
  await tapVisiblePart(tester, segment);
}

Future<void> _expectWorkspaceUsable(
  WidgetTester tester, {
  required String reason,
}) async {
  expect(tester.takeException(), isNull, reason: reason);
  await _expectChromeUsable(tester, reason);
  await _expectRecipeUsable(tester, reason);
  if (_key('random-manager-compact-sections').evaluate().isEmpty) {
    await _expectPreviewUsable(tester, reason);
    await _expectAlgorithmUsable(tester, reason);
  } else {
    final l10n = _l10n(tester);
    await _selectSection(tester, l10n.randomManager_previewGeneration);
    await _expectChromeUsable(tester, '$reason 预览分区');
    await _expectPreviewUsable(tester, reason);
    await _selectSection(tester, l10n.randomManager_inspectorTitle);
    await _expectChromeUsable(tester, '$reason 算法分区');
    await _expectAlgorithmUsable(tester, reason);
    await _selectSection(tester, l10n.randomManager_recipeTitle);
  }
  expect(tester.takeException(), isNull, reason: reason);
}

FocusNode _searchFocus(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: _searchField(),
        matching: find.byType(EditableText, skipOffstage: false),
      ),
    )
    .focusNode;

Future<void> _pressFind(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  for (final (size, textScale) in [
    (const Size(320, 900), 1.0),
    (const Size(840, 900), 1.0),
    (const Size(1600, 900), 3.0),
    (_landscape, 1.0),
  ]) {
    testWidgets('紧凑排布 $size、${textScale}x 在预览与算法分区按搜索快捷键时切回配方分区并聚焦搜索框', (
      tester,
    ) async {
      await _pumpScreen(tester, size: size, textScale: textScale);
      final l10n = _l10n(tester);
      expect(_key('random-manager-compact-sections'), findsOneWidget);
      for (final (section, modifier) in [
        (l10n.randomManager_previewGeneration, LogicalKeyboardKey.controlLeft),
        (l10n.randomManager_inspectorTitle, LogicalKeyboardKey.metaLeft),
      ]) {
        await _selectSection(tester, section);
        expect(_searchFocus(tester).hasFocus, isFalse, reason: section);

        await _pressFind(tester, modifier);
        expect(_searchFocus(tester).hasFocus, isTrue, reason: section);
        expect(
          _key('random-manager-generate-sample').hitTestable(),
          findsNothing,
          reason: '$section 已切回配方分区',
        );
        await revealOnScreen(tester, _searchField());
        expectReachable(tester, _searchField(), reason: '$section 搜索框');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('宽屏排布按搜索快捷键只聚焦搜索框，不改动紧凑排布记住的分区', (tester) async {
    await _pumpScreen(tester, size: const Size(840, 900));
    final l10n = _l10n(tester);
    await _selectSection(tester, l10n.randomManager_previewGeneration);
    await _resize(tester, size: const Size(1180, 900));
    expect(_key('random-manager-compact-sections'), findsNothing);

    await _pressFind(tester, LogicalKeyboardKey.controlLeft);
    expect(_searchFocus(tester).hasFocus, isTrue);

    await _resize(tester, size: const Size(840, 900));
    final generate = _key('random-manager-generate-sample');
    await revealOnScreen(tester, generate);
    expectReachable(tester, generate, reason: '仍停在预览分区');
    expect(tester.takeException(), isNull);
  });

  for (final locale in ['zh', 'en']) {
    for (final textScale in [1.0, 3.0]) {
      testWidgets('随机词库在 320–1600 宽度、$locale、${textScale}x 文字下无溢出且各分区操作可达', (
        tester,
      ) async {
        for (final width in responsiveWidths) {
          await _pumpScreen(
            tester,
            size: Size(width, 900),
            textScale: textScale,
            locale: locale,
          );
          await _expectWorkspaceUsable(
            tester,
            reason: 'width=$width $locale ${textScale}x',
          );
        }
      });

      testWidgets('随机词库在手机横屏、$locale、${textScale}x 文字下有无键盘与安全区都不溢出且操作可达', (
        tester,
      ) async {
        for (final keyboard in [0.0, _keyboardInset]) {
          for (final padding in [FakeViewPadding.zero, landscapePadding]) {
            await _pumpScreen(
              tester,
              size: _landscape,
              textScale: textScale,
              locale: locale,
              padding: padding,
              keyboard: keyboard,
            );
            await _expectWorkspaceUsable(
              tester,
              reason:
                  'landscape keyboard=$keyboard padding=${padding.left} '
                  '$locale ${textScale}x',
            );
          }
        }
      });
    }
  }

  testWidgets('竖屏高度充足时总览与标题栏固定在列表上方，横屏时随列表一起滚动', (tester) async {
    await _pumpScreen(tester, size: _portrait);
    expect(pinnedHeaderSliverOf(tester, _searchField()).isPinned, isTrue);
    final searchTop = tester.getTopLeft(_searchField()).dy;
    final moreTop = tester.getTopLeft(_key('random-manager-more-actions')).dy;
    await tester.drag(
      _categoryToggle(_preset.categories[2]),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(_categoryPosition(tester).pixels, greaterThan(0));
    expect(tester.getTopLeft(_searchField()).dy, searchTop);
    expect(tester.getTopLeft(_key('random-manager-more-actions')).dy, moreTop);
    expectReachable(tester, _searchField(), reason: '固定的搜索框');

    await _resize(tester, size: _landscape);
    expect(pinnedHeaderSliverOf(tester, _searchField()).isPinned, isFalse);
    _categoryPosition(tester).jumpTo(0);
    await tester.pumpAndSettle();
    final landscapeSearchTop = tester.getTopLeft(_searchField()).dy;
    await tester.drag(
      _categoryScrollable(),
      const Offset(0, -120),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(_searchField()).dy,
      lessThan(landscapeSearchTop),
      reason: '横屏高度不足时搜索框随列表滚动，把视口让给类别',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索框输入后过滤类别，清空按钮恢复全部类别', (tester) async {
    await _pumpScreen(tester, size: _portrait);
    final first = _key(
      'random-manager-category-${_preset.categories.first.id}',
    );
    expect(first, findsOneWidget);

    await tester.enterText(_searchField(), 'no-such-category');
    await tester.pumpAndSettle();
    expect(first, findsNothing);

    final clear = find.ancestor(
      of: find.descendant(
        of: _key('random-manager-overview-card'),
        matching: find.byIcon(Icons.close),
      ),
      matching: find.byType(IconButton),
    );
    expectReachable(tester, clear, reason: '清空按钮', minExtent: 44);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(_searchField()).controller!.text, isEmpty);
    expect(first, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('软键盘弹出使总览改为随列表滚动时，搜索内容、焦点与类别展开状态保留', (tester) async {
    await _pumpScreen(tester, size: _portrait);
    final target = _preset.categories.first;
    await tester.tap(_categoryToggle(target));
    await tester.pumpAndSettle();
    expect(_isExpanded(tester, target), isTrue);

    await tester.tap(_searchField());
    await tester.enterText(_searchField(), target.key);
    await tester.pumpAndSettle();
    final focus = tester
        .widget<EditableText>(
          find.descendant(
            of: _searchField(),
            matching: find.byType(EditableText, skipOffstage: false),
          ),
        )
        .focusNode;
    expect(focus.hasFocus, isTrue);
    expect(pinnedHeaderSliverOf(tester, _searchField()).isPinned, isTrue);

    await _resize(tester, keyboard: 500);
    expect(pinnedHeaderSliverOf(tester, _searchField()).isPinned, isFalse);
    expect(focus.hasFocus, isTrue);
    expect(
      tester.widget<TextField>(_searchField()).controller!.text,
      target.key,
    );
    expect(_isExpanded(tester, target), isTrue);
    expectReachable(tester, _searchField(), reason: '键盘弹出后仍可见的搜索框');

    await _resize(tester, keyboard: 0);
    expect(pinnedHeaderSliverOf(tester, _searchField()).isPinned, isTrue);
    expect(focus.hasFocus, isTrue);
    expect(_isExpanded(tester, target), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手机旋转为横屏时类别展开状态与列表滚动位置保留', (tester) async {
    await _pumpScreen(tester, size: _portrait);
    final target = _preset.categories[1];
    await tester.tap(_categoryToggle(target));
    await tester.pumpAndSettle();
    _categoryPosition(tester).jumpTo(160);
    await tester.pumpAndSettle();

    await _resize(tester, size: _landscape);
    expect(_categoryPosition(tester).pixels, 160);
    expect(_isExpanded(tester, target), isTrue);

    await _resize(tester, size: _portrait);
    expect(_categoryPosition(tester).pixels, 160);
    expect(_isExpanded(tester, target), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏与紧凑排布互换时搜索内容、焦点、展开状态与滚动位置保留', (tester) async {
    await _pumpScreen(tester, size: const Size(1180, 900));
    final target = _preset.categories.first;
    await tester.tap(_searchField());
    await tester.enterText(_searchField(), 'o');
    await tester.pumpAndSettle();
    await tester.tap(_categoryToggle(target));
    await tester.pumpAndSettle();
    _categoryPosition(tester).jumpTo(90);
    await tester.pumpAndSettle();
    final focus = tester
        .widget<EditableText>(
          find.descendant(
            of: _searchField(),
            matching: find.byType(EditableText, skipOffstage: false),
          ),
        )
        .focusNode;

    for (final size in [const Size(840, 900), const Size(1180, 900)]) {
      await _resize(tester, size: size);
      expect(tester.widget<TextField>(_searchField()).controller!.text, 'o');
      expect(focus.hasFocus, isTrue, reason: '$size');
      expect(_isExpanded(tester, target), isTrue, reason: '$size');
      expect(_categoryPosition(tester).pixels, 90, reason: '$size');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载失败提示在横屏键盘与放大文字下随标题栏滚动，重试可达', (tester) async {
    await _pumpScreen(
      tester,
      size: _landscape,
      textScale: 3,
      keyboard: _keyboardInset,
      library: _FailedLibrary.new,
    );
    expect(tester.takeException(), isNull);
    await _expectChromeUsable(tester, '加载失败');
    final retry = buttonLabeled(_l10n(tester).common_retry);
    await revealOnScreen(tester, retry);
    expectReachable(tester, retry, reason: '重试');
  });
}
