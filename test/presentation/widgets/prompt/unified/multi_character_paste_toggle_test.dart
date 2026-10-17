import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/comfyui_import_dialog.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

void main() {
  Future<void> pumpInput(
    WidgetTester tester, {
    required TextEditingController controller,
    required ValueNotifier<bool> detectOnPaste,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith(
            (ref) => _TestLocalStorageService(),
          ),
        ],
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 720,
              height: 120,
              child: ValueListenableBuilder<bool>(
                valueListenable: detectOnPaste,
                builder: (context, enabled, _) => UnifiedPromptInput(
                  controller: controller,
                  enableAssistant: false,
                  config: UnifiedPromptConfig(
                    enableAutocomplete: false,
                    enableSyntaxHighlight: false,
                    enableAutoFormat: false,
                    enableComfyuiImport: enabled,
                  ),
                  maxLines: null,
                  expands: true,
                  onComfyuiImport: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('keeps pasted pipe prompts as text while detection is off', (
    tester,
  ) async {
    final controller = TextEditingController();
    final detectOnPaste = ValueNotifier(false);
    addTearDown(controller.dispose);
    addTearDown(detectOnPaste.dispose);
    await pumpInput(
      tester,
      controller: controller,
      detectOnPaste: detectOnPaste,
    );

    const pasted = 'scene | first character | second character';
    controller.text = pasted;
    await tester.pumpAndSettle();

    expect(find.byType(ComfyuiImportDialog), findsNothing);
    expect(controller.text, pasted);
  });

  testWidgets('toggling detection keeps the same editable state', (
    tester,
  ) async {
    final controller = TextEditingController();
    final detectOnPaste = ValueNotifier(true);
    addTearDown(controller.dispose);
    addTearDown(detectOnPaste.dispose);
    await pumpInput(
      tester,
      controller: controller,
      detectOnPaste: detectOnPaste,
    );

    final before = tester.state<EditableTextState>(find.byType(EditableText));
    detectOnPaste.value = false;
    await tester.pump();
    final whileOff = tester.state<EditableTextState>(find.byType(EditableText));
    detectOnPaste.value = true;
    await tester.pump();
    final after = tester.state<EditableTextState>(find.byType(EditableText));

    expect(whileOff, same(before));
    expect(after, same(before));

    controller.text = 'scene | first character | second character';
    await tester.pumpAndSettle();
    expect(find.byType(ComfyuiImportDialog), findsOneWidget);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();
  });
}

class _TestLocalStorageService extends LocalStorageService {
  @override
  bool getResolveAliasOnCopy() => false;

  @override
  bool getEnablePromptWeightScroll() => false;

  @override
  bool getEnableAutocomplete() => false;

  @override
  bool getAutoFormatPrompt() => false;

  @override
  bool getHighlightEmphasis() => false;

  @override
  bool getSdSyntaxAutoConvert() => false;

  @override
  bool getEnableCooccurrenceRecommendation() => false;

  @override
  String? getTagLibraryEntriesJson() => null;

  @override
  String? getTagLibraryCategoriesJson() => null;

  @override
  int getTagLibraryViewMode() => 0;
}
