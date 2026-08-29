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

  testWidgets('流式预览默认开启并可持久化关闭', (tester) async {
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

    final tileFinder = find.widgetWithText(SwitchListTile, '流式预览');
    expect(tileFinder, findsOneWidget);
    expect(tester.widget<SwitchListTile>(tileFinder).value, isTrue);
    expect(find.textContaining('直接等待最终图像'), findsOneWidget);

    await tester.tap(find.text('流式预览'));
    await tester.pump();

    expect(tester.widget<SwitchListTile>(tileFinder).value, isFalse);
    expect(storage.values[StorageKeys.generationStreamPreviewEnabled], isFalse);
  });

  testWidgets('按任务流展示输入、输出、重试、提醒四个小节', (tester) async {
    final storage = _MemoryLocalStorageService();
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await tester.pumpAndSettle();

    expect(find.text('输入'), findsOneWidget);
    expect(find.text('图像输出'), findsOneWidget);
    expect(find.text('失败重试'), findsOneWidget);
    expect(find.text('完成提醒'), findsOneWidget);
    expect(find.text('显示随机提示词工具'), findsOneWidget);
    expect(find.text('滚轮调整提示词权重'), findsOneWidget);
    expect(find.text('重试次数'), findsOneWidget);
    expect(find.text('重试间隔'), findsOneWidget);
    expect(find.text('完成音效'), findsOneWidget);
  });

  testWidgets('透明图像 Alpha 模式默认直通并可切换为预乘', (tester) async {
    final storage = _MemoryLocalStorageService();
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await tester.pumpAndSettle();

    final selector = find.byKey(const Key('settings-alpha-mode-selector'));
    expect(selector, findsOneWidget);
    expect(
      find.ancestor(of: selector, matching: find.byType(ListTile)),
      findsOneWidget,
    );
    expect(tester.widget<SegmentedButton<bool>>(selector).selected, {true});

    await tester.tap(find.text('预乘（Premultiplied）'));
    await tester.pumpAndSettle();

    expect(tester.widget<SegmentedButton<bool>>(selector).selected, {false});
    expect(storage.values[StorageKeys.imageStraightAlpha], isFalse);
    expect(find.textContaining('RGB 已乘 Alpha'), findsOneWidget);
  });

  testWidgets('透明图像 Alpha 选择器在窄布局中不会溢出', (tester) async {
    final storage = _MemoryLocalStorageService();
    await tester.binding.setSurfaceSize(const Size(360, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(24),
              child: SingleChildScrollView(child: GenerationSettingsSection()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('settings-alpha-mode-selector')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const Key('settings-alpha-mode-selector')),
        matching: find.byType(ListTile),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('音效开关关闭时隐藏自定义音效入口', (tester) async {
    final storage = _MemoryLocalStorageService();
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await tester.pumpAndSettle();

    expect(find.text('自定义音效'), findsOneWidget);

    await tester.tap(find.text('完成音效'));
    await tester.pumpAndSettle();

    expect(find.text('自定义音效'), findsNothing);
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
