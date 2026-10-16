import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_pinned_header_sliver.dart';

const _minContent = AdaptivePinnedHeaderSliver.minContentExtent;
final _scrollKey = GlobalKey();

Widget _header(String label, double height, {FocusNode? fieldFocus}) {
  return SizedBox(
    key: ValueKey('header-$label'),
    height: height,
    child: ColoredBox(
      color: Colors.white,
      child: fieldFocus != null
          ? TextField(key: ValueKey('field-$label'), focusNode: fieldFocus)
          : TextButton(onPressed: () {}, child: Text(label)),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required double viewportHeight,
  required List<Widget> headers,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: viewportHeight,
            child: CustomScrollView(
              key: _scrollKey,
              slivers: [
                ...headers,
                SliverList.builder(
                  itemCount: 60,
                  itemBuilder: (context, index) => SizedBox(
                    key: ValueKey('item-$index'),
                    height: 50,
                    child: Text('item $index'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

RenderAdaptivePinnedHeaderSliver _sliver(WidgetTester tester, String label) {
  RenderObject? node = tester.renderObject(
    find.byKey(ValueKey('header-$label'), skipOffstage: false),
  );
  while (node is! RenderAdaptivePinnedHeaderSliver) {
    node = node!.parent;
  }
  return node;
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(_scrollKey),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

double _top(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(ValueKey(key))).dy;

void main() {
  testWidgets('头部加最小内容高度放得下时固定在视口顶端并可点中', (tester) async {
    await _pump(
      tester,
      viewportHeight: 600,
      headers: [AdaptivePinnedHeaderSliver(child: _header('a', 100))],
    );
    expect(_sliver(tester, 'a').isPinned, isTrue);

    _position(tester).jumpTo(400);
    await tester.pump();
    expect(_top(tester, 'header-a'), 0);
    expect(
      tester
          .hitTestOnBinding(const Offset(400, 50))
          .path
          .any(
            (entry) =>
                entry.target is RenderBox &&
                entry.target ==
                    tester.renderObject(find.byKey(const ValueKey('header-a'))),
          ),
      isTrue,
      reason: '列表从头部下方滚过，点击仍落在头部上',
    );
  });

  testWidgets('放不下时随内容滚出视口', (tester) async {
    await _pump(
      tester,
      viewportHeight: 100 + _minContent - 1,
      headers: [AdaptivePinnedHeaderSliver(child: _header('a', 100))],
    );
    expect(_sliver(tester, 'a').isPinned, isFalse);

    _position(tester).jumpTo(60);
    await tester.pump();
    expect(_top(tester, 'header-a'), -60);
    expect(_top(tester, 'item-0'), 40);
  });

  testWidgets('多个头部按前序滚动长度判断，滚动前后结论不翻转', (tester) async {
    await _pump(
      tester,
      viewportHeight: 600,
      headers: [
        AdaptivePinnedHeaderSliver(child: _header('a', 100)),
        AdaptivePinnedHeaderSliver(child: _header('b', 200)),
        AdaptivePinnedHeaderSliver(child: _header('c', 100)),
      ],
    );
    // a、b 叠放后仍留得下最小内容高度，再加 c 就不够
    for (final pixels in [0.0, 50.0, 250.0, 900.0]) {
      _position(tester).jumpTo(pixels);
      await tester.pump();
      expect(_sliver(tester, 'a').isPinned, isTrue, reason: 'pixels=$pixels');
      expect(_sliver(tester, 'b').isPinned, isTrue, reason: 'pixels=$pixels');
      expect(_sliver(tester, 'c').isPinned, isFalse, reason: 'pixels=$pixels');
    }
    expect(_top(tester, 'header-a'), 0);
    expect(_top(tester, 'header-b'), 100);
    expect(find.byKey(const ValueKey('header-c')), findsNothing);
  });

  testWidgets('视口变矮时改为随内容滚动，头部输入、焦点与内容位置不变', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Future<void> pumpAt(double height) => _pump(
      tester,
      viewportHeight: height,
      headers: [
        AdaptivePinnedHeaderSliver(child: _header('a', 100, fieldFocus: focus)),
      ],
    );

    await pumpAt(600);
    await tester.enterText(find.byKey(const ValueKey('field-a')), 'keep');
    expect(focus.hasFocus, isTrue);
    _position(tester).jumpTo(300);
    await tester.pump();
    final itemTop = _top(tester, 'item-6');

    await pumpAt(300);
    expect(_sliver(tester, 'a').isPinned, isFalse);
    expect(focus.hasFocus, isTrue);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText, skipOffstage: false))
          .controller
          .text,
      'keep',
    );
    expect(_position(tester).pixels, 300);
    expect(_top(tester, 'item-6'), itemTop, reason: '两种模式下内容的滚动偏移语义相同');

    await pumpAt(600);
    expect(_sliver(tester, 'a').isPinned, isTrue);
    expect(focus.hasFocus, isTrue);
    expect(_top(tester, 'item-6'), itemTop);
    expect(tester.takeException(), isNull);
  });

  testWidgets('固定时点入头部的输入框不会把列表滚回顶部', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(
      tester,
      viewportHeight: 600,
      headers: [
        AdaptivePinnedHeaderSliver(child: _header('a', 100, fieldFocus: focus)),
      ],
    );
    _position(tester).jumpTo(800);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('field-a')));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(_position(tester).pixels, 800);
  });

  testWidgets('随内容滚动时聚焦头部输入框会把它滚回视口', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(
      tester,
      viewportHeight: 300,
      headers: [
        AdaptivePinnedHeaderSliver(child: _header('a', 100, fieldFocus: focus)),
      ],
    );
    _position(tester).jumpTo(800);
    await tester.pump();
    focus.requestFocus();
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byKey(const ValueKey('field-a')));
    expect(field.top, greaterThanOrEqualTo(0));
    expect(field.bottom, lessThanOrEqualTo(300));
  });
}
