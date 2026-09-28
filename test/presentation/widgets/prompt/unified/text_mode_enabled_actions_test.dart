import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_capsule.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

import '../../../../helpers/memory_local_storage.dart';

void main() {
  for (final (menu, width, scale, height, keyboard) in [
    (false, 800.0, 1.0, 600.0, 0.0),
    (true, 800.0, 1.0, 600.0, 0.0),
    for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0])
      (false, width, 3.0, 800.0, 0.0),
    (false, 840.0, 1.0, 360.0, 0.0),
    (false, 600.0, 1.0, 800.0, 240.0),
  ]) {
    testWidgets(
      'text enable actions menu=$menu width=$width scale=$scale height=$height keyboard=$keyboard',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, height);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final source = TextEditingController(text: 'cat, dog, bird');
        final focus = FocusNode();
        final changes = <String>[];
        addTearDown(source.dispose);
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWith(
                (ref) => MemoryLocalStorage(),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 24, bottom: 20),
                  viewInsets: EdgeInsets.only(bottom: keyboard),
                ),
                child: child!,
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  height: 300,
                  child: UnifiedPromptInput(
                    controller: source,
                    focusNode: focus,
                    enableAssistant: false,
                    expands: true,
                    onChanged: changes.add,
                    config: const UnifiedPromptConfig(
                      enableTagMode: true,
                      enableAutocomplete: false,
                      enableSyntaxHighlight: false,
                      enableAutoFormat: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pumpAndSettle();
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        editable.widget.controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 8,
        );
        await tester.pumpAndSettle();
        Future<void> act(String label) async {
          if (menu) {
            expect(editable.showToolbar(), isTrue);
            await tester.pumpAndSettle();
            await tester.tap(find.text(label));
          } else {
            await tester.tap(
              find.byKey(const ValueKey('text-selection-enabled-button')),
            );
          }
          await tester.pumpAndSettle();
        }

        const disabled = '/*disabled:cat*/, /*disabled:dog*/, bird';
        await act('Disable');
        expect(source.text, disabled);
        expect(changes, [disabled]);
        expect(editable.widget.controller.text, 'cat, dog, bird');
        expect(
          editable.widget.controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 8),
        );
        await act('Enable');
        expect(source.text, 'cat, dog, bird');
        expect(changes.last, source.text);
        Future<void> undo() async {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
        }

        await undo();
        expect(source.text, disabled);
        expect(changes.last, disabled);
        await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<TagEditorCapsule>(find.byType(TagEditorCapsule))
              .where((tag) => tag.tag.span.disabled),
          hasLength(2),
        );
        await undo();
        expect(source.text, 'cat, dog, bird');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 250));
      },
    );
  }
}
