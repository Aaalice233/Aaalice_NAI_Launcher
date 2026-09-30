import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/tab_swipe_detector.dart';

final _excludedKey = GlobalKey();

class _Host extends StatefulWidget {
  const _Host({required this.textDirection, required this.onSwitched});

  final TextDirection textDirection;
  final VoidCallback onSwitched;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final controller = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: widget.textDirection,
      child: TabSwipeDetector(
        controller: controller,
        excludedRegions: [_excludedKey],
        onSwitched: widget.onSwitched,
        // 靶子必须能被命中，无子 SizedBox 会让拖动根本到不了识别器
        child: Column(
          children: [
            SizedBox(
              key: _excludedKey,
              height: 100,
              width: 400,
              child: const ColoredBox(color: Colors.white),
            ),
            const SizedBox(
              key: ValueKey('content'),
              height: 300,
              width: 400,
              child: ColoredBox(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

Future<TabController> _pump(
  WidgetTester tester, {
  TextDirection textDirection = TextDirection.ltr,
  VoidCallback? onSwitched,
}) async {
  tester.view.physicalSize = const Size(400, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: _Host(
            textDirection: textDirection,
            onSwitched: onSwitched ?? () {},
          ),
        ),
      ),
    ),
  );
  return tester.state<_HostState>(find.byType(_Host)).controller;
}

Offset _content(WidgetTester tester) =>
    tester.getCenter(find.byKey(const ValueKey('content')));

void main() {
  testWidgets('甩动按速度方向切到相邻标签，两端不越界，切换后通知调用方', (tester) async {
    var switched = 0;
    final controller = await _pump(tester, onSwitched: () => switched++);

    await tester.flingFrom(_content(tester), const Offset(-120, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    await tester.flingFrom(_content(tester), const Offset(-120, 0), 1000);
    await tester.pumpAndSettle();
    await tester.flingFrom(_content(tester), const Offset(-120, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.index, 2);
    await tester.flingFrom(_content(tester), const Offset(120, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    expect(switched, 3);
  });

  testWidgets('从右到左排版时方向与 TabBarView 一样镜像', (tester) async {
    final controller = await _pump(tester, textDirection: TextDirection.rtl);
    await tester.flingFrom(_content(tester), const Offset(120, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.index, 1);
  });

  testWidgets('慢速拖动需越过一半宽度才切换', (tester) async {
    final controller = await _pump(tester);
    await tester.timedDrag(
      find.byKey(const ValueKey('content')),
      const Offset(-150, 0),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    expect(controller.index, 0);
    await tester.timedDrag(
      find.byKey(const ValueKey('content')),
      const Offset(-250, 0),
      const Duration(seconds: 2),
    );
    await tester.pumpAndSettle();
    expect(controller.index, 1);
  });

  testWidgets('从排除区域开始的横拖与鼠标拖动都不切换', (tester) async {
    final controller = await _pump(tester);
    await tester.flingFrom(
      tester.getCenter(find.byKey(_excludedKey)),
      const Offset(-120, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(controller.index, 0);
    await tester.flingFrom(
      _content(tester),
      const Offset(-120, 0),
      1000,
      deviceKind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(controller.index, 0);
  });
}
