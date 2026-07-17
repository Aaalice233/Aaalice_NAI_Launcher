import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'package:timeago/timeago.dart' as timeago;

import 'core/constants/app_version.dart';
import 'core/constants/storage_keys.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_en.dart';
import 'l10n/app_localizations_ja.dart';
import 'l10n/app_localizations_zh.dart';
import 'core/network/proxy_service.dart';
import 'core/network/system_proxy_http_overrides.dart';
import 'core/shortcuts/shortcut_storage.dart';
import 'core/database/database_manager.dart';
import 'core/services/data_migration_service.dart';
import 'core/services/sqflite_bootstrap_service.dart';
import 'core/utils/app_error_reporter.dart';
import 'core/utils/fatal_diagnostics.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/hive_startup_box_opener.dart';
import 'core/utils/hive_storage_helper.dart';
import 'core/utils/window_focus_tracker.dart';
import 'core/utils/window_state_coercion.dart';
import 'core/utils/window_state_persistence.dart';
import 'data/datasources/local/nai_tags_data_source.dart';
import 'data/models/gallery/nai_image_metadata.dart';
import 'data/repositories/collection_repository.dart';
import 'data/repositories/gallery_folder_repository.dart';
import 'core/cache/gallery_cache_manager.dart';

import 'core/cache/tag_cache_service.dart';
import 'data/services/gallery/index.dart';
import 'data/services/image_metadata_service.dart';
import 'data/services/metadata/isolate_metadata_service.dart';
import 'data/services/search_index_service.dart';
import 'data/services/temp_image_service.dart';
import 'data/services/thumbnail_service.dart';
import 'presentation/providers/data_source_cache_provider.dart';
import 'presentation/providers/online_gallery_blacklist_provider.dart';
import 'presentation/screens/splash/app_bootstrap.dart';

/// Get localized strings based on the stored locale setting
/// Used in main() before the app is initialized
AppLocalizations _getLocalizedStrings() {
  final box = Hive.box(StorageKeys.settingsBox);
  final localeCode = box.get(StorageKeys.locale, defaultValue: 'zh') as String;
  switch (localeCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    default:
      return AppLocalizationsZh();
  }
}

Future<void> _openHiveBoxIfNeeded<E>(String name, {String? hivePath}) async {
  if (!Hive.isBoxOpen(name)) {
    await HiveStartupBoxOpener.openBox<E>(name, hivePath: hivePath);
  }
}

Future<void> _runNonFatalStartupStep(
  String name,
  Future<void> Function() action,
) async {
  final stopwatch = Stopwatch()..start();
  try {
    await action();
  } catch (e, stackTrace) {
    AppLogger.e(
      '$name failed after ${stopwatch.elapsedMilliseconds}ms; continuing startup',
      e,
      stackTrace,
      'Main',
    );
    return;
  }

  AppLogger.i(
    '$name completed in ${stopwatch.elapsedMilliseconds}ms',
    'Startup',
  );
}

void _runDeferredStartupStep(String name, Future<void> Function() action) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_runNonFatalStartupStep(name, action));
  });
}

Future<WindowStateSnapshot> _saveCurrentWindowState() async {
  final snapshot = WindowStateSnapshot(
    size: await windowManager.getSize(),
    position: await windowManager.getPosition(),
  );
  final box = Hive.box(StorageKeys.settingsBox);
  await persistWindowStateSnapshot(
    put: (key, value) => box.put(key, value),
    snapshot: snapshot,
  );
  return snapshot;
}

/// 窗口状态观察者，用于保存窗口位置和大小
class WindowStateObserver extends WidgetsBindingObserver {
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    // 仅在桌面端保存窗口状态
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }

    // 应用暂停或即将退出时保存窗口状态
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      try {
        final snapshot = await _saveCurrentWindowState();

        AppLogger.i(
          'Window state saved: ${snapshot.size.width}x${snapshot.size.height} at (${snapshot.position.dx}, ${snapshot.position.dy})',
          'Main',
        );
        await AppLogger.flush();
      } catch (e) {
        AppLogger.e('Failed to save window state: $e', 'Main');
      }
    }
  }
}

