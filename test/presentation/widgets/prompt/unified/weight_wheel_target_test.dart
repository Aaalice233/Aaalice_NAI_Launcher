import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

import '../../../../helpers/memory_local_storage.dart';

/// 滚轮调整选区所在的已有权重，而不是在其内外再套一层。
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith(
              (ref) => MemoryLocalStorage(),
            ),
          ],
          child: MaterialApp(
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: SizedBox(
                width: 720,
                height: 160,
                child: UnifiedPromptInput(
                  controller: host,
                  enableAssistant: false,
                  showTagModeSwitch: false,
                  config: const UnifiedPromptConfig(
                    enableTagMode: true,
                    enableAutocomplete: false,
                    enableAutoFormat: false,
                    enableSdSyntaxAutoConvert: false,
                  ),
                  onChanged: reported.add,
                  maxLines: null,
                  expands: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
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
}
