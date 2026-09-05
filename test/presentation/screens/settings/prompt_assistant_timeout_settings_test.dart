import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/prompt_assistant_settings_section.dart';

void main() {
  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('$width px / ${scale}x 超时选项可操作并保存', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        final storage = _SettingsStorage();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [localStorageServiceProvider.overrideWithValue(storage)],
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: PromptAssistantSettingsSection(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final selector = find.byKey(
          const ValueKey('prompt-assistant-response-timeout'),
        );
        await tester.ensureVisible(selector);
        await tester.tap(selector);
        await tester.pumpAndSettle();
        final option = find.text('15 分钟').last;
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(tester.widget<DropdownButton<int>>(selector).value, 900);
        final saved = PromptAssistantConfigState.decode(
          storage.getSetting<String>(StorageKeys.promptAssistantConfigJson)!,
        );
        expect(saved.responseTimeoutSeconds, 900);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _SettingsStorage extends LocalStorageService {
  final _settings = <String, Object?>{};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      _settings[key] as T? ?? defaultValue;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _settings[key] = value;
  }
}
