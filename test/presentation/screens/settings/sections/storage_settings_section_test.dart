import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:nai_launcher/core/services/file_export_service.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/local_onnx_model_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/data_source_cache_provider.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/storage_settings_section.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/cache_statistics_tile.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/data_source_cache_settings.dart';
import 'package:nai_launcher/presentation/screens/settings/widgets/settings_card.dart';
import 'package:path/path.dart' as p;
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

  testWidgets('iOS 保留「文件」App 投放路径提示与跳转入口，三处路径只读', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.iOS,
    );

    await tester.pumpWidget(_buildSubject(storage));
    await tester.pump();
    await tester.pump();

    final onnxTile = find.ancestor(
      of: find.text('本地 ONNX tagger 模型'),
      matching: find.byType(ListTile),
    );
    // 空态必须讲清「文件」App 的投放路径，而不是上游那句只提应用内导入的文案。
    expect(
      find.descendant(
        of: onnxTile,
        matching: find.textContaining('tagger_models'),
      ),
      findsOneWidget,
    );
    // 上游在自管导入分支里没有任何打开目录的按钮，iOS 必须补回 shareddocuments 入口。
    final openFolder = find.byTooltip('打开文件夹');
    expect(openFolder, findsOneWidget);
    expect(find.descendant(of: onnxTile, matching: openFolder), findsOneWidget);
    // 图片保存路径 / Vibe 库路径 / Hive 路径三处都只读，且用 iOS 而非 Android 文案。
    expect(find.textContaining('沙盒'), findsNWidgets(3));
    expect(find.textContaining('由系统安全管理'), findsNothing);
  });

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

  testWidgets('删除共现数据在 320、3x、IME 与 SafeArea 下使用全高 bottom sheet', (
    tester,
  ) async {
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

    final form = find.byKey(const ValueKey('adaptive-bottom-sheet'));
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

    // 6 张上游卡片 + 我们增量的「配置备份」无标题卡片。
    final settingsCards = find.byType(SettingsCard);
    expect(settingsCards, findsNWidgets(7));

    final primaryRect = tester.getRect(settingsCards.first);
    for (var index = 1; index < 7; index++) {
      final sectionRect = tester.getRect(settingsCards.at(index));
      expect(sectionRect.left, primaryRect.left);
      expect(sectionRect.right, primaryRect.right);
      expect(sectionRect.width, primaryRect.width);
    }
  });
  // ===== 配置导出/导入（上游没有的增量入口，服务层见 LocalStorageService）=====

  testWidgets('导出配置写出带版本信封的 JSON，并统一走 FileExportService', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // Hive 落盘同样是真实 I/O，必须在 runAsync 里完成。
    await tester.runAsync(
      () => Hive.box(StorageKeys.settingsBox).put(StorageKeys.themeType, 3),
    );
    final outputPath =
        '${tempDir.path}${Platform.pathSeparator}exported_config.json';
    final picker = _ConfigFilePicker(saveFilePath: outputPath);
    _installFilePicker(picker);
    // 固定成桌面分支，这样在 macOS CI 上也走「另存为对话框」这条可观测路径。
    FileExportService.debugPlatformOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    addTearDown(() => FileExportService.debugPlatformOverride = null);

    await tester.pumpWidget(_buildSubject(storage));
    await tester.pump();

    // 真实落盘走真实事件循环，必须在 runAsync 里完成。
    await tester.runAsync(() async {
      await tester.tap(find.text('导出配置'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(picker.saveFileExtensions, const ['json']);
    final written = await tester.runAsync(
      () => File(outputPath).readAsString(),
    );
    final decoded = jsonDecode(written!) as Map<String, dynamic>;
    expect(decoded['formatVersion'], settingsExportFormatVersion);
    expect(decoded['exportedAt'], isA<String>());
    expect(
      (decoded['settings'] as Map)[StorageKeys.themeType],
      3,
      reason: '导出内容必须来自真实设置，而不是空壳文档',
    );
    expect(find.text('配置已导出'), findsOneWidget);
  });

  testWidgets('导入配置先确认，再按白名单过滤并如实报告采纳条数', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final box = Hive.box(StorageKeys.settingsBox);
    final importPath =
        '${tempDir.path}${Platform.pathSeparator}import_config.json';
    await tester.runAsync(
      () => File(importPath).writeAsString(
        jsonEncode({
          'formatVersion': settingsExportFormatVersion,
          'exportedAt': '2026-01-01T00:00:00.000',
          'settings': {
            StorageKeys.themeType: 4,
            // 白名单之外的设备本地值，必须被跳过。
            'not_a_portable_key_v1': 'device-local',
          },
        }),
      ),
    );
    _installFilePicker(_ConfigFilePicker(pickFilePath: importPath));

    await tester.pumpWidget(_buildSubject(storage));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('导入配置'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    // 导入会覆盖本机现有值，写回前必须有一次明确确认。
    expect(find.text('确认覆盖本机设置？'), findsOneWidget);
    expect(box.get(StorageKeys.themeType), isNull);

    await tester.tap(find.text('确定'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(box.get(StorageKeys.themeType), 4);
    expect(box.get('not_a_portable_key_v1'), isNull);
    // 计数是白名单在工作的唯一用户可见证据。
    expect(find.text('配置已导入: 1/2'), findsOneWidget);
  });

  testWidgets('导入更新格式的文件时，确认弹窗追加一行提醒', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final importPath =
        '${tempDir.path}${Platform.pathSeparator}import_newer_config.json';
    await tester.runAsync(
      () => File(importPath).writeAsString(
        jsonEncode({
          'formatVersion': settingsExportFormatVersion + 1,
          'settings': {StorageKeys.themeType: 4},
        }),
      ),
    );
    _installFilePicker(_ConfigFilePicker(pickFilePath: importPath));

    await tester.pumpWidget(_buildSubject(storage));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('导入配置'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('该文件来自更新版本的应用'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      Hive.box(StorageKeys.settingsBox).get(StorageKeys.themeType),
      isNull,
    );
  });
}

void _installFilePicker(FilePicker picker) {
  FilePicker? original;
  try {
    original = FilePicker.platform;
  } catch (_) {
    original = null;
  }
  FilePicker.platform = picker;
  addTearDown(() {
    if (original != null) FilePicker.platform = original;
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

/// 配置导出/导入用的假 FilePicker：导出记录另存为参数并返回固定落地路径，
/// 导入返回一份预置的 JSON 文件。
class _ConfigFilePicker extends FilePicker {
  _ConfigFilePicker({this.saveFilePath, this.pickFilePath});

  final String? saveFilePath;
  final String? pickFilePath;
  List<String>? saveFileExtensions;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    saveFileExtensions = allowedExtensions;
    return saveFilePath;
  }

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
    final path = pickFilePath;
    if (path == null) return null;
    return FilePickerResult([
      PlatformFile(path: path, name: p.basename(path), size: 0),
    ]);
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
