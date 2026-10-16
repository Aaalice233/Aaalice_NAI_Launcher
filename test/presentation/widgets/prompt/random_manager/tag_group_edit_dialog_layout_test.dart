import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_tag_group.dart';
import 'package:nai_launcher/data/models/prompt/weighted_tag.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/tag_group_card.dart';

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
const _tagCount = 40;

final _group = RandomTagGroup(
  id: 'group',
  name: 'Group',
  tags: [
    for (var i = 0; i < _tagCount; i++) WeightedTag(tag: 'tag_$i', weight: 1),
  ],
);

TestRandomPresetNotifier _presets({required bool isDefault}) =>
    TestRandomPresetNotifier.categories([
      RandomCategory(
        id: 'cat-hair',
        name: 'Hair',
        key: 'hairColor',
        groups: [_group],
      ),
    ], isDefault: isDefault);

final _l10n = lookupAppLocalizations(_locale);

final _diyTitles = [
  _l10n.randomManager_conditionalBranch,
  _l10n.randomManager_dependencyConfig,
  _l10n.randomManager_visibilityRules,
  _l10n.randomManager_timeCondition,
  _l10n.randomManager_postProcessRules,
];

Finder _formSurface() => find
    .byWidgetPredicate(
      (widget) =>
          widget.key == const ValueKey('adaptive-bottom-sheet') ||
          widget.key == const ValueKey('adaptive-centered-form'),
    )
    .last;

Finder _editorSurface() =>
    find.byKey(const ValueKey('tag-group-editor-surface'));