/// 系统托盘监听器，处理托盘图标交互
class AppTrayListener extends TrayListener {
  @override
  Future<void> onTrayIconMouseDown() async {
    // 左键点击托盘图标 - 恢复窗口
    try {
      await windowManager.show();
      await windowManager.focus();
      AppLogger.d('Window restored from tray (left click)', 'TrayListener');
    } catch (e) {
      AppLogger.e('Failed to restore window from tray: $e', 'TrayListener');
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    // 右键点击托盘图标 - 显示上下文菜单 (Windows)
    trayManager.popUpContextMenu();
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    try {
      if (menuItem.key == 'show') {
        // 显示窗口
        await windowManager.show();
        await windowManager.focus();
        AppLogger.d('Window shown via tray menu', 'TrayListener');
      } else if (menuItem.key == 'exit') {
        // 退出应用（真正关闭）
        AppLogger.i('Application exiting, closing database...', 'TrayListener');

        // 1. 关闭数据库连接（避免 Windows 文件锁定）
        try {
          await DatabaseManager.instance.dispose();
          AppLogger.i('Database closed successfully', 'TrayListener');
        } catch (e) {
          AppLogger.w('Error closing database: $e', 'TrayListener');
        }

        // 2. 先销毁托盘图标，避免残留在系统托盘中
        await trayManager.destroy();
        // 3. 解除 preventClose，再销毁窗口
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
        AppLogger.d('Application exited via tray menu', 'TrayListener');
        await AppLogger.flush();
        // 强制退出进程，确保 dart.exe 不会残留
        exit(0);
      }
    } catch (e) {
      AppLogger.e('Failed to handle tray menu click: $e', 'TrayListener');
    }
  }
}

/// 窗口监听器，处理窗口关闭、大小变化和显示事件
class AppWindowListener extends WindowListener {
  DateTime? _lastResizeSave;

  @override
  Future<void> onWindowClose() async {
    // 阻止默认关闭行为，改为隐藏到托盘
    try {
      // 阻止窗口关闭
      await windowManager.setPreventClose(true);
      await windowManager.hide();
      AppLogger.d('Window hidden to tray', 'WindowListener');
    } catch (e) {
      AppLogger.e('Failed to hide window to tray: $e', 'WindowListener');
    }
  }

  @override
  Future<void> onWindowFocus() async {
    // 窗口获得焦点时的处理
    WindowFocusTracker.markFocused();
    AppLogger.d('Window focused', 'WindowListener');
  }

  @override
  Future<void> onWindowBlur() async {
    // 窗口失焦时记录时间，用于规避外部截图工具引发的焦点抖动
    WindowFocusTracker.markBlurred();
    AppLogger.d('Window blurred', 'WindowListener');
  }

  @override
  Future<void> onWindowResize() async {
    // 窗口大小变化时实时保存（带防抖）
    final now = DateTime.now();
    if (_lastResizeSave != null &&
        now.difference(_lastResizeSave!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastResizeSave = now;

    try {
      final snapshot = await _saveCurrentWindowState();

      AppLogger.d(
        'Window size/position saved: ${snapshot.size.width}x${snapshot.size.height} at (${snapshot.position.dx}, ${snapshot.position.dy})',
        'WindowListener',
      );
    } catch (e) {
      AppLogger.w(
        'Failed to save window state on resize: $e',
        'WindowListener',
      );
    }
  }

  @override
  Future<void> onWindowMove() async {
    // 窗口移动时也保存位置
    final now = DateTime.now();
    if (_lastResizeSave != null &&
        now.difference(_lastResizeSave!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastResizeSave = now;

    try {
      final snapshot = await _saveCurrentWindowState();

      AppLogger.d(
        'Window position saved: (${snapshot.position.dx}, ${snapshot.position.dy})',
        'WindowListener',
      );
    } catch (e) {
      AppLogger.w(
        'Failed to save window position on move: $e',
        'WindowListener',
      );
    }
  }
}

/// 处理来自 Windows 原生层的唤醒消息
/// 当新实例启动时，已存在的实例会收到此消息
void setupWindowsWakeUpChannel() {
  if (!Platform.isWindows) return;

  const channel = MethodChannel('com.nailauncher/window_control');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'wakeUp') {
      try {
        // 确保窗口显示并置于前台
        await windowManager.show();
        await windowManager.focus();
        await windowManager.restore();
        AppLogger.i('Window woken up by new instance', 'Main');
      } catch (e) {
        AppLogger.e('Failed to wake up window: $e', 'Main');
      }
    }
  });
}

void main() {
  final bootstrap = runZonedGuarded<Future<void>>(_bootstrapApplication, (
    error,
    stackTrace,
  ) {
    AppErrorReporter.reportError(
      error,
      stackTrace,
      source: 'runZonedGuarded',
      fatal: true,
    );
  });
  if (bootstrap != null) {
    unawaited(bootstrap);
  }
}

Future<void> _bootstrapApplication() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorReporter.installGlobalHandlers();

