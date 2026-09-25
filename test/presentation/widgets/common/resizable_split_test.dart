import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/resizable_split.dart';

void main() {
  Widget buildSplit({
    required Axis axis,
    required ResizableSplitController controller,
    required Size size,
    VoidCallback? onResizeEnd,
    void Function()? onLeadingBuild,
    void Function()? onTrailingBuild,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: ResizableSplit(
              axis: axis,
              controller: controller,
              minimumLeadingExtent: 100,
              minimumTrailingExtent: 150,
              resizeLabel: 'resize',
              dividerKey: const ValueKey('divider'),
              onResizeEnd: onResizeEnd,
              leading: _BuildCounter(
                key: const ValueKey('leading'),
                onBuild: onLeadingBuild ?? () {},
              ),
              trailing: _BuildCounter(
                key: const ValueKey('trailing'),
                onBuild: onTrailingBuild ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('拖动分隔线只重排布局，不重建两侧面板，结束时回调一次', (tester) async {
    final controller = ResizableSplitController.fraction(0.5);
    addTearDown(controller.dispose);
    var leadingBuilds = 0;
    var trailingBuilds = 0;
    var resizeEnds = 0;
    await tester.pumpWidget(
      buildSplit(
        axis: Axis.vertical,
        controller: controller,
        size: const Size(300, 508),
        onResizeEnd: () => resizeEnds++,
        onLeadingBuild: () => leadingBuilds++,
        onTrailingBuild: () => trailingBuilds++,
      ),
    );
    final dividerHeight = tester
        .getSize(find.byKey(const ValueKey('divider')))
        .height;
    final available = 508 - dividerHeight;
    expect(
      tester.getSize(find.byKey(const ValueKey('trailing'))).height,
      closeTo(available / 2, 0.01),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('divider'))),
    );
    for (var step = 0; step < 5; step++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(leadingBuilds, 1);
    expect(trailingBuilds, 1);
    expect(resizeEnds, 1);
    final trailingHeight = tester
        .getSize(find.byKey(const ValueKey('trailing')))
        .height;
    expect(trailingHeight, lessThan(available / 2));
    expect(controller.value, closeTo(trailingHeight / available, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('左右分栏按逻辑像素保存，拖动被最小宽度夹住', (tester) async {
    final controller = ResizableSplitController.logicalPixels(200);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildSplit(
        axis: Axis.horizontal,
        controller: controller,
        size: const Size(508, 400),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('trailing'))).width, 200);

    controller.dragBy(-1000);
    await tester.pump();
    final dividerWidth = tester
        .getSize(find.byKey(const ValueKey('divider')))
        .width;
    expect(
      tester.getSize(find.byKey(const ValueKey('leading'))).width,
      closeTo(100, 0.01),
    );
    expect(controller.value, closeTo(508 - dividerWidth - 100, 0.01));

    controller.dragBy(1000);
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const ValueKey('trailing'))).width,
      closeTo(150, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('空间不足两个最小值时按比例分配且不溢出', (tester) async {
    final controller = ResizableSplitController.logicalPixels(400);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildSplit(
        axis: Axis.horizontal,
        controller: controller,
        size: const Size(158, 200),
      ),
    );
    final leading = tester.getSize(find.byKey(const ValueKey('leading'))).width;
    final trailing = tester
        .getSize(find.byKey(const ValueKey('trailing')))
        .width;
    final divider = tester.getSize(find.byKey(const ValueKey('divider'))).width;
    expect(leading + trailing + divider, closeTo(158, 0.01));
    expect(trailing / leading, closeTo(150 / 100, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘方向键微调分隔线并提交', (tester) async {
    final controller = ResizableSplitController.logicalPixels(200);
    addTearDown(controller.dispose);
    var resizeEnds = 0;
    await tester.pumpWidget(
      buildSplit(
        axis: Axis.horizontal,
        controller: controller,
        size: const Size(600, 300),
        onResizeEnd: () => resizeEnds++,
      ),
    );
    Focus.of(
      tester.element(
        find
            .descendant(
              of: find.byKey(const ValueKey('divider')),
              matching: find.byType(Semantics),
            )
            .first,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.value, 200 + ResizableSplit.keyboardStep);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.value, 200);
    expect(resizeEnds, 2);
  });
}

class _BuildCounter extends StatelessWidget {
  const _BuildCounter({super.key, required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const ColoredBox(color: Colors.white);
  }
}
