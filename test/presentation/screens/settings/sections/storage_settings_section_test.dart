import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/autocomplete/cooccurrence_data_pack_provider.dart';
import 'package:nai_launcher/core/autocomplete/cooccurrence_data_pack_service.dart';
import 'package:nai_launcher/core/cache/gallery_cache_manager.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
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
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    await Hive.box(StorageKeys.settingsBox).clear();
    storage = _MemoryLocalStorageService({
      StorageKeys.onnxTaggerModelDirectory: r'C:\models\onnx_tagger',
    });
  });

  tearDown(() {
    PlatformCapabilities.debugOverride = null;
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
      of: find.text('本地 ONNX tagger 模型'),
      matching: find.byType(ListTile),
    );

    expect(onnxTile, findsOneWidget);
    expect(
      find.descendant(of: onnxTile, matching: find.byTooltip('打开文件夹')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Android ONNX import does not hide extensions behind MIME filters',
    (tester) async {
      FilePicker? originalFilePicker;
      try {
        originalFilePicker = FilePicker.platform;
      } catch (_) {
        originalFilePicker = null;
      }
      final filePicker = _RecordingFilePicker();
      FilePicker.platform = filePicker;
      addTearDown(() {
        if (originalFilePicker != null) {
          FilePicker.platform = originalFilePicker;
        }
      });
      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.android,
      );

      await tester.pumpWidget(_buildSubject(storage));
      await tester.pump();

      final importButton = find.byTooltip('导入 ONNX 模型、标签文件或 ZIP 压缩包');
      expect(importButton, findsOneWidget);
      await tester.tap(importButton);
      await tester.pump();

      expect(filePicker.type, FileType.any);
      expect(filePicker.allowedExtensions, isNull);
      expect(filePicker.allowMultiple, isTrue);
    },
  );

  testWidgets('聚焦数据与存储：保护模式移出，数据源缓存迁入', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildSubject(storage));
    await tester.pump();

    expect(find.text('图片保存位置'), findsOneWidget);
    expect(find.text('自动保存'), findsOneWidget);
    expect(find.text('点击标签时显示补全'), findsOneWidget);
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

  testWidgets('存储入口在 320–1600 宽度和 3x 文本下无布局溢出', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in const [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
      await tester.binding.setSurfaceSize(Size(width, 1400));
      await tester.pumpWidget(_buildSubject(storage, textScale: 3));
      await tester.pump();

      expect(find.text('图片保存位置'), findsOneWidget);
      expect(find.text('本地 ONNX tagger 模型'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });

  testWidgets('删除共现数据在 320、3x、IME 与 SafeArea 下使用全屏表单', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.reset);
    final service = _ReadyCooccurrenceService(tempDir);

    await tester.pumpWidget(
      _buildSubject(
        storage,
        textScale: 3,
        cooccurrenceService: service,
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
        viewInsets: const EdgeInsets.only(bottom: 220),
      ),
    );
    await tester.pump();

    final remove = find.byTooltip('移除');
    expect(remove, findsOneWidget);
    await tester.ensureVisible(remove);
    await tester.pump();
    await tester.tap(remove);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final form = find.byKey(const ValueKey('adaptive-full-screen-form'));
    expect(form, findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    final rect = tester.getRect(form);
    expect(rect.top, greaterThanOrEqualTo(24));
    expect(rect.bottom, lessThanOrEqualTo(568 - 220));
    final formScroll = find
        .descendant(of: form, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.byType(CheckboxListTile),
      100,
      scrollable: formScroll,
    );
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('数据源缓存卡片与主设置卡片宽度一致', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildSubject(storage));
    await tester.pump();
    await tester.pump();

    final settingsCards = find.byType(SettingsCard);
    expect(settingsCards, findsNWidgets(6));

    final primaryRect = tester.getRect(settingsCards.first);
    for (var index = 1; index < 6; index++) {
      final sectionRect = tester.getRect(settingsCards.at(index));
      expect(sectionRect.left, primaryRect.left);
      expect(sectionRect.right, primaryRect.right);
      expect(sectionRect.width, primaryRect.width);
    }
  });
}

Widget _buildSubject(
  _MemoryLocalStorageService storage, {
  double textScale = 1,
  CooccurrenceDataPackService? cooccurrenceService,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
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
      if (cooccurrenceService != null)
        cooccurrenceDataPackServiceProvider.overrideWith(
          (ref) => cooccurrenceService,
        ),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: padding,
          viewPadding: padding,
          viewInsets: viewInsets,
        ),
        child: child!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(child: StorageSettingsSection()),
      ),
    ),
  );
}

class _ReadyCooccurrenceService extends CooccurrenceDataPackService {
  _ReadyCooccurrenceService(Directory directory)
    : super(supportDirectoryLoader: () async => directory) {
    state = const CooccurrenceDataPackState(
      status: CooccurrenceDataPackStatus.ready,
      installedVersion: 'test',
      relationCount: 1,
      diskBytes: 1,
    );
  }

  @override
  Future<void> deleteData() async {
    state = const CooccurrenceDataPackState();
  }
}

class _RecordingFilePicker extends FilePicker {
  FileType? type;
  List<String>? allowedExtensions;
  bool? allowMultiple;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    this.type = type;
    this.allowedExtensions = allowedExtensions;
    this.allowMultiple = allowMultiple;
    return null;
  }
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
