import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/app_branch_visibility.dart';
import 'package:nai_launcher/presentation/widgets/common/frame_staggered_builder.dart';

void main() {
  testWidgets('materializes at most one expensive child per frame', (
    tester,
  ) async {
    final controller = FrameStaggerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            FrameStaggeredChild(
              controller: controller,
              placeholder: const Text('placeholder-a'),
              child: const Text('child-a'),
            ),
            FrameStaggeredChild(
              controller: controller,
              placeholder: const Text('placeholder-b'),
              child: const Text('child-b'),
            ),
          ],
        ),
      ),
    );

    expect(find.text('placeholder-a'), findsOneWidget);
    expect(find.text('placeholder-b'), findsOneWidget);

    await tester.pump();
    expect(find.text('child-a'), findsOneWidget);
    expect(find.text('placeholder-b'), findsOneWidget);

    await tester.pump();
    expect(find.text('child-b'), findsOneWidget);
  });

  testWidgets('does not materialize while its branch is hidden', (
    tester,
  ) async {
    final controller = FrameStaggerController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppBranchVisibility(
          isVisible: false,
          child: FrameStaggeredChild(
            controller: controller,
            placeholder: const Text('placeholder'),
            child: const Text('child'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('placeholder'), findsOneWidget);
    expect(find.text('child'), findsNothing);
  });
}
