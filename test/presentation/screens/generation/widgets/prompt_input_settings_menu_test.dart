import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/autocomplete_settings.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_controller.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_models.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/prompt_input_toolbar.dart';

void main() {
  testWidgets('settings menu toggles the shared underscore preference', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final controller = PromptInputController(prompt: '', negativePrompt: '');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PromptInputBottomActions(
              controller: controller,
              commands: _noopCommands,
            ),
          ),
        ),
      ),
    );

    const title = 'Use Spaces Instead of Underscores';
    Finder checkbox(IconData icon) => find.descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byType(PopupMenuItem<String>),
      ),
      matching: find.byIcon(icon),
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(checkbox(Icons.check_box_outline_blank), findsOneWidget);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();

    expect(container.read(replaceUnderscoresPreferenceProvider), isTrue);
    expect(storage.values[StorageKeys.autocompleteReplaceUnderscores], isTrue);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(checkbox(Icons.check_box), findsOneWidget);
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();

    expect(container.read(replaceUnderscoresPreferenceProvider), isFalse);
    expect(storage.values[StorageKeys.autocompleteReplaceUnderscores], isFalse);
  });
}

final _noopCommands = PromptInputCommands(
  setNegativeMode: (_) {},
  updatePrompt: (_) {},
  updateNegativePrompt: (_) {},
  importComfyuiPrompt: (_, _) {},
  clearPrompt: () {},
  clearNegativePrompt: () {},
  generateRandomPrompt: () async {},
  openAssistantSettings: () {},
  showMobileCharacterManager: () async {},
  toggleMaximize: () {},
);

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (values[key] ?? defaultValue) as T?;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}
