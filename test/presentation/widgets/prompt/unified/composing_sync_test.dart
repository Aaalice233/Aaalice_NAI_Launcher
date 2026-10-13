import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

import '../../../../helpers/memory_local_storage.dart';

/// 输入法组合输入期间，外部控制器的改写不能覆盖内部的组合区。
void main() {
  testWidgets('组合输入期间不被外部改写打断，组合结束后正常同步', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
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
              height: 120,
              child: UnifiedPromptInput(
                controller: controller,
                enableAssistant: false,
                config: const UnifiedPromptConfig(
                  enableAutocomplete: false,
                  enableSyntaxHighlight: false,
                  enableAutoFormat: false,
                  enableSdSyntaxAutoConvert: false,
                ),
                maxLines: null,
                expands: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    TextEditingValue innerValue() =>
        tester.widget<EditableText>(find.byType(EditableText)).controller.value;

    await tester.tap(find.byType(EditableText));
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'ni',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();

    controller.value = const TextEditingValue(text: 'stale');
    await tester.pump();

    expect(innerValue().text, 'ni');
    expect(innerValue().composing, const TextRange(start: 0, end: 2));

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '你',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();

    expect(innerValue().text, '你');
    expect(controller.text, '你');
  });
}