  // 先初始化控制台日志；文件日志稍后读取设置后按需开启，默认关闭。
  await AppLogger.initialize(
    isTestEnvironment: false,
    enableFileLogging: false,
  );
  AppLogger.i('Application starting', 'Main');

  await _runNonFatalStartupStep('Fatal diagnostics initialization', () async {
    await FatalDiagnostics.initialize();
  });

  // 初始化版本信息（从 pubspec.yaml 读取）
  await _runNonFatalStartupStep('App version initialization', () async {
    await AppVersion.initialize();
    AppLogger.i('App version: ${AppVersion.fullVersion}', 'Main');
  });

  // 增加图片缓存限制，防止本地画廊滚动时图片被回收变白
  PaintingBinding.instance.imageCache.maximumSize = 500; // 最大缓存 500 张图片
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // 200MB

  try {
    // 初始化桌面端视频播放支持 (media_kit: Windows + macOS)
    VideoPlayerMediaKit.ensureInitialized(
      windows: Platform.isWindows,
      macOS: Platform.isMacOS,
    );
  } catch (e, stackTrace) {
    AppLogger.e(
      'Video player initialization failed; continuing startup',
      e,
      stackTrace,
      'Main',
    );
  }

  // 日志系统已自动初始化，无需显式调用

  // 初始化 SQLite FFI（Windows/Linux 桌面端必需）
  await SqfliteBootstrapService.instance.ensureInitialized();

  // 初始化 Hive（使用子目录存储，支持迁移旧数据）
  await HiveStorageHelper.instance.init();
  final hivePath = await HiveStorageHelper.instance.getPath();

  // 注册 Hive adapters（用于元数据存储）
  if (!Hive.isAdapterRegistered(24)) {
    Hive.registerAdapter(NaiImageMetadataAdapter());
  }
  if (!Hive.isAdapterRegistered(25)) {
    Hive.registerAdapter(CharacterPromptInfoAdapter());
  }

  // 先迁移 Hive 文件，再打开 box，避免 Windows 文件锁阻止旧数据覆盖占位文件。
  await HiveStorageHelper.instance.migrateFromOldLocation(hivePath);

  await _openHiveBoxIfNeeded(StorageKeys.settingsBox, hivePath: hivePath);
  final settingsBox = Hive.box(StorageKeys.settingsBox);
  final fileLoggingEnabled =
      settingsBox.get(StorageKeys.fileLoggingEnabled, defaultValue: false) ==
      true;
  await AppLogger.setFileLoggingEnabled(fileLoggingEnabled);

  // 在 Hive 初始化之后执行文件迁移
  try {
    final migrationResult = await DataMigrationService.instance.migrateAll();
    AppLogger.i('Startup migration result: $migrationResult', 'Main');
  } catch (e) {
    AppLogger.w('Startup migration failed (will continue): $e', 'Main');
  }

  // ===== V2 架构：数据库初始化和恢复（在 runApp 之前完成）====
  AppLogger.i('等待数据库初始化...', 'Main');
  final container = ProviderContainer();

  try {
    // V2 架构：DatabaseManagerV2 自动处理热重启检测
    final manager = await DatabaseManager.initialize();
    await manager.initialized;

    // 检查核心资产库完整性。翻译和共现数据已迁移到独立资产数据库，
    // 不应再从 danbooru.db 的运行时表统计里判断。
    final coreAssetStats = await manager.getCoreAssetStatistics();
    final translationCount = coreAssetStats['translations'] ?? 0;
    final cooccurrenceCount = coreAssetStats['cooccurrences'] ?? 0;

    AppLogger.i(
      '核心资产数据库状态: translations=$translationCount, cooccurrences=$cooccurrenceCount',
      'Main',
    );

    if (translationCount == 0 || cooccurrenceCount == 0) {
      AppLogger.w('核心资产数据为空，请检查打包数据库', 'Main');
    }

    AppLogger.i('数据库初始化完成', 'Main');
  } catch (e, stack) {
    AppLogger.e('数据库初始化失败', e, stack, 'Main');
    // 继续启动，应用内会显示错误',
  }

