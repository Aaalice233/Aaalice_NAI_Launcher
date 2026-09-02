import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/data/models/prompt/default_categories.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/tag_library.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_provider.dart';
import 'package:nai_launcher/presentation/screens/prompt_config/prompt_config_screen.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/preset_selector_bar.dart';

void main() {
  late Directory hiveDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    hiveDir = await Directory.systemTemp.createTemp('random_config_screen_');
    Hive.init(hiveDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('random config screen exposes completed management actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _ScreenTestRandomPresetNotifier.new,
          ),
          tagLibraryNotifierProvider.overrideWith(
            _ScreenTestTagLibraryNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PromptConfigScreen(),
        ),
      ),
    );

    await _pumpBounded(tester);

    expect(find.text('测试预设'), findsOneWidget);
    expect(find.text('全局人数设置'), findsOneWidget);
    expect(find.byTooltip('生成预览'), findsOneWidget);
    expect(find.byTooltip('更多操作'), findsOneWidget);
    expect(find.byTooltip('导入/导出'), findsNothing);

    await tester.tap(find.byTooltip('数据来源详情'));
    await _pumpBounded(tester);
    expect(find.text('Character Prompts：2456 条原始记录'), findsOneWidget);
    expect(find.text('5960 条记录，118 个原始数组'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await _pumpBounded(tester);

    await tester.tap(find.byType(DropdownButton<String>));
    await _pumpBounded(tester);

    await tester.tap(find.text('新建预设...').last);
    await _pumpBounded(tester);

    expect(find.text('创建新预设'), findsOneWidget);

    Navigator.of(tester.element(find.byType(PromptConfigScreen))).pop();
    await _pumpBounded(tester);

    await tester.tap(find.byTooltip('更多操作'));
    await _pumpBounded(tester);
    expect(find.text('导入/导出'), findsOneWidget);

    await tester.tap(find.text('导入/导出'));
    await _pumpBounded(tester);

    expect(find.text('导入预设'), findsOneWidget);
    expect(find.text('导出当前预设'), findsOneWidget);

    Navigator.of(tester.element(find.byType(PromptConfigScreen))).pop();
    await _pumpBounded(tester);

    await tester.ensureVisible(find.text('全局人数设置'));
    await tester.tap(find.text('全局人数设置'));
    await _pumpBounded(tester);

    expect(find.text('人数类别配置'), findsOneWidget);

    Navigator.of(tester.element(find.byType(PromptConfigScreen))).pop();
    await _pumpBounded(tester);

    expect(find.text('人数类别配置'), findsNothing);

    await tester.tap(find.byTooltip('生成预览'));
    await _pumpBounded(tester);

    expect(find.text('预览生成'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [
    320.0,
    400.0,
    420.0,
    600.0,
    700.0,
    840.0,
    1180.0,
    1600.0,
  ]) {
    testWidgets('random library remains usable at ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            randomPresetNotifierProvider.overrideWith(
              _ScreenTestRandomPresetNotifier.new,
            ),
            tagLibraryNotifierProvider.overrideWith(
              _ScreenTestTagLibraryNotifier.new,
            ),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PromptConfigScreen(),
          ),
        ),
      );
      await _pumpBounded(tester);

      expect(find.text('官网 · Character Prompts'), findsOneWidget);
      expect(find.byTooltip('数据来源详情'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      final searchHints = tester
          .widgetList<TextField>(find.byType(TextField))
          .map((field) => field.decoration?.hintText)
          .whereType<String>();
      expect(
        searchHints,
        contains(width < 1050 ? '搜索类别、词组或标签' : '搜索类别、词组或标签（Ctrl+F）'),
      );
      if (width < 840) {
        final heading = tester.getRect(
          find.byKey(const ValueKey('random-manager-heading-row')),
        );
        final selector = tester.getRect(
          find.byKey(const ValueKey('random-manager-mode-selector')),
        );
        final preview = tester.getRect(
          find.byKey(const ValueKey('random-manager-preview-action')),
        );
        final more = tester.getRect(
          find.byKey(const ValueKey('random-manager-more-actions')),
        );

        expect(selector.top, greaterThan(heading.bottom));
        final stacksControls = shouldStackWorkspacePresetControls(
          width - 40,
          1,
        );
        if (stacksControls) {
          expect(preview.top, greaterThan(selector.bottom));
        } else {
          expect((selector.center.dy - preview.center.dy).abs(), lessThan(1));
          expect(selector.width, greaterThan(preview.width));
        }
        expect(selector.height, greaterThanOrEqualTo(44));
        expect(preview.height, greaterThanOrEqualTo(44));
        expect(more.width, greaterThanOrEqualTo(44));
        expect(more.height, greaterThanOrEqualTo(44));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final textScale in [2.0, 3.0]) {
    for (final width in [320.0, 400.0, 600.0, 840.0]) {
      testWidgets(
        'workspace preset controls reflow at ${width.toInt()} px and ${textScale.toInt()}x text',
        (tester) async {
          tester.view.physicalSize = Size(width, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          var previewRequested = false;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                randomPresetNotifierProvider.overrideWith(
                  _ScreenTestRandomPresetNotifier.new,
                ),
              ],
              child: MaterialApp(
                locale: const Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: PresetSelectorBar(
                          showWorkspaceHeading: true,
                          onGeneratePreview: () => previewRequested = true,
                          onImportExport: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await _pumpBounded(tester);

          final selector = tester.getRect(
            find.byKey(const ValueKey('random-manager-mode-selector')),
          );
          final preview = tester.getRect(
            find.byKey(const ValueKey('random-manager-preview-action')),
          );
          final stacksControls = shouldStackWorkspacePresetControls(
            width - 24,
            textScale,
          );
          if (stacksControls) {
            expect(preview.top, greaterThan(selector.bottom));
          } else {
            expect((selector.center.dy - preview.center.dy).abs(), lessThan(1));
          }
          expect(find.byTooltip('更多操作'), findsOneWidget);
          await tester.tap(
            find.byKey(const ValueKey('random-manager-preview-action')),
          );
          expect(previewRequested, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('random library only wraps its primary action at extreme width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          randomPresetNotifierProvider.overrideWith(
            _ScreenTestRandomPresetNotifier.new,
          ),
          tagLibraryNotifierProvider.overrideWith(
            _ScreenTestTagLibraryNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PromptConfigScreen(),
        ),
      ),
    );
    await _pumpBounded(tester);

    final selector = tester.getRect(
      find.byKey(const ValueKey('random-manager-mode-selector')),
    );
    final preview = tester.getRect(
      find.byKey(const ValueKey('random-manager-preview-action')),
    );
    expect(preview.top, greaterThan(selector.bottom));
    expect(selector.height, greaterThanOrEqualTo(44));
    expect(preview.height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpBounded(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _ScreenTestRandomPresetNotifier extends RandomPresetNotifier {
  @override
  RandomPresetState build() {
    return RandomPresetState(
      presets: [_defaultPreset, _customPreset],
      selectedPresetId: _customPreset.id,
    );
  }
}

class _ScreenTestTagLibraryNotifier extends TagLibraryNotifier {
  @override
  TagLibraryState build() => TagLibraryState(library: _testLibrary);
}

final _defaultPreset = RandomPreset(
  id: 'default',
  name: '默认预设',
  isDefault: true,
  categories: DefaultCategories.createDefault(),
);

final _customPreset = RandomPreset(
  id: 'custom',
  name: '测试预设',
  categories: DefaultCategories.createDefault(),
);

final _testLibrary = TagLibrary(
  id: 'test-catalog',
  name: 'Test catalog',
  lastUpdated: DateTime.utc(2026),
  source: TagLibrarySource.catalog,
  dataVersion: 'test-v1',
  sourceUrl: 'https://example.com/catalog.csv',
  sourceCommit: 'abc123',
  sourceLicense: 'Unlicense',
  sourceVersionDate: DateTime.utc(2026),
  sourceCatalogTagCount: 221787,
  sourceCatalogAliasCount: 71504,
  categories: const {},
);
