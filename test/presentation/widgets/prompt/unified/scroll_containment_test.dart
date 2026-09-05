import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/tag_editor_view.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

void main() {
  for (final scenario in [
    (name: 'text', tags: false, short: false, readOnly: false),
    (name: 'tags', tags: true, short: false, readOnly: false),
    (name: 'short text', tags: false, short: true, readOnly: false),
    (name: 'short tags', tags: true, short: true, readOnly: false),
    (name: 'read-only text', tags: false, short: false, readOnly: true),
    (name: 'short read-only text', tags: false, short: true, readOnly: true),
  ]) {
    testWidgets(
      '${scenario.name} contains wheel scrolling only with overflow',
      (tester) async {
        final prompt = TextEditingController(
          text: scenario.short
              ? 'cat'
              : List.generate(120, (i) => 'tag_$i').join(',\n'),
        );
        final page = ScrollController(initialScrollOffset: 100);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: SingleChildScrollView(
                  controller: page,
                  child: Column(
                    children: [
                      const SizedBox(height: 200),
                      SizedBox(
                        height: 160,
                        child: UnifiedPromptInput(
                          controller: prompt,
                          expands: true,
                          enableAssistant: false,
                          config: UnifiedPromptConfig(
                            enableAutocomplete: false,
                            enableSyntaxHighlight: false,
                            enableTagMode: true,
                            readOnly: scenario.readOnly,
                          ),
                        ),
                      ),
                      const SizedBox(height: 1400),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        if (scenario.tags) {
          await tester.tap(find.byKey(const ValueKey('tag-mode-button')));
        }
        await tester.pumpAndSettle();
        final editor = find.byType(UnifiedPromptInput);
        final pointer = TestPointer(1, PointerDeviceKind.mouse)
          ..hover(tester.getCenter(editor));
        final initialPageOffset = page.offset;
        Future<void> wheel(double delta) async {
          final beforePageOffset = page.offset;
          pointer.hover(tester.getCenter(editor));
          bool? platformDefault;
          await tester.sendEventToBinding(
            pointer.scroll(
              Offset(0, delta),
              onRespond: ({required bool allowPlatformDefault}) =>
                  platformDefault = allowPlatformDefault,
            ),
          );
          await tester.pump();
          if (scenario.short) {
            expect(
              page.offset,
              delta > 0
                  ? greaterThan(beforePageOffset)
                  : lessThan(beforePageOffset),
            );
          } else {
            expect(page.offset, initialPageOffset);
          }
          expect(platformDefault, isFalse);
        }

        await wheel(-60);
        if (!scenario.short) {
          final inner = tester
              .stateList<ScrollableState>(
                find.descendant(
                  of: scenario.tags ? find.byType(TagEditorView) : editor,
                  matching: find.byType(Scrollable),
                ),
              )
              .firstWhere((state) => state.position.maxScrollExtent > 0);
          final before = inner.position.pixels;
          await wheel(60);
          expect(inner.position.pixels, greaterThan(before));
          inner.position.jumpTo(inner.position.maxScrollExtent);
        }
        await wheel(60);
        await wheel(60);

        if (!scenario.short) {
          final longText = prompt.text;
          prompt.text = 'cat';
          await tester.pumpAndSettle();
          pointer.hover(tester.getCenter(editor));
          await tester.sendEventToBinding(pointer.scroll(const Offset(0, 60)));
          await tester.pump();
          expect(page.offset, greaterThan(initialPageOffset));
          prompt.text = longText;
          await tester.pumpAndSettle();
          page.jumpTo(initialPageOffset);
          await tester.pump();
          await wheel(-60);
        }

        pointer.hover(const Offset(20, 450));
        await tester.sendEventToBinding(pointer.scroll(const Offset(0, 60)));
        await tester.pump();
        expect(page.offset, greaterThan(initialPageOffset));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 250));
        page.dispose();
        prompt.dispose();
      },
    );
  }
}