  // 预先打开 Hive boxes (确保 LocalStorageService 可用)
  await _openHiveBoxIfNeeded(StorageKeys.settingsBox, hivePath: hivePath);
  await _openHiveBoxIfNeeded(StorageKeys.historyBox, hivePath: hivePath);
  await _openHiveBoxIfNeeded(StorageKeys.tagCacheBox, hivePath: hivePath);
  await _openHiveBoxIfNeeded(StorageKeys.galleryBox, hivePath: hivePath);
  // Local Gallery 新功能所需的 Hive boxes
  await _openHiveBoxIfNeeded(StorageKeys.localFavoritesBox, hivePath: hivePath);
  await _openHiveBoxIfNeeded(StorageKeys.tagsBox, hivePath: hivePath);
  await _openHiveBoxIfNeeded(StorageKeys.searchIndexBox, hivePath: hivePath);
  // 统计数据缓存 Box
  await _openHiveBoxIfNeeded(
    StorageKeys.statisticsCacheBox,
    hivePath: hivePath,
  );
  // 收藏集合 Box
  await _openHiveBoxIfNeeded(StorageKeys.collectionsBox, hivePath: hivePath);
  // 队列相关 Box（预加载以避免首次打开队列管理页面时的延迟）
  await _openHiveBoxIfNeeded<String>(
    StorageKeys.replicationQueueBox,
    hivePath: hivePath,
  );
  await _openHiveBoxIfNeeded<String>(
    StorageKeys.queueExecutionStateBox,
    hivePath: hivePath,
  );

  // 初始化图像元数据服务（包含持久化缓存，用于详情页快速加载）
  await _runNonFatalStartupStep(
    'Image metadata service initialization',
    () async {
      await ImageMetadataService().initialize();
      AppLogger.i('图像元数据服务初始化完成', 'Main');
    },
  );

  // 后台执行 L2 Hive 缓存清理（不阻塞启动）
  Future.microtask(() async {
    try {
      await L2CacheCleaner().checkAndClean();
    } catch (e) {
      AppLogger.w('L2 cache cleanup failed: $e', 'Main');
    }
  });

  // 初始化统一缩略图服务
  final thumbnailService = ThumbnailService.instance;
  await _runNonFatalStartupStep('Thumbnail service initialization', () async {
    await thumbnailService.initialize();
    AppLogger.i('缩略图服务初始化完成', 'Main');
  });

  // 【修复】初始化收藏集合仓库
  await _runNonFatalStartupStep(
    'Collection repository initialization',
    () async {
      await CollectionRepository.instance.initialize();
      AppLogger.i('收藏集合仓库初始化完成', 'Main');
    },
  );

  // 【修复】初始化扫描状态管理器（确保检查点功能正常工作）
  await _runNonFatalStartupStep('Scan state manager initialization', () async {
    await ScanStateManager.instance.initialize();
    AppLogger.i('扫描状态管理器初始化完成', 'Main');
  });

  // 【修复】初始化 Isolate 元数据服务（详情页快速解析）
  await _runNonFatalStartupStep(
    'Isolate metadata service initialization',
    () async {
      await IsolateMetadataService.instance.initialize();
      AppLogger.i('Isolate 元数据服务初始化完成', 'Main');
    },
  );

  // 【修复】启动时清理嵌套缩略图（修复递归生成bug遗留问题）
  Future.microtask(() async {
    try {
      final rootPath = await GalleryFolderRepository.instance.getRootPath();
      if (rootPath != null) {
        final cleanedCount = await thumbnailService.cleanupNestedThumbs(
          rootPath,
        );
        if (cleanedCount > 0) {
          AppLogger.i('启动清理完成: 删除了 $cleanedCount 个嵌套缩略图目录', 'Main');
        }
      }
    } catch (e) {
      AppLogger.w('清理嵌套缩略图失败: $e', 'Main');
    }
  });

