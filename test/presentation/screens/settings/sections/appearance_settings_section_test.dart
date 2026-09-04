import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/font_provider.dart';
import 'package:nai_launcher/presentation/providers/font_scale_provider.dart';
import 'package:nai_launcher/presentation/providers/generation_layout_mode_provider.dart';
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

  testWidgets('外观分类不再显示已移除的悬浮球设置', (tester) async {
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

    expect(find.text('生成页布局'), findsOneWidget);
    expect(find.text('悬浮球背景'), findsNothing);
    expect(find.text('外观'), findsOneWidget);
  });

  for (final width in [320.0, 600.0, 840.0, 1600.0]) {
    testWidgets('外观设置在 ${width.toInt()} 宽度与放大文本下无溢出', (tester) async {
      tester.view.physicalSize = Size(width, width == 320 ? 420 : 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 320 ? 3 : 1)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(child: AppearanceSettingsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('外观'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('短高度与 3x 文本下布局选择弹窗可滚动', (tester) async {
    tester.view.physicalSize = const Size(320, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(3)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: AppearanceSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('生成页布局').first);
    await tester.tap(find.text('生成页布局').first);
    await tester.pumpAndSettle();

    expect(find.byType(RadioGroup<GenerationLayoutMode>), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final formFactor in [
    (width: 700.0, surface: 'adaptive-bottom-sheet'),
    (width: 1200.0, surface: 'adaptive-centered-form'),
  ]) {
    testWidgets(
      '字体选择与缩放在 ${formFactor.width.toInt()} 宽度使用 ${formFactor.surface}',
      (tester) async {
        tester.view.physicalSize = Size(formFactor.width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWith((ref) => _FakeStorage()),
            ],
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

        await tester.tap(find.text('字体').first);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(formFactor.surface)), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        await tester.tap(find.text('字体大小').first);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey(formFactor.surface)), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('异步字体选择器使用自适应表单并保持选择即保存与取消语义', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    const selectedFont = FontConfig(
      displayName: '最坏组合下仍可选择的超长测试字体名称',
      fontFamily: 'Worst Case Test Font',
      source: FontSource.system,
    );
    final storage = _FakeStorage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => storage),
          allFontsProvider.overrideWith(
            (ref) async => {
              '包含很多异步字体的超长分组名称': [FontConfig.defaultFont, selectedFont],
            },
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(3),
              viewInsets: const EdgeInsets.only(bottom: 160),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: AppearanceSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('字体').first);
    await tester.tap(find.text('字体').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppearanceSettingsSection)),
    );
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(container.read(fontNotifierProvider), FontConfig.defaultFont);
    expect(storage.fontFamily, FontConfig.defaultFont.key);

    await tester.tap(find.text('字体').first);
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    final panelScrollable = find.descendant(
      of: panel,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text(selectedFont.displayName),
      120,
      scrollable: panelScrollable,
    );
    await tester.drag(panelScrollable, const Offset(0, -50));
    await tester.pumpAndSettle();
    await tester.tap(find.text(selectedFont.displayName));
    await tester.pumpAndSettle();

    expect(container.read(fontNotifierProvider), selectedFont);
    expect(storage.fontFamily, selectedFont.key);
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsNothing);
  });

  testWidgets('字体缩放自适应编辑器在窄屏、3x 字号和 IME 下实时保存', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    final storage = _FakeStorage();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(3),
              viewInsets: const EdgeInsets.only(bottom: 160),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: AppearanceSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('字体大小').first);
    await tester.tap(find.text('字体大小').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);

    final panel = find.byKey(const ValueKey('adaptive-bottom-sheet'));
    final panelScrollable = find.descendant(
      of: panel,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byType(Slider),
      120,
      scrollable: panelScrollable,
    );
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(1.5);
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppearanceSettingsSection)),
    );
    expect(container.read(fontScaleNotifierProvider), 1.5);

    await tester.scrollUntilVisible(
      find.text('完成'),
      120,
      scrollable: panelScrollable,
    );
    await tester.drag(panelScrollable, const Offset(0, -50));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(container.read(fontScaleNotifierProvider), 1.5);
    expect(storage.fontScale, 1.5);
    expect(tester.takeException(), isNull);
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
  String fontFamily = FontConfig.defaultFont.key;
  double fontScale = 1;

  @override
  String getFontFamily() => fontFamily;

  @override
  Future<void> setFontFamily(String value) async {
    fontFamily = value;
  }

  @override
  double getFontScale() => fontScale;

  @override
  Future<void> setFontScale(double value) async {
    fontScale = value;
  }

  @override
  String getHistoryClickBehavior() => behavior;

  @override
  Future<void> setHistoryClickBehavior(String value) async {
    behavior = value;
  }
}
