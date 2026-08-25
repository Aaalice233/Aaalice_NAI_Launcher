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
    expect(find.byTooltip('导入/导出'), findsOneWidget);

    await tester.tap(find.byTooltip('数据来源详情'));
    await _pumpBounded(tester);
    expect(
      find.textContaining('https://example.com/catalog.csv'),
      findsOneWidget,
    );
    expect(find.textContaining('221787'), findsOneWidget);
    await tester.tap(find.text('关闭'));
    await _pumpBounded(tester);

    await tester.tap(find.byType(DropdownButton<String>));
    await _pumpBounded(tester);

    await tester.tap(find.text('新建预设...').last);
    await _pumpBounded(tester);

    expect(find.text('创建新预设'), findsOneWidget);

    Navigator.of(tester.element(find.byType(PromptConfigScreen))).pop();
    await _pumpBounded(tester);

    await tester.tap(find.byTooltip('导入/导出'));
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

  for (final width in [700.0, 840.0, 1180.0, 1600.0]) {
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

      expect(find.text('已验证的离线随机词库'), findsOneWidget);
      expect(find.byTooltip('数据来源详情'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
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
