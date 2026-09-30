import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
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
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required RandomCategory category,
  MediaQueryData Function(MediaQueryData data)? mediaQuery,
}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: mediaQuery == null
            ? null
            : (context, child) => MediaQuery(
                data: mediaQuery(MediaQuery.of(context)),
                child: child!,
              ),
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
