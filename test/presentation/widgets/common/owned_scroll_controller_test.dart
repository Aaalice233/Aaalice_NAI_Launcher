import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/owned_scroll_controller.dart';

void main() {
  testWidgets('reattach starts at the last usable viewport without a jump', (
    tester,
  ) async {
    final viewport = OwnedViewportOffset();
    var controller = OwnedScrollController(viewport: viewport);

    Widget subject(ScrollController activeController) => MaterialApp(
      home: SizedBox(
        height: 300,
        child: ListView.builder(
          controller: activeController,
          itemExtent: 50,
          itemCount: 100,
          itemBuilder: (_, index) => Text('item $index'),
        ),
      ),
    );

    await tester.pumpWidget(subject(controller));
    controller.jumpTo(750);
    await tester.pump();
    expect(viewport.pixels, 750);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    controller.dispose();

    controller = OwnedScrollController(viewport: viewport);
    await tester.pumpWidget(subject(controller));

    expect(controller.offset, 750);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    controller.dispose();
  });

  testWidgets('a stale position cannot overwrite the newest attachment', (
    tester,
  ) async {
    final viewport = OwnedViewportOffset()..replace(100);
    final controller = OwnedScrollController(viewport: viewport);
    addTearDown(controller.dispose);

    Widget list(String key) => ListView.builder(
      key: ValueKey(key),
      controller: controller,
      itemExtent: 50,
      itemCount: 100,
      itemBuilder: (_, index) => Text('$key-$index'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Expanded(child: list('stale')),
            Expanded(child: list('active')),
          ],
        ),
      ),
    );
    final positions = controller.positions.toList(growable: false);
    expect(positions, hasLength(2));
    positions.first.jumpTo(300);
    positions.last.jumpTo(700);
    expect(controller.position, same(positions.last));
    expect(viewport.pixels, 700);

    await tester.pumpWidget(
      MaterialApp(home: SizedBox(height: 300, child: list('active'))),
    );

    expect(controller.position.pixels, 700);
    expect(viewport.pixels, 700);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('zero viewport never replaces a valid offset', () {
    final viewport = OwnedViewportOffset()..replace(640);

    viewport.record(
      FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 0,
        pixels: 0,
        viewportDimension: 0,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1,
      ),
    );

    expect(viewport.pixels, 640);
  });
}
