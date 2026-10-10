import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/generation_segmented_toggle.dart';

import '../../../../helpers/ink_expectations.dart';

enum _Effort { medium, high }

void main() {
  Future<List<_Effort>> pumpToggle(
    WidgetTester tester, {
    _Effort selected = _Effort.medium,
    InteractionPolicy? policy,
  }) async {
    final changes = <_Effort>[];
    await tester.pumpWidget(
      MaterialApp(
        home: InteractionPolicyScope(
          initialPolicy: policy,
          child: Scaffold(
            body: Center(
              child: GenerationSegmentedToggle<_Effort>(
                semanticLabel: '生成档位',
                segments: const [
                  GenerationSegment(value: _Effort.medium, label: '节约'),
                  GenerationSegment(value: _Effort.high, label: '标准'),
                ],
                selected: selected,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  Finder segmentInk(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(InkWell));

  SemanticsNode segmentNode(String label) {
    final node = find.semantics.byPredicate(
      (node) => node.flagsCollection.isButton && node.label == label,
    );
    expect(node, findsOne, reason: label);
    return node.evaluate().single;
  }

  testWidgets('only a different segment reports a change', (tester) async {
    final changes = await pumpToggle(tester);

    await tester.tap(find.text('节约'));
    await tester.pump();
    expect(changes, isEmpty);

    await tester.tap(find.text('标准'));
    await tester.pump();
    expect(changes, [_Effort.high]);
  });

  testWidgets('screen readers hear the group name and the exclusive choice', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpToggle(tester);

    expect(
      find.semantics.byPredicate((node) => node.label == '生成档位'),
      findsOne,
    );
    expect(find.text('生成档位'), findsNothing);

    final medium = segmentNode('节约').flagsCollection;
    final high = segmentNode('标准').flagsCollection;
    expect(medium.isSelected, Tristate.isTrue);
    expect(high.isSelected, Tristate.isFalse);
    expect(medium.isInMutuallyExclusiveGroup, isTrue);
    expect(high.isInMutuallyExclusiveGroup, isTrue);
    semantics.dispose();
  });

  testWidgets('desktop stays as compact as the generation toggles', (
    tester,
  ) async {
    await pumpToggle(tester, policy: InteractionPolicy.neutral);

    final height = tester
        .getSize(find.byType(GenerationSegmentedToggle<_Effort>))
        .height;
    expect(height, lessThan(32));
  });

  testWidgets('touch reaches the minimum control extent', (tester) async {
    await pumpToggle(tester, policy: InteractionPolicy.touchFirst);

    expect(
      tester.getSize(find.byType(GenerationSegmentedToggle<_Effort>)).height,
      greaterThanOrEqualTo(InteractionPolicy.touchFirst.minimumControlExtent),
    );
    for (final label in ['节约', '标准']) {
      expect(
        tester.getSize(segmentInk(label)).height,
        greaterThanOrEqualTo(44),
        reason: label,
      );
    }
  });

  testWidgets(
    'keyboard focus stays visible on the selected segment',
    (tester) async {
      final changes = await pumpToggle(tester);
      final theme = Theme.of(tester.element(find.text('节约')));

      await tabUntilFocused(tester, segmentInk('节约'));
      expectInkOnTop(
        tester,
        find
            .ancestor(of: find.text('节约'), matching: find.byType(Material))
            .first,
        ink: theme.focusColor,
        below: theme.colorScheme.primary,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(changes, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(changes, [_Effort.high]);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );
}
