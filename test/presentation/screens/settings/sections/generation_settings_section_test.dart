import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/generation_settings_section.dart';

void main() {
  testWidgets('prompt weight wheel switch defaults on and persists changes', (
    tester,
  ) async {
    final storage = _MemoryLocalStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: GenerationSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pump();

    final tileFinder = find.widgetWithText(SwitchListTile, '滚轮调整提示词权重');
    expect(tileFinder, findsOneWidget);
    expect(tester.widget<SwitchListTile>(tileFinder).value, isTrue);
    expect(find.textContaining('不再触发页面滚动'), findsOneWidget);

    await tester.tap(find.text('滚轮调整提示词权重'));
    await tester.pump();

    expect(tester.widget<SwitchListTile>(tileFinder).value, isFalse);
    expect(storage.values[StorageKeys.enablePromptWeightScroll], isFalse);
  });

  testWidgets('prompt weight wheel switch rolls back and shows save failure', (
    tester,
  ) async {
    final storage = _MemoryLocalStorageService(
      writeError: StateError('settings write failed'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: GenerationSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('滚轮调整提示词权重'));
    await tester.pump();
    await tester.pump();

    final tileFinder = find.widgetWithText(SwitchListTile, '滚轮调整提示词权重');
    expect(tester.widget<SwitchListTile>(tileFinder).value, isTrue);
    expect(find.textContaining('保存失败'), findsOneWidget);
    expect(storage.values, isEmpty);
  });
}

class _MemoryLocalStorageService extends LocalStorageService {
  _MemoryLocalStorageService({
    Map<String, Object?> initialValues = const {},
    this.writeError,
  }) : values = Map<String, Object?>.from(initialValues);

  final Map<String, Object?> values;
  final Object? writeError;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return values.containsKey(key) ? values[key] as T? : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    if (writeError case final error?) {
      throw error;
    }
    values[key] = value;
  }
}
