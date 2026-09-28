import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/resize_handle.dart';

void main() {
  testWidgets('horizontal resize handle reports pointer drag deltas', (
    tester,
  ) async {
    var dragDelta = 0.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.center,
            child: SizedBox(
              height: 300,
              child: ResizeHandle(
                key: const ValueKey('draggable-horizontal'),
                onDrag: (delta) => dragDelta += delta,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('draggable-horizontal')),
      const Offset(-80, 0),
    );

    expect(dragDelta, closeTo(-80, 0.01));
  });

  testWidgets('resize handles use touch-safe hit extents without thickening', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InteractionPolicyScope(
          initialPolicy: InteractionPolicy.touchFirst,
          child: Scaffold(
            body: Column(
              children: [
                ResizeHandle(key: ValueKey('horizontal'), onDrag: _ignoreDrag),
                VerticalResizeHandle(
                  key: ValueKey('vertical'),
                  onDrag: _ignoreDrag,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('horizontal'))).width, 48);
    expect(tester.getSize(find.byKey(const ValueKey('vertical'))).height, 48);

    final paintedLines = tester.widgetList<Container>(find.byType(Container));
    expect(
      paintedLines.any((container) => container.constraints?.maxWidth == 2),
      isTrue,
    );
  });

  testWidgets('resize handles retain their compact precise-pointer extents', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InteractionPolicyScope(
          initialPolicy: InteractionPolicy(
            modality: InteractionModality.pointer,
            touchAvailable: true,
            precisePointerAvailable: true,
          ),
          child: Scaffold(
            body: Column(
              children: [
                ResizeHandle(key: ValueKey('horizontal'), onDrag: _ignoreDrag),
                VerticalResizeHandle(
                  key: ValueKey('vertical'),
                  onDrag: _ignoreDrag,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('horizontal'))).width, 8);
    expect(tester.getSize(find.byKey(const ValueKey('vertical'))).height, 8);
  });
}

void _ignoreDrag(double _) {}
