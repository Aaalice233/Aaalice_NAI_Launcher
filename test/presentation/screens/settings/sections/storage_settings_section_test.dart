import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/local_onnx_model_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/data_source_cache_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/storage_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/cache_statistics_tile.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/data_source_cache_settings.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_card.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _MemoryLocalStorageService storage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'storage_settings_section_test_',
    );
    final documentsDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}documents',
    ).create();
    final appSupportDir = await Directory(
      '${tempDir.path}${Platform.pathSeparator}app_support',
    ).create();
    PathProviderPlatform.instance = _TestPathProviderPlatform(
      documentsPath: documentsDir.path,
      appSupportPath: appSupportDir.path,
    );
    Hive.init('${tempDir.path}${Platform.pathSeparator}hive');
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
    storage = _MemoryLocalStorageService({
      StorageKeys.onnxTaggerModelDirectory: r'C:\models\onnx_tagger',
    });
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('local ONNX tagger path tile exposes an open-folder button', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject(storage));
    await tester.pump();

    final onnxTile = find.ancestor(
      of: find.text('本地 ONNX tagger 模型文件夹'),
      matching: find.byType(ListTile),
    );

    expect(onnxTile, findsOneWidget);
    expect(
      find.descendant(of: onnxTile, matching: find.byTooltip('打开文件夹')),
      findsOneWidget,
    );
  });

  testWidgets('聚焦数据与存储：保护模式移出，数据源缓存迁入', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildSubject(storage));
    await tester.pump();

    expect(find.text('图片保存位置'), findsOneWidget);
    expect(find.text('自动保存'), findsOneWidget);
    expect(
      <String, int>{
        '数据与存储标题': find.text('数据与存储').evaluate().length,
        '保护模式标题': find.text('保护模式').evaluate().length,
        '移除元数据子项': find.text('复制/拖拽时移除全部元数据').evaluate().length,
        'DataSourceCacheSettings': find
            .byType(DataSourceCacheSettings)
            .evaluate()
            .length,
      },
      <String, int>{
        '数据与存储标题': 1,
        '保护模式标题': 0,
        '移除元数据子项': 0,
        'DataSourceCacheSettings': 1,
      },
    );
  });

  testWidgets('数据源缓存卡片与主设置卡片宽度一致', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildSubject(storage));
    await tester.pump();
    await tester.pump();

    final settingsCards = find.byType(SettingsCard);
    expect(settingsCards, findsNWidgets(2));

    final primaryRect = tester.getRect(settingsCards.at(0));
    final cacheRect = tester.getRect(settingsCards.at(1));

    expect(cacheRect.left, primaryRect.left);
    expect(cacheRect.right, primaryRect.right);
    expect(cacheRect.width, primaryRect.width);
  });
}

Widget _buildSubject(_MemoryLocalStorageService storage) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWith((ref) => storage),
      localOnnxModelServiceProvider.overrideWith(
        (ref) => LocalOnnxModelService(storage),
      ),
      cacheStatisticsProvider.overrideWith(
        (ref) async => CacheStatistics(
          l1MemorySize: 0,
          l1HitRate: 0,
          l1MemoryBytes: 0,
          l2HiveSize: 0,
          l2HitRate: 0,
          l2HiveBytes: 0,
          l3DatabaseImageCount: 0,
          l3DatabaseMetadataCount: 0,
          totalHitRate: 0,
          lastUpdated: DateTime(2026),
        ),
      ),
      danbooruTagsCacheNotifierProvider.overrideWith(
        _TestDanbooruTagsCacheNotifier.new,
      ),
    ],
    child: const MaterialApp(
      locale: Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: StorageSettingsSection()),
      ),
    ),
  );
}

class _TestDanbooruTagsCacheNotifier extends DanbooruTagsCacheNotifier {
  @override
  Future<DanbooruTagsCacheState> build() async {
    return const DanbooruTagsCacheState();
  }
}

class _MemoryLocalStorageService extends LocalStorageService {
  _MemoryLocalStorageService(this.values);

  final Map<String, Object?> values;

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    return values.containsKey(key) ? values[key] as T? : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    values.remove(key);
  }

  @override
  String? getImageSavePath() {
    return getSetting<String>(StorageKeys.imageSavePath);
  }

  @override
  bool getAutoSaveImages() {
    return getSetting<bool>(StorageKeys.autoSaveImages, defaultValue: false) ??
        false;
  }
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform({
    required this.documentsPath,
    required this.appSupportPath,
  });

  final String documentsPath;
  final String appSupportPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => appSupportPath;
}