  // 扫描已由 UnifiedGalleryService 处理，在打开本地画廊时自动执行

  // 初始化快捷键存储
  final shortcutStorage = ShortcutStorage();
  await _runNonFatalStartupStep('Shortcut storage initialization', () async {
    await shortcutStorage.init();
    AppLogger.d('Shortcut storage initialized', 'Main');
  });

  // Timeago 本地化配置
  timeago.setLocaleMessages('zh', timeago.ZhCnMessages());
  timeago.setLocaleMessages('zh_CN', timeago.ZhCnMessages());
  timeago.setLocaleMessages('ja', timeago.JaMessages());

  // 清理过期临时文件（不阻塞启动）
  Future.microtask(() async {
    try {
      await TempImageService().cleanupOldTempFiles();
    } catch (e) {
      AppLogger.w('Temp files cleanup failed: $e', 'Main');
    }
  });

  // 后台预加载 NAI 标签数据（不阻塞启动）
  // 使用已创建的 container
  Future.microtask(() async {
    try {
      await container.read(naiTagsDataSourceProvider).loadData();
      AppLogger.d('NAI tags preloaded successfully', 'Main');
    } catch (e) {
      AppLogger.w('NAI tags preload failed: $e', 'Main');
      // 预加载失败不影响应用启动
    }
  });

  // 后台自动同步画师标签（不阻塞启动）
  // 延迟5秒执行，避免与数据库初始化冲突
  Future.delayed(const Duration(seconds: 5), () async {
    try {
      AppLogger.i('Checking artist tags sync...', 'Main');
      final notifier = container.read(
        danbooruTagsCacheNotifierProvider.notifier,
      );
      await notifier.checkAndSyncArtists();
    } catch (e) {
      AppLogger.w('Artist tags auto-sync failed: $e', 'Main');
      // 同步失败不影响应用启动
    }
  });

  // 启动时自动同步在线画廊黑名单（不阻塞启动）
  Future.delayed(const Duration(seconds: 8), () async {
    try {
      await container
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .syncOnStartup();
    } catch (e) {
      AppLogger.w('Online gallery blacklist auto-sync failed: $e', 'Main');
    }
  });

  // 桌面端窗口配置
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      await windowManager.ensureInitialized();

      // 设置 Windows 唤醒消息处理（单实例唤醒）
      if (Platform.isWindows) {
        setupWindowsWakeUpChannel();
      }

      // 从 Hive 读取保存的窗口状态
      final box = Hive.box(StorageKeys.settingsBox);
      final savedWidth = coerceWindowDimension(
        box.get(StorageKeys.windowWidth, defaultValue: 1600.0),
        fallback: 1600.0,
      );
      final savedHeight = coerceWindowDimension(
        box.get(StorageKeys.windowHeight, defaultValue: 900.0),
        fallback: 900.0,
      );
      final savedX = coerceWindowPosition(box.get(StorageKeys.windowX));
      final savedY = coerceWindowPosition(box.get(StorageKeys.windowY));

      // 读取屏幕可用工作区
      double effWidth = savedWidth;
      double effHeight = savedHeight;
      Rect? fillBounds; // macOS 首次启动：铺满工作区时使用
      try {
        final display = await screenRetriever.getPrimaryDisplay();
        final work = display.visibleSize ?? display.size;
        final workPos = display.visiblePosition ?? Offset.zero;

        if (Platform.isMacOS) {
          // macOS：启动时自适应屏幕，铺满可用工作区（紧贴屏幕，保留菜单栏/Dock）
          effWidth = work.width;
          effHeight = work.height;
          fillBounds = Rect.fromLTWH(
            workPos.dx,
            workPos.dy,
            work.width,
            work.height,
          );
        } else {
          // 其它情况：clamp 到工作区，避免窗口超出屏幕
          final maxW = (work.width - 40)
              .clamp(800.0, double.infinity)
              .toDouble();
          final maxH = (work.height - 40)
              .clamp(600.0, double.infinity)
              .toDouble();
          effWidth = savedWidth.clamp(800.0, maxW).toDouble();
          effHeight = savedHeight.clamp(600.0, maxH).toDouble();
        }
      } catch (e) {
        AppLogger.w('获取屏幕工作区失败，使用默认窗口尺寸: $e', 'Main');
      }

