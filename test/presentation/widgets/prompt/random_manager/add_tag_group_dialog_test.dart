import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/adaptive_dialog_frame.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/add_tag_group_dialog.dart';

import '../../../../helpers/flutter_error_collector.dart';
import '../../../../helpers/reachability_expectations.dart';

const _landscapePadding = FakeViewPadding(left: 32, right: 48);

final _viewports = <({Size size, double keyboard, FakeViewPadding padding})>[
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0])
    (size: Size(width, 900), keyboard: 0, padding: FakeViewPadding.zero),
  (size: const Size(740, 360), keyboard: 0, padding: FakeViewPadding.zero),
  (size: const Size(740, 360), keyboard: 160, padding: _landscapePadding),
];

Finder _formScroll() => find.byKey(
  const ValueKey('add-tag-group-form-scroll'),
  skipOffstage: false,
);

Finder _sourceTab(String label) => find.ancestor(
  of: find.text(label, skipOffstage: false),
  matching: find.byType(Tab, skipOffstage: false),
);

Finder _tile(String label) => find
    .ancestor(
      of: find.text(label, skipOffstage: false),
      matching: find.byType(AnimatedContainer, skipOffstage: false),
    )
    .first;

Finder _button(String label) => find.ancestor(
  of: find.text(label, skipOffstage: false),
  matching: find.byWidgetPredicate(
    (widget) => widget is ButtonStyleButton,
    skipOffstage: false,
  ),
);

int _sourceIndex(WidgetTester tester) => tester
    .widget<TabBar>(find.byType(TabBar, skipOffstage: false))
    .controller!
    .index;

// 文本框自带的 Scrollable 只滚动自身文字，不算表单的主滚动容器
int _verticalFormScrollables(WidgetTester tester) => find
    .descendant(
      of: find.byType(AddTagGroupDialog),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        skipOffstage: false,
      ),
    )
    .evaluate()
    .where(
      (element) =>
          element.findAncestorWidgetOfExactType<EditableText>() == null,
    )
    .length;

Future<void> _selectSource(WidgetTester tester, String label) async {
  await revealOnScreen(tester, _sourceTab(label));
  await tester.tap(_sourceTab(label));
  await tester.pumpAndSettle();
}

Future<void> _expectReachableInForm(
  WidgetTester tester,
  Finder target,
  String reason,
) async {
  await scrollUntilBuilt(tester, target, _formScroll());
  await revealOnScreen(tester, target);
  expectReachable(tester, target, reason: reason);
}

