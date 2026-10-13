import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_view.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

import '../../../../helpers/memory_local_storage.dart';

Future<void> _pumpInput(
  WidgetTester tester,
  TextEditingController host, {
  ValueChanged<String>? onChanged,
  bool showTagModeSwitch = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => MemoryLocalStorage()),
      ],
      child: MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: InteractionPolicyScope(
          initialPolicy: const InteractionPolicy(
            modality: InteractionModality.pointer,
            touchAvailable: false,
            precisePointerAvailable: true,
          ),
          child: Scaffold(
            body: SizedBox(
              width: 720,
              height: 160,
              child: UnifiedPromptInput(
                controller: host,
                enableAssistant: false,
                showTagModeSwitch: showTagModeSwitch,
                config: const UnifiedPromptConfig(
                  enableTagMode: true,
                  enableAutocomplete: false,
                  enableAutoFormat: false,
                  enableSdSyntaxAutoConvert: false,
                ),
                onChanged: onChanged,
                maxLines: null,
                expands: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// 滚轮调整选区所在的已有权重，而不是在其内外再套一层；按住鼠标键时滚轮只滚动。
void main() {
  for (final (name, text, part, dy, expected) in [
    ('双击选中带权重标签的文字', 'a, 1.05::iu::, b', 'iu', -40.0, 'a, 1.1::iu::, b'),
    ('选区带上前面的逗号', 'a, 1.05::iu::, b', ', 1.05::iu::', 40.0, 'a, iu, b'),
    ('修复旧版本叠出的嵌套权重', '0.9::1.05::iu::::', 'iu', -40.0, '1.1::iu::'),
  ]) {
    testWidgets(name, (tester) async {
      final host = TextEditingController(text: text);
      addTearDown(host.dispose);
      final reported = <String>[];
      await _pumpInput(tester, host, onChanged: reported.add);
      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      final start = text.indexOf(part);
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: text,
          selection: TextSelection(
            baseOffset: start,
            extentOffset: start + part.length,
          ),
        ),
      );
      await tester.pump();

      final pointer = TestPointer(1, PointerDeviceKind.mouse)
        ..hover(tester.getCenter(find.byType(EditableText).first));
      await tester.sendEventToBinding(pointer.scroll(Offset(0, dy)));
      await tester.pump();

      expect(host.text, expected);
      expect(reported.last, expected);
    });
  }

  testWidgets(
    '按住鼠标拖选时滚轮滚动文本，松开后才调整权重',
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
    (tester) async {
      final text = List.generate(40, (index) => 'tag_$index').join(',\n');
      final host = TextEditingController(text: text);
      addTearDown(host.dispose);
      await _pumpInput(tester, host);
      final field = find.byType(EditableText).first;
      await tester.tap(field);
      await tester.pump(const Duration(milliseconds: 500));

      final origin = tester.getTopLeft(field);
      final drag = await tester.startGesture(
        origin + const Offset(4, 8),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await drag.moveTo(origin + const Offset(120, 60));
      await tester.pump();
      expect(host.selection.isCollapsed, isFalse);

      final scrollable = find.descendant(
        of: field,
        matching: find.byType(Scrollable),
      );
      final wheel = TestPointer(2, PointerDeviceKind.mouse)
        ..hover(tester.getBottomLeft(field) + const Offset(200, -12));
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, 40)));
      await tester.pump();
      expect(host.text, text);
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(0),
      );

      await drag.up();
      await tester.pump();
      await tester.sendEventToBinding(wheel.scroll(const Offset(0, -40)));
      await tester.pump();
      expect(host.text, isNot(text));
    },
  );

  testWidgets('标签模式按住鼠标时滚轮不调整选中标签的权重', (tester) async {
    const text = 'a, 1.05::iu::, b';
    final host = TextEditingController(text: text);
    addTearDown(host.dispose);
    await _pumpInput(tester, host, showTagModeSwitch: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
    await tester.pumpAndSettle();

    final session = tester
        .widget<TagEditorView>(find.byType(TagEditorView))
        .session;
    session.setSelection([
      session.leaves.firstWhere((tag) => tag.span.label == 'iu').id,
    ]);
    await tester.pump();
    final capsule = tester.getCenter(
      find
          .descendant(of: find.byType(TagEditorView), matching: find.text('iu'))
          .first,
    );

    final press = await tester.startGesture(
      capsule,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    final wheel = TestPointer(2, PointerDeviceKind.mouse)..hover(capsule);
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, -40)));
    await tester.pump();
    expect(host.text, text);

    await press.cancel();
    await tester.pump();
    await tester.sendEventToBinding(wheel.scroll(const Offset(0, -40)));
    await tester.pump();
    expect(host.text, 'a, 1.1::iu::, b');
  });
}
