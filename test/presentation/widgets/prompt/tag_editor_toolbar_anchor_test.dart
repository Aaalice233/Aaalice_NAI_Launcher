import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_weight_label.dart';

import 'tag_mode_prompt_field_test.dart' show pumpEditor;

void main() {
  final scenarios = [
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0])
      for (final scale in [1.0, 3.0]) (width, 800.0, scale, 0.0),
    (840.0, 360.0, 1.0, 0.0),
    (600.0, 800.0, 1.0, 240.0),
  ];
  for (final (width, height, scale, keyboard) in scenarios) {
    testWidgets(
      'group toolbar clears header at $width / $height / $scale / $keyboard',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, height));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final source = TextEditingController(text: '{{cat, dog}}');
        addTearDown(source.dispose);
        await pumpEditor(
          tester,
          source,
          width: width,
          height: height,
          scale: scale,
          insets: EdgeInsets.only(bottom: keyboard),
        );
        await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
        await tester.pumpAndSettle();
        final header = find.byType(TagEditorWeightLabel).first;
        await tester.tap(
          find.descendant(of: header, matching: find.byType(InkWell)).first,
        );
        await tester.pumpAndSettle();

        final toolbar = tester.getRect(
          find.byKey(const ValueKey('tag-action-toolbar')),
        );
        final group = tester.getRect(
          find.byKey(const ValueKey('tag-weight-group-0')),
        );
        expect(toolbar.overlaps(group), isFalse);
        expect(toolbar.left, greaterThanOrEqualTo(0));
        expect(toolbar.right, lessThanOrEqualTo(width));
        expect(toolbar.top, greaterThanOrEqualTo(32));
        expect(
          toolbar.bottom,
          lessThanOrEqualTo(height - (keyboard > 20 ? keyboard : 20) - 8),
        );
        expect(find.text('cat'), findsOneWidget);
        expect(find.text('dog'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
