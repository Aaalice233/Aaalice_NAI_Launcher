import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/presentation/widgets/prompt/nai_syntax_controller.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_capsule.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_weight_label.dart';

import 'tag_mode_prompt_field_test.dart' show pumpEditor;

class _CountingSyntax extends NaiSyntaxController {
  _CountingSyntax(String text) : super(text: text);
  int scans = 0;
  @override
  Map<int, Color> emphasisColorsAt(ThemeData theme, Iterable<int> offsets) {
    scans++;
    return super.emphasisColorsAt(theme, offsets);
  }
}

class _CountingLookup extends TagTranslationLookup {
  _CountingLookup()
    : super.fromResolver(
        (tags) async => {
          for (final tag in tags.where((tag) => !tag.contains('missing')))
            tag: '译文 $tag',
        },
      );
  final batches = <List<String>>[];
  @override
  Future<Map<String, String>> translateBatch(List<String> tags) {
    batches.add(List.of(tags));
    return super.translateBatch(tags);
  }
}

void main() {
  testWidgets(
    'caret stays local and changing one label reuses other capsules and translations',
    (tester) async {
      final source = _CountingSyntax(
        '{cat, dog, missing, ${List.generate(100, (i) => 'tag_$i').join(', ')}}',
      );
      final lookup = _CountingLookup();
      addTearDown(source.dispose);
      await pumpEditor(tester, source, lookup: lookup);
      await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('cat'));
      await tester.pumpAndSettle();
      final input = find.byType(TextField).hitTestable().first;
      final field = tester.widget<TextField>(input);
      final groupState = tester.state(find.byType(TagEditorWeightLabel).first);
      final rebuilt = <int>{};
      final oldHook = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        if (element.widget case final TagEditorCapsule capsule) {
          rebuilt.add(capsule.tag.id);
        }
        oldHook?.call(element, builtOnce);
      };
      addTearDown(() => debugOnRebuildDirtyWidget = oldHook);
      lookup.batches.clear();
      final scans = source.scans;
      for (var i = 0; i < 10; i++) {
        field.controller!.selection = TextSelection(
          baseOffset: 0,
          extentOffset: i % 4,
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(rebuilt, isEmpty);
      expect(source.scans, scans);
      expect(lookup.batches, isEmpty);
      await tester.enterText(input, 'kitten');
      await tester.pumpAndSettle();
      expect(rebuilt, hasLength(1));
      expect(source.scans, scans + 1);
      expect(lookup.batches, [
        ['kitten'],
      ]);
      expect(
        tester.state(find.byType(TagEditorWeightLabel).first),
        same(groupState),
      );
      expect(source.text, startsWith('{kitten, dog, missing,'));
      await tester.tap(find.text('dog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('dog'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).hitTestable().first,
        'puppy',
      );
      await tester.pumpAndSettle();
      expect(source.text, startsWith('{kitten, puppy, missing,'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
