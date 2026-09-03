import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_input.dart';

void main() {
  testWidgets('physical keyboard shortcuts work on a touch-first platform', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final controller = TextEditingController(text: 'blue eyes');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 240,
              child: UnifiedPromptInput(
                controller: controller,
                sessionId: 'physical_keyboard_shortcuts',
                enableAssistant: false,
                fitContent: true,
                config: const UnifiedPromptConfig(
                  enableAutocomplete: false,
                  enableSyntaxHighlight: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(EditableText));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;

    expect(find.byKey(const ValueKey('prompt_input_search_field')), findsOne);
    await tester.pump(const Duration(milliseconds: 250));
  });
}
