import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/common/resizable_pane.dart';

void main() {
  testWidgets('pointer-rate width updates relayout without rebuilding child', (
    tester,
  ) async {
    final controller = ResizablePaneController(initialWidth: 320);
    addTearDown(controller.dispose);
    var childBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const Expanded(child: ColoredBox(color: Colors.black)),
              ResizablePane(
                key: const ValueKey('resizable-pane'),
                controller: controller,
                minimumWidth: 240,
                maximumWidth: 520,
                child: _BuildCounter(
                  onBuild: () => childBuilds++,
                  child: const ColoredBox(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(childBuilds, 1);
    expect(
      tester.getSize(find.byKey(const ValueKey('resizable-pane'))).width,
      320,
    );

    for (var frame = 0; frame < 10; frame++) {
      controller.resizeBy(12);
      await tester.pump();
      expect(childBuilds, 1, reason: 'frame=$frame');
    }

    expect(
      tester.getSize(find.byKey(const ValueKey('resizable-pane'))).width,
      440,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('resizable pane clamps updates to its current layout bounds', (
    tester,
  ) async {
    final controller = ResizablePaneController(initialWidth: 320);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: ResizablePane(
              key: const ValueKey('resizable-pane'),
              controller: controller,
              minimumWidth: 240,
              maximumWidth: 520,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );

    controller.resizeBy(1000);
    await tester.pump();
    expect(controller.width, 520);

    controller.resizeBy(-1000);
    await tester.pump();
    expect(controller.width, 240);
    expect(tester.takeException(), isNull);
  });
}

class _BuildCounter extends StatelessWidget {
  const _BuildCounter({required this.onBuild, required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}