      final windowOptions = WindowOptions(
        size: Size(effWidth, effHeight),
        minimumSize: const Size(800, 600),
        center: fillBounds == null && (savedX == null || savedY == null),
        backgroundColor: const Color(0xFF121212), // 深色背景，避免窗口透明
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'NAI Launcher',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        if (fillBounds != null) {
          // macOS 首次启动：精确铺满屏幕工作区
          await windowManager.setBounds(fillBounds);
          AppLogger.d(
            'Window filled to work area: ${effWidth}x$effHeight',
            'Main',
          );
        } else if (savedX != null && savedY != null) {
          await windowManager.setPosition(Offset(savedX, savedY));
          AppLogger.d(
            'Window state restored: ${effWidth}x$effHeight at ($savedX, $savedY)',
            'Main',
          );
        } else {
          AppLogger.d(
            'Window initialized with default state: ${effWidth}x$effHeight (centered)',
            'Main',
          );
        }

        await windowManager.show();
        await windowManager.focus();
      });

      // 初始化系统托盘（仅 Windows）
      if (Platform.isWindows) {
        try {
          // 设置托盘图标和提示
          // tray_manager 使用 Flutter 资源路径格式（相对于 data/flutter_assets/）
          await trayManager.setIcon('assets/icons/app_icon.ico');
          await trayManager.setToolTip('NAI Launcher');

          // 获取本地化字符串
          final l10n = _getLocalizedStrings();

          final menu = Menu(
            items: [
              MenuItem(key: 'show', label: l10n.tray_show),
              MenuItem.separator(),
              MenuItem(key: 'exit', label: l10n.tray_exit),
            ],
          );
          await trayManager.setContextMenu(menu);

          // 设置阻止关闭（关闭时隐藏到托盘）
          await windowManager.setPreventClose(true);

          trayManager.addListener(AppTrayListener());
          windowManager.addListener(AppWindowListener());

          AppLogger.d('System tray initialized', 'Main');
        } catch (e) {
          AppLogger.e('Failed to initialize system tray: $e', 'Main');
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'Desktop window initialization failed; continuing startup',
        e,
        stackTrace,
        'Main',
      );
    }
  }

  // 系统代理配置（根据用户设置）
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final settingsBox = Hive.box(StorageKeys.settingsBox);
    final proxyEnabled =
        settingsBox.get(StorageKeys.proxyEnabled, defaultValue: true) as bool;

    if (proxyEnabled) {
      final proxyMode =
          settingsBox.get(StorageKeys.proxyMode, defaultValue: 'auto')
              as String;

      String? proxyAddress;

      if (proxyMode == 'manual') {
        // 手动模式：从设置读取
        final host = settingsBox.get(StorageKeys.proxyManualHost) as String?;
        final port = settingsBox.get(StorageKeys.proxyManualPort) as int?;
        if (host != null && host.isNotEmpty && port != null && port > 0) {
          proxyAddress = '$host:$port';
        }
      } else {
        // 自动模式：从系统获取
        proxyAddress = ProxyService.getSystemProxyAddress();
      }

      if (proxyAddress != null && proxyAddress.isNotEmpty) {
        HttpOverrides.global = SystemProxyHttpOverrides('PROXY $proxyAddress');
        AppLogger.i(
          'Applied proxy: $proxyAddress (mode: $proxyMode)',
          'NETWORK',
        );
      } else {
        AppLogger.w(
          'Proxy enabled but no proxy address available (mode: $proxyMode)',
          'NETWORK',
        );
      }
    } else {
      AppLogger.d('Proxy disabled by user settings', 'NETWORK');
    }
  }

  // 注册窗口状态观察者（桌面端）
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    WidgetsBinding.instance.addObserver(WindowStateObserver());
    AppLogger.d('Window state observer registered', 'Main');
  }

  final searchIndexService = SearchIndexService();
  _runDeferredStartupStep('Search index service initialization', () async {
    await searchIndexService.init();
    AppLogger.i('搜索索引服务初始化完成', 'Main');
  });

  final tagCacheService = TagCacheService();
  _runDeferredStartupStep('Tag cache service initialization', () async {
    await tagCacheService.init();
    AppLogger.i('Tag 缓存服务初始化完成', 'Main');
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AppBootstrap(),
    ),
  );
}
