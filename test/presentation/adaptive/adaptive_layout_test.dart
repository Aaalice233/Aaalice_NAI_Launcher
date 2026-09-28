import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_layout.dart';

void main() {
  test('breakpoints classify the required viewport matrix', () {
    expect(AdaptiveBreakpoints.classifyWidth(360), WindowSizeClass.compact);
    expect(AdaptiveBreakpoints.classifyWidth(600), WindowSizeClass.medium);
    expect(AdaptiveBreakpoints.classifyWidth(840), WindowSizeClass.expanded);
    expect(AdaptiveBreakpoints.classifyWidth(1180), WindowSizeClass.wide);
    expect(AdaptiveBreakpoints.classifyWidth(1600), WindowSizeClass.wide);
  });

  testWidgets('AdaptiveLayout selects compact, medium, and expanded branches', (
    tester,
  ) async {
    for (final scenario in <(double, String)>[
      (360, 'compact'),
      (700, 'medium'),
      (1180, 'expanded'),
    ]) {
      await tester.binding.setSurfaceSize(Size(scenario.$1, 600));
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveLayout(
            compact: (_) => const Text('compact'),
            medium: (_) => const Text('medium'),
            expanded: (_) => const Text('expanded'),
          ),
        ),
      );
      expect(find.text(scenario.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('slot areas and content bounds follow the current class', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late AdaptiveSlotAreas areas;
    late BoxConstraints content;
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveSlotLayout(
          builder: (context, value) {
            areas = value;
            return AdaptiveContentBounds(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  content = constraints;
                  return const SizedBox.expand();
                },
              ),
            );
          },
        ),
      ),
    );

    expect(areas.sizeClass, WindowSizeClass.wide);
    expect(
      areas.workspaceContentMaxWidth,
      AdaptiveBreakpoints.workspaceContentMaxWidth,
    );
    expect(content.maxWidth, AdaptiveBreakpoints.readableContentMaxWidth);
  });

  test('slot policy keeps Medium rail and derives panes from real widths', () {
    const areas = AdaptiveSlotAreas(
      constraints: BoxConstraints(maxWidth: 700),
      sizeClass: WindowSizeClass.medium,
      horizontalPadding: 20,
      workspaceContentMaxWidth: 660,
      minimumTargetExtent: 40,
    );

    expect(areas.usesNavigationRail, isTrue);
    expect(
      areas.canFitSupportingPane(
        mainMinimumWidth: 400,
        supportingMinimumWidth: 240,
      ),
      isTrue,
    );
    expect(
      areas.canFitSupportingPane(
        mainMinimumWidth: 500,
        supportingMinimumWidth: 240,
      ),
      isFalse,
    );
  });
}
