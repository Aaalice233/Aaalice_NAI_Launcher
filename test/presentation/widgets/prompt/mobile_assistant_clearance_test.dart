import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_state_provider.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

import '../../../helpers/memory_local_storage.dart';

void main() {
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'touch assistant preserves editor viewport at $width with 3x text',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final source = TextEditingController(
          text: List.filled(30, 'cat, blue sky').join(', '),
        );
        addTearDown(source.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWith(
                (ref) => MemoryLocalStorage(),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(width, 600),
                  textScaler: const TextScaler.linear(3),
                  padding: const EdgeInsets.only(bottom: 24),
                  viewInsets: const EdgeInsets.only(bottom: 100),
                ),
                child: InteractionPolicyScope(
                  initialPolicy: InteractionPolicy.touchFirst,
                  child: Scaffold(
                    body: SafeArea(
                      child: SizedBox(
                        height: 240,
                        child: UnifiedPromptInput(
                          controller: source,
                          sessionId: 'mobile-clearance',
                          config: const UnifiedPromptConfig(
                            enableAutocomplete: false,
                            enableSyntaxHighlight: false,
                            enableTagMode: false,
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.all(12),
                          ),
                          expands: true,
                          maxLines: null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final input = find.byType(UnifiedPromptInput);
        final container = ProviderScope.containerOf(tester.element(input));
        final originalRect = tester.getRect(find.byType(EditableText));
        for (final expanded in [false, true, false]) {
          container
              .read(promptAssistantStateProvider.notifier)
              .setExpanded('mobile-clearance', expanded);
          await tester.pump();
          final field = tester.widget<TextField>(find.byType(TextField));
          expect(field.decoration!.contentPadding, const EdgeInsets.all(12));
          expect(tester.getRect(find.byType(EditableText)), originalRect);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
