import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/history_click_behavior_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/appearance_settings_section.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('appearance_settings_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('外观分类包含悬浮球背景设置', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: AppearanceSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 原有项仍在
    expect(find.text('生成页布局'), findsOneWidget);
    // 自队列迁入的悬浮球背景
    expect(find.text('悬浮球背景'), findsOneWidget);
  });

  testWidgets('历史点击行为默认经典并可从外观设置切换和持久化', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = _FakeStorage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: AppearanceSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppearanceSettingsSection)),
    );

    expect(find.text('历史记录点击行为'), findsOneWidget);
    expect(find.text('经典'), findsOneWidget);
    expect(
      container.read(historyClickBehaviorNotifierProvider),
      HistoryClickBehavior.openDetail,
    );

    await tester.tap(find.text('历史记录点击行为'));
    await tester.pumpAndSettle();

    expect(find.text('单击历史图片直接打开详情'), findsOneWidget);
    expect(find.textContaining('单击切换中央预览'), findsOneWidget);
    final group = tester.widget<RadioGroup<HistoryClickBehavior>>(
      find.byType(RadioGroup<HistoryClickBehavior>),
    );
    expect(group.groupValue, HistoryClickBehavior.openDetail);

    await tester.tap(find.text('官网式联动'));
    await tester.pumpAndSettle();

    expect(
      container.read(historyClickBehaviorNotifierProvider),
      HistoryClickBehavior.selectPreview,
    );
    expect(storage.behavior, 'select_preview');
  });
}

class _FakeStorage extends LocalStorageService {
  String behavior = 'open_detail';

  @override
  String getHistoryClickBehavior() => behavior;

  @override
  Future<void> setHistoryClickBehavior(String value) async {
    behavior = value;
  }
}
