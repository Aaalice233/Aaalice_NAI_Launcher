import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/prompt/nai_syntax_controller.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_capsule.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_weight_label.dart';

import 'tag_mode_prompt_field_test.dart' show pumpEditor;

void main() {
  testWidgets(
    'reducing selected inner tags does not tint unselected siblings or outside tags',
    (tester) async {
      final source = NaiSyntaxController(text: '{{cat, dog, fox}}, bird');
      addTearDown(source.dispose);
      await pumpEditor(tester, source, locale: const Locale('en'));
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      Color? color(String label) => tester
          .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
          .firstWhere((tag) => tag.tag.span.label == label)
          .emphasisColor;
      final foxBefore = color('fox');
      expect(color('bird'), isNull);
      await tester.tap(find.text('cat'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(find.text('dog'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(find.text('cat')),
            scrollDelta: const Offset(0, 20),
          ),
        );
        await tester.pumpAndSettle();
        expect(color('fox'), foxBefore);
        expect(color('bird'), isNull);
        expect(
          tester
              .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
              .where((tag) => tag.selected)
              .map((tag) => tag.tag.span.label),
          ['cat', 'dog'],
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'desktop group header stays compact and selection stays visible',
    (tester) async {
      final source = NaiSyntaxController(
        text: '1.3::cat, dog::, /*disabled:fox*/',
      );
      addTearDown(source.dispose);
      final theme = ThemeData.dark();
      await pumpEditor(
        tester,
        source,
        theme: theme,
        policy: const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('tag-mode-button')),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      final header = find.byType(TagEditorWeightLabel).first;
      expect(tester.getSize(header).height, lessThanOrEqualTo(28));
      final cat = find.ancestor(
        of: find.text('cat'),
        matching: find.byType(TagEditorCapsule),
      );
      await tester.tap(find.text('cat'), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      final selectedSurface = tester.widget<Material>(
        find.descendant(of: cat, matching: find.byType(Material)).first,
      );
      expect(
        selectedSurface.color,
        isNot(theme.colorScheme.secondaryContainer),
      );
      expect(
        selectedSurface.color,
        isNot(theme.colorScheme.surfaceContainerHigh),
      );
      expect(
        (selectedSurface.shape! as RoundedRectangleBorder).side.style,
        BorderStyle.solid,
      );
      final foregroundLuminance = theme.colorScheme.onSurface
          .computeLuminance();
      final backgroundLuminance = selectedSurface.color!.computeLuminance();
      expect(
        (foregroundLuminance + 0.05) / (backgroundLuminance + 0.05),
        greaterThanOrEqualTo(4.5),
      );
      final disabled = tester
          .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
          .last;
      expect(disabled.emphasisColor, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'weight colors follow source resets, model support and highlight setting',
    () {
      const text = '{1.3::cat::, dog}, /*disabled:2::fox::*/, 0.7::bird::';
      final controller = NaiSyntaxController(text: text);
      addTearDown(controller.dispose);
      final offsets = ['cat', 'dog', 'fox', 'bird'].map(text.indexOf).toList();
      final theme = ThemeData.dark();
      final colors = controller.emphasisColorsAt(theme, offsets);
      expect(colors[offsets[0]], isNotNull);
      expect(colors[offsets[1]], isNull);
      expect(colors[offsets[2]], isNull);
      expect(colors[offsets[3]], isNot(colors[offsets[0]]));
      controller.numericEmphasisEnabled = false;
      final legacy = controller.emphasisColorsAt(theme, offsets);
      expect(legacy[offsets[0]], legacy[offsets[1]]);
      expect(legacy[offsets[3]], isNull);
      controller.highlightEnabled = false;
      expect(controller.emphasisColorsAt(theme, offsets), isEmpty);
    },
  );

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
      testWidgets('group surfaces and syntax preview at $width $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 520);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const text = '1.3::cat, dog::, bird';
        final source = NaiSyntaxController(text: text);
        addTearDown(source.dispose);
        final theme = ThemeData(brightness: brightness);
        await pumpEditor(
          tester,
          source,
          theme: theme,
          width: width,
          height: 520,
          scale: 3,
          insets: const EdgeInsets.only(bottom: 120),
        );
        await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
        await tester.pumpAndSettle();
        final capsules = tester
            .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
            .toList();
        expect(capsules[0].emphasisColor, isNotNull);
        expect(capsules[1].emphasisColor, capsules[0].emphasisColor);
        expect(capsules[2].emphasisColor, isNull);
        Color? surface(String tag) => tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.ancestor(
                      of: find.text(tag),
                      matching: find.byType(TagEditorCapsule),
                    ),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;
        expect(surface('cat'), isNot(surface('bird')));
        final header = find.byType(TagEditorWeightLabel).first;
        await tester.ensureVisible(header);
        await tester.tap(find.byIcon(Icons.expand_more).first);
        await tester.pumpAndSettle();
        expect(
          find.text('1.3::cat, dog::', findRichText: true),
          findsOneWidget,
        );
        expect(source.text, text);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.expand_less).first);
        await tester.pumpAndSettle();
        expect(find.text('1.3::cat, dog::', findRichText: true), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
