import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

import '../../../../helpers/memory_local_storage.dart';

/// 组件内的文本改动只经由 onChanged 通知宿主一次；宿主经 controller 写入的文本不回送。
void main() {
  const prompt = 'alpha, beta, gamma';
  const betaSelection = TextSelection(baseOffset: 7, extentOffset: 11);

  for (final autocomplete in [false, true]) {
    group('自动补全${autocomplete ? '开启' : '关闭'}', () {
      late TextEditingController host;
      late List<String> reported;

      Future<void> pumpInput(WidgetTester tester) async {
        host = TextEditingController();
        addTearDown(host.dispose);
        reported = [];
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
                    config: UnifiedPromptConfig(
                      enableAutocomplete: autocomplete,
                      enableSyntaxHighlight: false,
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
        await tester.tap(find.byType(EditableText));
        await tester.pump();
      }

      testWidgets('用户输入每次改动只通知一次', (tester) async {
        await pumpInput(tester);

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'a',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'ab',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        await tester.pump();

        expect(reported, ['a', 'ab']);
        expect(host.text, 'ab');
      });

      testWidgets('权重工具栏的改动通知宿主', (tester) async {
        await pumpInput(tester);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: prompt,
            selection: TextSelection.collapsed(offset: prompt.length),
          ),
        );
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(text: prompt, selection: betaSelection),
        );
        await tester.pump();
        reported.clear();

        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('weight_adjust_toolbar_surface')),
            matching: find.byIcon(Icons.add),
          ),
        );
        await tester.pump();

        expect(reported, ['alpha, 1.05::beta::, gamma']);
        expect(host.text, 'alpha, 1.05::beta::, gamma');
      });

      testWidgets('宿主经 controller 写入的文本不回送', (tester) async {
        await pumpInput(tester);

        host.text = prompt;
        await tester.pump();

        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          prompt,
        );
        expect(reported, isEmpty);
      });
    });
  }
}
