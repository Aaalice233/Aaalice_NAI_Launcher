import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_capsule.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_view.dart';

import 'tag_mode_prompt_field_test.dart' show pumpEditor;

void main() {
  testWidgets('touch blank taps clear selection inside and outside editor', (
    tester,
  ) async {
    final source = TextEditingController(text: 'cat, dog');
    addTearDown(source.dispose);
    await pumpEditor(tester, source);
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();
    for (final outside in [false, true]) {
      await tester.tap(find.byType(TagEditorCapsule).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tag-action-toolbar')), findsOneWidget);
      await tester.tapAt(
        outside
            ? const Offset(10, 20)
            : tester.getRect(find.byType(TagEditorView)).bottomLeft +
                  const Offset(20, -30),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tag-action-toolbar')), findsNothing);
      expect(
        tester
            .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
            .every((tag) => !tag.selected),
        isTrue,
      );
      expect(source.text, 'cat, dog');
    }
  });

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('touch toolbar edits directly at $width/$scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final source = TextEditingController(text: 'cat, dog');
        addTearDown(source.dispose);
        await pumpEditor(tester, source, width: width, scale: scale);
        await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TagEditorCapsule).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('tag-action-toolbar')),
            matching: find.byIcon(Icons.add),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('tag-action-toolbar')),
          findsOneWidget,
        );
        final edit = find.byKey(const ValueKey('tag-edit-button'));
        expect(edit.hitTestable(), findsOneWidget);
        expect(tester.getSize(edit).height, greaterThanOrEqualTo(48));
        await tester.tap(edit);
        await tester.pumpAndSettle();
        final input = find.byKey(const ValueKey('tag-input-0'));
        expect(input, findsOneWidget);
        await tester.enterText(input, 'kitten');
        await tester.pumpAndSettle();
        expect(source.text, contains('kitten'));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('pointer toolbar keeps its existing actions', (tester) async {
    final source = TextEditingController(text: 'cat, dog');
    addTearDown(source.dispose);
    await pumpEditor(
      tester,
      source,
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
    await tester.tap(
      find.byType(TagEditorCapsule).first,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tag-action-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('tag-edit-button')), findsNothing);
  });
}
