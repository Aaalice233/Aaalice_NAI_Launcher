import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/data/models/prompt/default_categories.dart';
import 'package:nai_launcher/data/models/prompt/random_category.dart';
import 'package:nai_launcher/data/models/prompt/random_preset.dart';
import 'package:nai_launcher/data/models/prompt/tag_library.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/random_preset_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_provider.dart';
import 'package:nai_launcher/presentation/screens/prompt_config/prompt_config_screen.dart';
import 'package:nai_launcher/presentation/themes/app_theme.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_manager/category_card.dart';
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
    expect(
      find.byKey(const ValueKey('random-manager-preview-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('random-manager-preview-action')),
      findsNothing,
    );
    expect(find.byTooltip('关闭'), findsNothing);
    expect(find.byTooltip('更多操作'), findsOneWidget);
    expect(find.byTooltip('导入/导出'), findsNothing);

    expect(find.byTooltip('数据来源详情'), findsNothing);

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

    expect(find.text('输出预览'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '生成样例'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Grunge 暗色主题下工作区卡片与画布保持可见层级', (tester) async {
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
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.getTheme(AppStyle.grungeCollage, Brightness.dark),
          home: const PromptConfigScreen(),
        ),
      ),
    );
    await _pumpBounded(tester);

    final surface = Theme.of(
      tester.element(find.byType(PromptConfigScreen)),
    ).colorScheme.surface;
    Color decorationColor(Finder finder) =>
        (tester.widget<Container>(finder).decoration! as BoxDecoration).color!;

    expect(
      decorationColor(
        find.byKey(const ValueKey('random-manager-overview-card')),
      ),
      isNot(surface),
    );
    expect(
      decorationColor(
        find.byKey(const ValueKey('random-manager-algorithm-card')),
      ),
      isNot(surface),
    );
    expect(
      decorationColor(
        find.byKey(const ValueKey('random-manager-preview-panel')),
      ),
      isNot(surface),
    );
    final category = tester.widget<CategoryCard>(
      find.byType(CategoryCard).first,
    );
    expect(
      decorationColor(
        find.byKey(ValueKey('random-manager-category-${category.category.id}')),
      ),
      isNot(surface),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('官网预设统计锁定的官方词库而不是完整 catalog', (tester) async {
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

    await tester.tap(find.byType(DropdownButton<String>));
    await _pumpBounded(tester);
    await tester.tap(find.text('NovelAI 官网预设').last);
    await _pumpBounded(tester);

    expect(find.text('118'), findsOneWidget);
    expect(find.text('5960'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blank preset exposes a complete create and edit path', (
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

    await tester.tap(find.byType(DropdownButton<String>));
    await _pumpBounded(tester);
    await tester.tap(find.text('新建预设...').last);
    await _pumpBounded(tester);
    await tester.enterText(find.byType(TextField).last, '空白预设');
    await tester.tap(find.text('完全空白'));
    await tester.tap(find.text('创建'));
    await _pumpBounded(tester);

    expect(find.text('空白预设'), findsOneWidget);
    expect(find.text('暂无类别'), findsOneWidget);
    expect(find.text('点击“新增类别”开始配置'), findsOneWidget);
    expect(find.text('新增类别'), findsOneWidget);

    await tester.tap(find.text('新增类别'));
    await _pumpBounded(tester);
    final categoryNameField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == '输入类别名称',
    );
    expect(categoryNameField, findsOneWidget);
    await tester.enterText(categoryNameField, '发色');
    await tester.pump();
    final createCategoryButton = find.widgetWithText(FilledButton, '确定').last;
    expect(
      tester.widget<FilledButton>(createCategoryButton).onPressed,
      isNotNull,
    );
    await tester.tap(createCategoryButton);
    await _pumpBounded(tester);

    expect(find.text('创建新类别'), findsNothing);
    expect(find.byType(CategoryCard), findsOneWidget);
    expect(find.text('发色'), findsOneWidget);
    await tester.tap(
      find
          .descendant(
            of: find.byType(CategoryCard),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await _pumpBounded(tester);
    expect(find.text('添加词组'), findsOneWidget);

    await tester.tap(find.byTooltip('更多操作'));
    await _pumpBounded(tester);
    expect(find.text('重命名'), findsOneWidget);
    await tester.tap(find.text('重命名'));
    await _pumpBounded(tester);
    final presetNameField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '预设名称',
    );
    expect(presetNameField, findsOneWidget);
    await tester.enterText(presetNameField, '已命名预设');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await _pumpBounded(tester);

    expect(find.text('已命名预设'), findsOneWidget);
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

      expect(find.byIcon(Icons.casino_outlined), findsOneWidget);
      expect(find.text('用完整离线 catalog 组合可复用的随机生成配方'), findsNothing);
      expect(find.text('适用于 V4/V5 的 catalog 扩展预设，支持多角色'), findsNothing);
      expect(find.byTooltip('数据来源详情'), findsNothing);
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('新增类别'), findsOneWidget);
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
          find.byKey(const ValueKey('random-manager-preset-selector')),
        );
        final more = tester.getRect(
          find.byKey(const ValueKey('random-manager-more-actions')),
        );

        expect(selector.top, greaterThan(heading.bottom));
        expect(selector.height, greaterThanOrEqualTo(44));
        expect(more.width, greaterThanOrEqualTo(44));
        expect(more.height, greaterThanOrEqualTo(44));
      }
      if (width >= 1050) {
        final title = tester.getRect(find.text('随机词库'));
        final selector = tester.getRect(
          find.byKey(const ValueKey('random-manager-preset-selector')),
        );
        expect(selector.left - title.right, 12);
      }
      if (width < 1050) {
        expect(
          find.byKey(const ValueKey('random-manager-compact-sections')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('random-manager-preview-panel')),
          findsNothing,
        );
        await tester.tap(find.text('输出预览'));
        await _pumpBounded(tester);
      }
      expect(
        find.byKey(const ValueKey('random-manager-preview-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('random-manager-preview-action')),
        findsNothing,
      );
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
            find.byKey(const ValueKey('random-manager-preset-selector')),
          );
          final heading = tester.getRect(
            find.byKey(const ValueKey('random-manager-heading-row')),
          );
          expect(selector.top, greaterThan(heading.bottom));
          expect(find.byTooltip('更多操作'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('random-manager-preview-action')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('random library keeps the resident preview at extreme width', (
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
      find.byKey(const ValueKey('random-manager-preset-selector')),
    );
    expect(selector.height, greaterThanOrEqualTo(44));
    expect(
      find.byKey(const ValueKey('random-manager-preview-panel')),
      findsNothing,
    );
    await tester.tap(find.text('输出预览'));
    await _pumpBounded(tester);
    expect(
      find.byKey(const ValueKey('random-manager-preview-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('random-manager-preview-action')),
      findsNothing,
    );
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

  @override
  Future<RandomPreset> createPreset({
    required String name,
    String? description,
    bool copyFromCurrent = true,
  }) async {
    final current = state.selectedPreset;
    final preset = copyFromCurrent && current != null
        ? RandomPreset.copyFrom(current, name: name)
        : RandomPreset(
            id: 'created-preset',
            name: name,
            description: description,
          );
    state = state.copyWith(
      presets: [...state.presets, preset],
      selectedPresetId: preset.id,
    );
    return preset;
  }

  @override
  Future<void> selectPreset(String id) async {
    state = state.copyWith(selectedPresetId: id);
  }

  @override
  Future<void> addCategory(RandomCategory category) async {
    final selected = state.selectedPreset;
    if (selected == null) return;
    _replacePreset(selected.addCategory(category));
  }

  @override
  Future<void> renamePreset(String id, String newName) async {
    final index = state.presets.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _replacePreset(state.presets[index].copyWith(name: newName));
  }

  void _replacePreset(RandomPreset preset) {
    state = state.copyWith(
      presets: [
        for (final item in state.presets)
          if (item.id == preset.id) preset else item,
      ],
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
