import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_pinned_header_sliver.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/adaptive/content_sized_adaptive_form.dart';

import '../../helpers/reachability_expectations.dart';

const _title = 'A localized form title that wraps onto two lines';
final _header = find.byKey(
  const ValueKey('adaptive-panel-header-surface'),
  skipOffstage: false,
);

Finder _closeButton() => find.ancestor(
  of: find.byIcon(Icons.close, skipOffstage: false),
  matching: find.byType(IconButton, skipOffstage: false),
);

Finder _doneButton() => find.ancestor(
  of: find.text('Done', skipOffstage: false),
  matching: find.byType(FilledButton, skipOffstage: false),
);

Finder _field(int index) =>
    find.byKey(ValueKey('field-$index'), skipOffstage: false);

Future<void> _openForm(
  WidgetTester tester, {
  required Size size,
  double textScale = 1,
  double keyboard = 0,
  bool headerScrollsWithContent = true,
  int fieldCount = 40,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => AdaptivePresenter.showForm<void>(
              context: context,
              title: _title,
              headerScrollsWithContent: headerScrollsWithContent,
              builder: (context, controller) => ContentSizedAdaptiveForm(
                scrollController: controller,
                content: [
                  for (var i = 0; i < fieldCount; i++)
                    TextField(
                      key: ValueKey('field-$i'),
                      decoration: InputDecoration(labelText: 'Field $i'),
                    ),
                ],
                footer: Padding(
                  padding: const EdgeInsets.all(8),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

RenderAdaptivePinnedHeaderSliver _headerSliver(WidgetTester tester) {
  RenderObject? node = tester.renderObject(_header);
  while (node is! RenderAdaptivePinnedHeaderSliver) {
    node = node!.parent;
  }
  return node;
}

ScrollPosition _formPosition(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable).first).position;

void main() {
  testWidgets('高度充足时标题栏固定在表单顶端，正文从下方滚过且底部操作固定', (tester) async {
    await _openForm(tester, size: const Size(840, 900));
    expect(_headerSliver(tester).isPinned, isTrue);
    final surface = tester.getRect(
      find.byKey(const ValueKey('adaptive-centered-form')),
    );
    expect(tester.getTopLeft(_header).dy, surface.top);

    _formPosition(tester).jumpTo(400);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_header).dy, surface.top);
    expectReachable(tester, _closeButton(), reason: '固定的关闭按钮');
    expectReachable(tester, _doneButton(), reason: '固定的底部操作');
    expect(tester.takeException(), isNull);
  });

  for (final textScale in [1.0, 3.0]) {
    testWidgets('短横屏加键盘、${textScale}x 文字下标题栏与底部操作随正文滚动且全部可达', (tester) async {
      await _openForm(
        tester,
        size: const Size(740, 360),
        textScale: textScale,
        keyboard: 160,
      );
      expect(tester.takeException(), isNull);
      expect(_headerSliver(tester).isPinned, isFalse);

      for (final (label, target) in [
        ('首个字段', _field(0)),
        ('关闭按钮', _closeButton()),
        ('末个字段', _field(39)),
        ('完成', _doneButton()),
      ]) {
        await scrollUntilBuilt(tester, target, find.byType(Scrollable).first);
        await revealOnScreen(tester, target);
        expectReachable(tester, target, reason: label);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('标题栏与底部操作在固定和随正文滚动之间切换时输入与焦点保留', (tester) async {
    await _openForm(tester, size: const Size(840, 900), fieldCount: 3);
    await tester.enterText(_field(1), 'keep');
    final focus = tester
        .widget<EditableText>(
          find.descendant(of: _field(1), matching: find.byType(EditableText)),
        )
        .focusNode;
    expect(focus.hasFocus, isTrue);
    expect(_headerSliver(tester).isPinned, isTrue);

    tester.view.physicalSize = const Size(740, 360);
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    await tester.pumpAndSettle();
    expect(_headerSliver(tester).isPinned, isFalse);
    expect(focus.hasFocus, isTrue);
    expect(find.text('keep'), findsOneWidget);
    await revealOnScreen(tester, _field(1));
    expectReachable(tester, _field(1), reason: '键盘弹出后可滚回的输入框');

    tester.view.physicalSize = const Size(840, 900);
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(_headerSliver(tester).isPinned, isTrue);
    expect(focus.hasFocus, isTrue);
    expect(find.text('keep'), findsOneWidget);
    expectReachable(tester, _doneButton(), reason: '恢复固定的底部操作');
    expect(tester.takeException(), isNull);
  });

  testWidgets('未开启时标题栏仍固定在滚动视图之外，其他调用方的排布不变', (tester) async {
    await _openForm(
      tester,
      size: const Size(840, 900),
      headerScrollsWithContent: false,
    );
    expect(
      find.ancestor(of: _header, matching: find.byType(Scrollable)),
      findsNothing,
    );
    expect(
      find.byType(AdaptivePanelHeaderScope, skipOffstage: false),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