void main() {
  const category = RandomCategory(
    id: 'test-category',
    name: 'Test category',
    key: 'testCategory',
  );

  for (final textScale in [1.0, 3.0]) {
    testWidgets('各宽度、短横屏与键盘下只有一个纵向主滚动容器，${textScale}x 时三个来源的条目与操作都随表单滚动可达', (
      tester,
    ) async {
      for (final viewport in _viewports) {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = viewport.padding;
        tester.view.viewInsets = FakeViewPadding(bottom: viewport.keyboard);
        addTearDown(tester.view.reset);
        await _pumpHost(
          tester,
          category: category,
          mediaQuery: (data) =>
              data.copyWith(textScaler: TextScaler.linear(textScale)),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final reason =
            '${viewport.size} keyboard=${viewport.keyboard} ${textScale}x';
        expect(tester.takeException(), isNull, reason: reason);

        for (final (source, targets) in [
          (
            'Custom',
            [
              find.byType(TextFormField, skipOffstage: false).first,
              find.byType(TextFormField, skipOffstage: false).last,
            ],
          ),
          ('Tag Group', [_tile('Hair Color'), _tile('Body Types')]),
          ('Danbooru Pool', [_tile('Genshin Characters'), _tile('Azur Lane')]),
        ]) {
          await _selectSource(tester, source);
          expect(
            _verticalFormScrollables(tester),
            1,
            reason: '$reason $source 不应再嵌套独立滚动的列表',
          );
          for (final (index, target) in targets.indexed) {
            await _expectReachableInForm(
              tester,
              target,
              '$reason $source #$index',
            );
          }
          for (final action in ['Cancel', 'Add']) {
            await _expectReachableInForm(
              tester,
              _button(action),
              '$reason $source $action',
            );
          }
        }
        expect(tester.takeException(), isNull, reason: reason);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('在来源内容上横滑切换来源且方向与原 TabBarView 一致，纵滑与从标签栏开始的横拖不切换', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpHost(tester, category: category);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    Future<void> flingOn(Finder target, Offset offset) async {
      await revealOnScreen(tester, target);
      await tester.flingFrom(tester.getCenter(target), offset, 1000);
      await tester.pumpAndSettle();
    }

    await flingOn(find.text('Tag List'), const Offset(-200, 0));
    expect(_sourceIndex(tester), 1);
    await flingOn(_tile('Hair Color'), const Offset(-200, 0));
    expect(_sourceIndex(tester), 2);
    await flingOn(_tile('Arknights'), const Offset(-200, 0));
    expect(_sourceIndex(tester), 2, reason: '最后一个来源再向左甩不越界');
    await flingOn(_tile('Arknights'), const Offset(200, 0));
    expect(_sourceIndex(tester), 1);

    final position = tester
        .state<ScrollableState>(
          find
              .descendant(of: _formScroll(), matching: find.byType(Scrollable))
              .first,
        )
        .position;
    final before = position.pixels;
    await flingOn(_tile('Posture'), const Offset(0, -300));
    expect(_sourceIndex(tester), 1);
    expect(position.pixels, greaterThan(before));

    await revealOnScreen(tester, find.byType(TabBar));
    final tabBar = tester.getRect(find.byType(TabBar));
    await tester.flingFrom(
      Offset(tabBar.right - 8, tabBar.center.dy),
      const Offset(-200, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(_sourceIndex(tester), 1, reason: '标签栏在原 TabBarView 之外');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320dp 3x text with IME and SafeArea keeps the form and actions scrollable',
    (tester) async {
      final errors = FlutterErrorCollector.install(tester);
      addTearDown(errors.restoreAndAssertNoErrors);
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(960, 1704);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpHost(
        tester,
        category: category,
        mediaQuery: (data) => data.copyWith(
          padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
          viewPadding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
          viewInsets: const EdgeInsets.only(bottom: 240),
          textScaler: const TextScaler.linear(3),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final surface = find.byKey(const ValueKey('adaptive-bottom-sheet'));
      expect(surface, findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AdaptiveDialogFrame), findsNothing);

      final surfaceRect = tester.getRect(surface);
      expect(surfaceRect.left, greaterThanOrEqualTo(12));
      expect(surfaceRect.top, greaterThanOrEqualTo(24));
      expect(surfaceRect.right, lessThanOrEqualTo(320 - 12));
      expect(surfaceRect.bottom, lessThanOrEqualTo(568 - 240));

      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isTrue,
      );

      final formScroll = find.byKey(
        const ValueKey('add-tag-group-form-scroll'),
      );
      final scrollableFinder = find
          .descendant(of: formScroll, matching: find.byType(Scrollable))
          .first;
      final scrollable = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));

      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final cancel = find.text('Cancel');
      expect(cancel, findsOneWidget);
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      expect(cancel.hitTestable(), findsOneWidget);
      errors.expectNoErrors(reason: 'compact tag group form');
    },
  );

  testWidgets(
    'wide presentation stays bounded and preserves all source modes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await _pumpHost(tester, category: category);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final surface = find.byKey(const ValueKey('adaptive-centered-form'));
      expect(surface, findsOneWidget);
      final surfaceRect = tester.getRect(surface);
      expect(surfaceRect.width, lessThanOrEqualTo(580));
      expect(surfaceRect.center.dx, moreOrLessEquals(600));
      expect(surfaceRect.height, lessThan(900 - 32), reason: '内容不长时面板按内容收紧');
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Tag Group'), findsOneWidget);
      expect(find.text('Danbooru Pool'), findsOneWidget);
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
      expect(find.byType(TextFormField), findsNWidgets(2));
      final formScrollable = find
          .descendant(
            of: find.byKey(const ValueKey('add-tag-group-form-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Cancel'),
        200,
        scrollable: formScrollable,
      );
      expect(find.text('Cancel'), findsOneWidget);
      final addButton = find.ancestor(
        of: find.text('Add'),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(addButton).onPressed, isNull);
      await tester.scrollUntilVisible(
        find.byType(TextFormField).first,
        -200,
        scrollable: formScrollable,
      );
      await tester.enterText(find.byType(TextFormField).first, 'My group');
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Add'),
        200,
        scrollable: formScrollable,
      );
      expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('来源标签栏字号取自主题的 labelMedium，选中与未选中一致', (tester) async {
    final base = ThemeData();
    final theme = base.copyWith(
      textTheme: base.textTheme.copyWith(
        labelMedium: base.textTheme.labelMedium!.copyWith(fontSize: 17),
      ),
    );
    tester.view.physicalSize = const Size(1180, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpHost(tester, category: category, theme: theme);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    for (final label in ['Custom', 'Tag Group', 'Danbooru Pool']) {
      final style = tester
          .renderObject<RenderParagraph>(
            find.descendant(of: _sourceTab(label), matching: find.text(label)),
          )
          .text
          .style;
      expect(style?.fontSize, 17, reason: label);
      expect(style?.fontWeight, FontWeight.w600, reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  group('Danbooru 条目', () {
    const sources = [
      ('Tag Group', 'Hair Color'),
      ('Danbooru Pool', 'Arknights'),
    ];

    for (final textScale in [1.0, 3.0]) {
      testWidgets('触屏下 $textScale x 各宽度条目按可聚焦按钮朗读，外部打开入口无需悬停即可点按', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
          await _pumpDanbooruHost(
            tester,
            category: category,
            size: Size(width, 900),
            textScale: textScale,
            interactionPolicy: InteractionPolicy.touchFirst,
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          for (final (source, label) in sources) {
            final reason = 'width=$width ${textScale}x $source';
            await _selectSource(tester, source);
            await _expectReachableInForm(tester, _tile(label), reason);

            final node = _tileSemantics(label);
            expect(node, findsOne, reason: '$reason 条目按按钮朗读');
            final flags = node.evaluate().single.flagsCollection;
            expect(flags.isFocused, isNot(Tristate.none), reason: reason);
            expect(flags.isSelected, Tristate.isFalse, reason: reason);

            await revealOnScreen(tester, _openInDanbooru(label));
            expectReachable(
              tester,
              _openInDanbooru(label),
              reason: '$reason 未选中且未悬停时外部打开入口可点按',
            );
          }
          expect(tester.takeException(), isNull);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        semantics.dispose();
      });
    }

    for (final (source, label) in sources) {
      testWidgets('指针下 $source 条目悬停或焦点落在本行时才显示外部打开入口且行高不变，键盘可选中', (
        tester,
      ) async {
        // 整个用例只用一个鼠标设备点击，触摸会让交互策略转为触屏
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        addTearDown(mouse.removePointer);
        Future<void> click(Finder target) async {
          await revealOnScreen(tester, target);
          final center = tester.getCenter(target);
          await mouse.moveTo(center);
          await mouse.down(center);
          await mouse.up();
          await mouse.moveTo(Offset.zero);
          await tester.pumpAndSettle();
        }

        await _pumpDanbooruHost(
          tester,
          category: category,
          size: const Size(1180, 900),
          textScale: 1,
          interactionPolicy: InteractionPolicy.neutral,
        );
        await click(find.text('Open'));
        await click(_sourceTab(source));
        await _expectReachableInForm(tester, _tile(label), source);
        final restingSize = tester.getSize(_tile(label));
        expect(_openInDanbooru(label).hitTestable(), findsNothing);

        await mouse.moveTo(tester.getCenter(_tile(label)));
        await tester.pump();
        expect(_openInDanbooru(label).hitTestable(), findsOne);
        expect(tester.getSize(_tile(label)), restingSize);
        // 悬停预览在 300ms 后请求网络，移开前只推进单帧
        await mouse.moveTo(Offset.zero);
        await tester.pump();
        expect(_openInDanbooru(label).hitTestable(), findsNothing);

        var presses = 0;
        while (!_focusWithin(_tile(label)) && presses < 60) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          presses++;
        }
        expect(_focusWithin(_tile(label)), isTrue, reason: 'Tab 能落到条目上');
        expect(_openInDanbooru(label).hitTestable(), findsOne);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          _focusWithin(_openInDanbooru(label)),
          isTrue,
          reason: '外部打开入口可用 Tab 到达',
        );
        expect(_openInDanbooru(label).hitTestable(), findsOne);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: _tile(label),
            matching: find.byIcon(Icons.check_circle),
          ),
          findsOne,
          reason: 'Enter 选中条目',
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Finder _openInDanbooru(String label) => find.descendant(
  of: _tile(label),
  matching: find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == 'View in Danbooru',
    skipOffstage: false,
  ),
);

SemanticsFinder _tileSemantics(String label) => find.semantics.byPredicate(
  (node) => node.flagsCollection.isButton && node.label.contains(label),
);

bool _focusWithin(Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  final targets = target.evaluate().toSet();
  if (focused == null || targets.isEmpty) return false;
  if (targets.contains(focused)) return true;
  var found = false;
  focused.visitAncestorElements((element) {
    found = targets.contains(element);
    return !found;
  });
  return found;
}

Future<void> _pumpDanbooruHost(
  WidgetTester tester, {
  required RandomCategory category,
  required Size size,
  required double textScale,
  required InteractionPolicy interactionPolicy,
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return _pumpHost(
    tester,
    category: category,
    mediaQuery: (data) =>
        data.copyWith(textScaler: TextScaler.linear(textScale)),
    interactionPolicy: interactionPolicy,
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required RandomCategory category,
  MediaQueryData Function(MediaQueryData data)? mediaQuery,
  InteractionPolicy? interactionPolicy,
  ThemeData? theme,
}) {
  Widget wrap(BuildContext context, Widget child) {
    final policyScoped = interactionPolicy == null
        ? child
        : InteractionPolicyScope(
            initialPolicy: interactionPolicy,
            child: child,
          );
    return mediaQuery == null
        ? policyScoped
        : MediaQuery(
            data: mediaQuery(MediaQuery.of(context)),
            child: policyScoped,
          );
  }

  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        theme: theme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: mediaQuery == null && interactionPolicy == null
            ? null
            : (context, child) => wrap(context, child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => AddTagGroupDialog.show(
                context,
                category: category,
                presetId: 'test-preset',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}