Finder _editorScrollable() => find
    .descendant(
      of: find.byKey(const ValueKey('tag-group-editor-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

// 标签栏随正文滚动时可能已滚出视口，查找时包含视口外的元素
Finder _tab(IconData icon) => find.descendant(
  of: find.byType(TabBar, skipOffstage: false),
  matching: find.byIcon(icon, skipOffstage: false),
  skipOffstage: false,
);

Finder _tagText(int index) => find.byKey(ValueKey('translated-tag-tag_$index'));

Finder _action(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate(
    (widget) => widget is TextButton || widget is FilledButton,
  ),
);

Finder _nameField() =>
    find.descendant(of: _editorSurface(), matching: find.byType(EditableText));

ScrollPosition _editorPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(_editorScrollable()).position;

// 随正文滚动时操作栏是末尾的 sliver，滚出视口也仍在树上
bool _actionsScrollWithContent() => find
    .descendant(
      of: find.byKey(const ValueKey('tag-group-editor-scroll')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data == _l10n.common_cancel ||
                widget.data == _l10n.common_close),
        skipOffstage: false,
      ),
      skipOffstage: false,
    )
    .evaluate()
    .isNotEmpty;

Future<void> _openEditor(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  bool readOnly = false,
  FakeViewPadding padding = FakeViewPadding.zero,
}) async {
  await pumpRandomManager(
    tester,
    size: size,
    textScale: textScale,
    padding: padding,
    locale: _locale,
    presets: () => _presets(isDefault: readOnly),
    home: Scaffold(
      body: TagGroupCard(
        tagGroup: _group,
        categoryId: 'cat-hair',
        categoryKey: 'hairColor',
        presetId: 'preset',
        isPresetDefault: readOnly,
      ),
    ),
  );
  await tester.tap(find.text(_group.name));
  await tester.pumpAndSettle();
  expect(_editorSurface(), findsOneWidget);
}

Future<void> _selectTab(WidgetTester tester, IconData icon) async {
  await tester.ensureVisible(_tab(icon));
  await tester.pumpAndSettle();
  await tester.tap(_tab(icon));
  await tester.pumpAndSettle();
}

// 每步实际滚动半个视口：矮视口里比控件还高的操作栏会在一步之内盖过目标；
// 横滑切页与纵向滚动同时竞争手势，拖动开头的触摸容差不计入滚动
Future<void> _scrollEditorUntilVisible(WidgetTester tester, Finder target) {
  return tester.scrollUntilVisible(
    target,
    tester.getSize(_editorScrollable()).height / 2 + kTouchSlop,
    scrollable: _editorScrollable(),
    maxScrolls: 200,
  );
}

Future<void> _setKeyboard(WidgetTester tester, double inset) async {
  tester.view.viewInsets = FakeViewPadding(bottom: inset);
  await tester.pumpAndSettle();
}

/// 滚到控件后断言它可见可点中、不越出容器左右边界，按钮类命中区达标
Future<void> _expectReachable(
  WidgetTester tester,
  Finder control, {
  required Finder container,
  required String reason,
  bool touchTarget = true,
}) async {
  // 操作栏随正文滚动时视口很矮，下方控件可能尚在视口外，先往下滚到它出现
  if (control.evaluate().isEmpty) {
    await _scrollEditorUntilVisible(tester, control);
  }
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

Future<void> _expectEditorUsable(
  WidgetTester tester, {
  required bool readOnly,
  required String reason,
}) async {
  expect(tester.takeException(), isNull, reason: 'open $reason');
  final editor = _editorSurface();

  for (final icon in const [
    Icons.tune_rounded,
    Icons.sell_outlined,
    Icons.account_tree_outlined,
  ]) {
    // 标签的命中区是含内边距的整块 InkWell，不是图标本身
    await _expectReachable(
      tester,
      find.ancestor(of: _tab(icon), matching: find.byType(InkWell)).first,
      container: editor,
      reason: 'tab $icon $reason',
    );
  }

  await _selectTab(tester, Icons.tune_rounded);
  // 只读时名称输入整体禁用，不接收点按，只要求露出且不越出编辑区
  if (readOnly) {
    await tester.ensureVisible(_nameField());
    await tester.pumpAndSettle();
    final name = tester.getRect(_nameField());
    final bounds = tester.getRect(editor);
    expect(
      name.overlaps(tester.getRect(_editorScrollable())) &&
          name.left >= bounds.left - 0.5 &&
          name.right <= bounds.right + 0.5,
      isTrue,
      reason: 'name $reason: $name',
    );
  } else {
    await _expectReachable(
      tester,
      _nameField(),
      container: editor,
      touchTarget: false,
      reason: 'name $reason',
    );
  }
  await _expectReachable(
    tester,
    find.descendant(of: editor, matching: find.byType(Slider)),
    container: editor,
    touchTarget: false,
    reason: 'probability $reason',
  );
  await _expectReachable(
    tester,
    find.byType(DropdownButton<SelectionMode>),
    container: editor,
    reason: 'selection mode $reason',
  );

  await _selectTab(tester, Icons.sell_outlined);
  await _expectReachable(
    tester,
    _tagText(0),
    container: editor,
    touchTarget: false,
    reason: 'first tag $reason',
  );
  // 标签列表按需构建，末项要滚到附近才存在
  await _scrollEditorUntilVisible(tester, _tagText(_tagCount - 1));
  await _expectReachable(
    tester,
    _tagText(_tagCount - 1),
    container: editor,
    touchTarget: false,
    reason: 'last tag $reason',
  );

  await _selectTab(tester, Icons.account_tree_outlined);
  if (readOnly) {
    for (final text in [
      _l10n.diyNotAvailableForDefault,
      _l10n.diyNotAvailableHint,
    ]) {
      final notice = find.text(text);
      await tester.ensureVisible(notice);
      await tester.pumpAndSettle();
      expectFullyVisible(tester, notice, reason: 'notice $reason');
    }
  } else {
    for (final title in _diyTitles) {
      await _expectReachable(
        tester,
        find.byKey(ValueKey('tag-group-diy-action-$title')),
        container: editor,
        reason: 'diy $title $reason',
      );
    }
    await _expectReachable(
      tester,
      find.descendant(of: editor, matching: find.byType(Slider)),
      container: editor,
      touchTarget: false,
      reason: 'emphasis $reason',
    );
  }

  final actions = readOnly
      ? [_l10n.common_close]
      : [_l10n.common_cancel, _l10n.common_save];
  for (final label in actions) {
    await _expectReachable(
      tester,
      _action(label),
      container: _formSurface(),
      reason: 'action $label $reason',
    );
  }
  expect(tester.takeException(), isNull, reason: reason);
}

void main() {
  for (final readOnly in [false, true]) {
    final variant = readOnly ? '默认预设只读' : '可编辑';
    for (final textScale in _textScales) {
      testWidgets('$variant词组编辑弹窗在 320–1600 宽度、${textScale}x 文字下各标签页字段与操作均可达', (
        tester,
      ) async {
        for (final width in _widths) {
          await _openEditor(
            tester,
            size: Size(width, 900),
            textScale: textScale,
            readOnly: readOnly,
          );
          expect(
            _actionsScrollWithContent(),
            isFalse,
            reason: '高度充足时操作栏固定 width=$width',
          );
          await _expectEditorUsable(
            tester,
            readOnly: readOnly,
            reason: 'width=$width scale=$textScale',
          );
        }
      });
    }

    testWidgets('$variant词组编辑弹窗在短横屏、安全区与软键盘下标签栏和操作随正文滚动且全部可达', (tester) async {
      for (final textScale in _textScales) {
        await _openEditor(
          tester,
          size: _landscape,
          textScale: textScale,
          readOnly: readOnly,
          padding: _landscapePadding,
        );
        await _setKeyboard(tester, _keyboardInset);
        final reason = 'landscape keyboard scale=$textScale';
        expect(_actionsScrollWithContent(), isTrue, reason: reason);
        final form = tester.getRect(_formSurface());
        expect(form.left, greaterThanOrEqualTo(_landscapePadding.left));
        expect(
          form.right,
          lessThanOrEqualTo(_landscape.width - _landscapePadding.right),
        );
        expect(
          form.bottom,
          lessThanOrEqualTo(_landscape.height - _keyboardInset),
          reason: reason,
        );
        await _expectEditorUsable(tester, readOnly: readOnly, reason: reason);
      }
    });
  }

  testWidgets('软键盘弹出使操作栏改为随正文滚动时，名称输入的文字、选区与焦点保持不变', (tester) async {
    // 短横屏即使不弹键盘也已随正文滚动，改用能固定操作栏的竖屏作为起点
    await _openEditor(tester, size: const Size(412, 700), textScale: 1);
    expect(_actionsScrollWithContent(), isFalse);

    await tester.tap(_nameField());
    await tester.pump();
    await tester.enterText(_nameField(), 'Renamed group');
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Renamed group',
        selection: TextSelection(baseOffset: 2, extentOffset: 7),
      ),
    );
    await tester.pump();

    for (final inset in [320.0, 0.0]) {
      await _setKeyboard(tester, inset);
      final reason = 'keyboard=$inset';
      expect(_actionsScrollWithContent(), inset > 0, reason: reason);
      final field = tester.widget<EditableText>(_nameField());
      expect(field.focusNode.hasFocus, isTrue, reason: reason);
      expect(field.controller.text, 'Renamed group', reason: reason);
      expect(
        field.controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 7),
        reason: reason,
      );
      expect(_nameField().hitTestable(), findsOneWidget, reason: reason);
      expect(tester.takeException(), isNull, reason: reason);
    }
  });

  testWidgets('标签栏与操作栏按同一条规则一起固定或一起随正文滚动', (tester) async {
    await _openEditor(tester, size: const Size(412, 700), textScale: 1);
    await _selectTab(tester, Icons.sell_outlined);

    Future<bool> tabBarPinnedAfterScroll(double keyboardInset) async {
      await _setKeyboard(tester, keyboardInset);
      _editorPosition(tester).jumpTo(200);
      await tester.pumpAndSettle();
      final offset =
          tester.getRect(find.byType(TabBar, skipOffstage: false)).top -
          tester.getRect(_editorScrollable()).top;
      return offset > -0.5;
    }

    var sawPinned = false;
    var sawScrolling = false;
    for (var inset = 0.0; inset <= 360; inset += 8) {
      final pinned = await tabBarPinnedAfterScroll(inset);
      expect(
        _actionsScrollWithContent(),
        !pinned,
        reason: '键盘占 $inset 时标签栏${pinned ? '固定' : '滚走'}，操作栏应一致',
      );
      if (pinned) sawPinned = true;
      if (!pinned) sawScrolling = true;
    }
    expect(sawPinned && sawScrolling, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('操作栏在固定与随正文滚动之间切换时标签列表的滚动位置不变，切换标签页回到开头', (tester) async {
    await _openEditor(tester, size: const Size(412, 700), textScale: 1);
    await _selectTab(tester, Icons.sell_outlined);
    await tester.scrollUntilVisible(
      _tagText(20),
      200,
      scrollable: _editorScrollable(),
    );
    await tester.pumpAndSettle();
    expect(_actionsScrollWithContent(), isFalse);
    final pixels = _editorPosition(tester).pixels;
    expect(pixels, greaterThan(0));
    double anchorOffset() =>
        tester.getRect(_tagText(20)).top -
        tester.getRect(_editorScrollable()).top;
    final offset = anchorOffset();

    await _setKeyboard(tester, 320);
    expect(_actionsScrollWithContent(), isTrue);
    expect(_editorPosition(tester).pixels, pixels);
    expect(anchorOffset(), moreOrLessEquals(offset, epsilon: 0.5));

    await _setKeyboard(tester, 0);
    expect(_actionsScrollWithContent(), isFalse);
    expect(_editorPosition(tester).pixels, pixels);
    expect(anchorOffset(), moreOrLessEquals(offset, epsilon: 0.5));

    await _selectTab(tester, Icons.account_tree_outlined);
    expect(_editorPosition(tester).pixels, 0);
    expect(tester.takeException(), isNull);
  });

  group('横滑切换标签页', () {
    int tabIndex(WidgetTester tester) => tester
        .widget<TabBar>(find.byType(TabBar, skipOffstage: false))
        .controller!
        .index;

    Future<void> flingOn(
      WidgetTester tester,
      Finder target,
      Offset offset, {
      PointerDeviceKind deviceKind = PointerDeviceKind.touch,
    }) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.flingFrom(
        tester.getCenter(target),
        offset,
        1000,
        deviceKind: deviceKind,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('正文上左甩切到下一页、右甩回到上一页，首页不再越界', (tester) async {
      await _openEditor(tester, size: const Size(412, 700), textScale: 1);
      await _selectTab(tester, Icons.sell_outlined);
      expect(tabIndex(tester), 1);

      await flingOn(tester, _tagText(2), const Offset(-200, 0));
      expect(tabIndex(tester), 2);
      await flingOn(
        tester,
        find.byKey(ValueKey('tag-group-diy-action-${_diyTitles.first}')),
        const Offset(200, 0),
      );
      expect(tabIndex(tester), 1);
      await flingOn(tester, _tagText(2), const Offset(200, 0));
      expect(tabIndex(tester), 0);
      // 第一页再向右甩不越界
      await flingOn(
        tester,
        find.text(_l10n.randomManager_selectionMode),
        const Offset(200, 0),
      );
      expect(tabIndex(tester), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('慢速拖过正文一半宽度才切页，操作栏随正文滚动时同样生效', (tester) async {
      await _openEditor(tester, size: _landscape, textScale: 1);
      await _setKeyboard(tester, _keyboardInset);
      expect(_actionsScrollWithContent(), isTrue);
      await _selectTab(tester, Icons.sell_outlined);
      final width = tester.getSize(_editorScrollable()).width;

      await _scrollEditorUntilVisible(tester, _tagText(0));
      await tester.ensureVisible(_tagText(0));
      await tester.pumpAndSettle();
      await tester.timedDrag(
        _tagText(0),
        Offset(-width * 0.3, 0),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(tabIndex(tester), 1, reason: '不到一半宽度的慢速拖动不切页');

      await tester.ensureVisible(_tagText(0));
      await tester.pumpAndSettle();
      await tester.timedDrag(
        _tagText(0),
        Offset(-width * 0.6, 0),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(tabIndex(tester), 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('纵向滑动只滚动正文，不切换标签页', (tester) async {
      await _openEditor(tester, size: const Size(412, 700), textScale: 1);
      await _selectTab(tester, Icons.sell_outlined);
      await flingOn(tester, _tagText(4), const Offset(0, -300));
      expect(tabIndex(tester), 1);
      expect(_editorPosition(tester).pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('从滑块、名称输入框或标签栏开始的横拖不切换标签页', (tester) async {
      await _openEditor(tester, size: const Size(412, 700), textScale: 1);
      final probability = find.descendant(
        of: _editorSurface(),
        matching: find.byType(Slider),
      );
      final before = tester.widget<Slider>(probability).value;
      await flingOn(tester, probability, const Offset(-200, 0));
      expect(tabIndex(tester), 0, reason: '滑块');
      expect(tester.widget<Slider>(probability).value, lessThan(before));

      await flingOn(tester, _nameField(), const Offset(-200, 0));
      expect(tabIndex(tester), 0, reason: '名称输入框');

      final tabBar = tester.getRect(find.byType(TabBar));
      await tester.flingFrom(
        Offset(tabBar.right - 8, tabBar.center.dy),
        const Offset(-200, 0),
        1000,
      );
      await tester.pumpAndSettle();
      expect(tabIndex(tester), 0, reason: '标签栏');
      expect(tester.takeException(), isNull);
    });

    testWidgets('鼠标拖动不切换标签页，只有滚动配置允许拖动的设备能切页', (tester) async {
      await _openEditor(tester, size: const Size(1180, 900), textScale: 1);
      await _selectTab(tester, Icons.sell_outlined);
      await flingOn(
        tester,
        _tagText(2),
        const Offset(-300, 0),
        deviceKind: PointerDeviceKind.mouse,
      );
      expect(tabIndex(tester), 1);
      expect(tester.takeException(), isNull);
    });
  });
}
