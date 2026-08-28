import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'package:timeago/timeago.dart' as timeago;

import 'core/constants/app_version.dart';
import 'core/constants/storage_keys.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_en.dart';
import 'l10n/app_localizations_ja.dart';
import 'l10n/app_localizations_zh.dart';
import 'core/services/desktop_app_shutdown_service.dart';
import 'core/windowing/agent_window_protocol.dart';
import 'core/windowing/agent_window_runtime.dart';
import 'presentation/agent_chat/services/agent_window_bridge_adapter.dart';
import 'core/utils/app_error_reporter.dart';
import 'core/utils/app_locale.dart';
import 'core/utils/fatal_diagnostics.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/hive_startup_box_opener.dart';
import 'core/utils/hive_storage_helper.dart';
import 'core/utils/window_focus_tracker.dart';
import 'core/utils/windows_clipboard_history_key_fix.dart';
import 'core/utils/window_state_coercion.dart';
import 'core/utils/window_state_persistence.dart';
import 'data/datasources/local/random_tag_library_data_source.dart';
import 'data/models/gallery/nai_image_metadata.dart';
import 'data/repositories/gallery_folder_repository.dart';
import 'core/cache/gallery_cache_manager.dart';
import 'core/cache/local_gallery_thumbnail_migration.dart';

import 'core/cache/tag_cache_service.dart';
import 'core/services/sqflite_bootstrap_service.dart';
import 'data/services/metadata/isolate_metadata_service.dart';
import 'data/services/search_index_service.dart';
import 'data/services/temp_image_service.dart';
import 'presentation/providers/online_gallery_blacklist_provider.dart';
import 'presentation/screens/splash/app_bootstrap.dart';
import 'presentation/services/generation_history_storage_service.dart';

/// Get localized strings based on the stored locale setting
/// Used in main() before the app is initialized
AppLocalizations _getLocalizedStrings() {
  final box = Hive.box(StorageKeys.settingsBox);
  final localeCode = box.get(StorageKeys.locale, defaultValue: 'zh') as String;
  switch (appLocaleCode(appLocaleFromCode(localeCode))) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case traditionalChineseLocaleCode:
      return AppLocalizationsZhHant();
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

Future<void> _windowStateSaveQueue = Future<void>.value();

Future<WindowStateSnapshot> _saveCurrentWindowState() {
  final operation = _windowStateSaveQueue.then((_) async {
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
  });
  _windowStateSaveQueue = operation.then<void>((_) {}, onError: (_) {});
  return operation;
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
        await DesktopAppShutdownService.shutdownAndExit(0);
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

class _DesktopWindowConfiguration {
  const _DesktopWindowConfiguration({
    required this.options,
    required this.width,
    required this.height,
    required this.savedX,
    required this.savedY,
    required this.fillBounds,
  });

  final WindowOptions options;
  final double width;
  final double height;
  final double? savedX;
  final double? savedY;
  final Rect? fillBounds;

  Future<void> show() async {
    await windowManager.waitUntilReadyToShow(options, () async {
      if (fillBounds != null) {
        await windowManager.setBounds(fillBounds!);
        AppLogger.d('Window filled to work area: ${width}x$height', 'Main');
      } else if (savedX != null && savedY != null) {
        await windowManager.setPosition(Offset(savedX!, savedY!));
        AppLogger.d(
          'Window state restored: ${width}x$height at ($savedX, $savedY)',
          'Main',
        );
      }
      await windowManager.show();
      await windowManager.focus();
      AppLogger.i('Desktop window showing rendered Splash', 'Main');
    });
    final trayReady = await _initializeSystemTray();
    if (trayReady) {
      await windowManager.setPreventClose(true);
      windowManager.addListener(AppWindowListener());
    }
  }
}

Future<_DesktopWindowConfiguration?> _prepareDesktopWindow() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return null;
  }

  try {
    await windowManager.ensureInitialized();
    if (Platform.isWindows) setupWindowsWakeUpChannel();

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

    var width = savedWidth;
    var height = savedHeight;
    Rect? fillBounds;
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final work = display.visibleSize ?? display.size;
      final workPosition = display.visiblePosition ?? Offset.zero;
      if (Platform.isMacOS) {
        width = work.width;
        height = work.height;
        fillBounds = Rect.fromLTWH(
          workPosition.dx,
          workPosition.dy,
          work.width,
          work.height,
        );
      } else {
        final maxWidth = (work.width - 40)
            .clamp(800.0, double.infinity)
            .toDouble();
        final maxHeight = (work.height - 40)
            .clamp(600.0, double.infinity)
            .toDouble();
        width = savedWidth.clamp(800.0, maxWidth).toDouble();
        height = savedHeight.clamp(600.0, maxHeight).toDouble();
      }
    } catch (e) {
      AppLogger.w('获取屏幕工作区失败，使用默认窗口尺寸: $e', 'Main');
    }

    await windowManager.setMinimumSize(const Size(800, 600));
    if (fillBounds != null) {
      await windowManager.setBounds(fillBounds);
    } else {
      await windowManager.setSize(Size(width, height));
      if (savedX != null && savedY != null) {
        await windowManager.setPosition(Offset(savedX, savedY));
      } else {
        await windowManager.center();
      }
    }

    WidgetsBinding.instance.addObserver(WindowStateObserver());
    AppLogger.d('Desktop window configured before first frame', 'Main');

    return _DesktopWindowConfiguration(
      options: WindowOptions(
        size: Size(width, height),
        minimumSize: const Size(800, 600),
        center: fillBounds == null && (savedX == null || savedY == null),
        backgroundColor: const Color(0xFF121212),
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'NAI Launcher',
      ),
      width: width,
      height: height,
      savedX: savedX,
      savedY: savedY,
      fillBounds: fillBounds,
    );
  } catch (e, stackTrace) {
    AppLogger.e(
      'Desktop window preparation failed; continuing startup',
      e,
      stackTrace,
      'Main',
    );
    return null;
  }
}

Future<bool> _initializeSystemTray() async {
  if (!(Platform.isWindows || Platform.isMacOS)) return false;
  try {
    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/icons/app_icon.ico'
          : 'assets/icons/tray_icon.png',
    );
    await trayManager.setToolTip('NAI Launcher');
    final l10n = _getLocalizedStrings();
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: l10n.tray_show),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: l10n.tray_exit),
        ],
      ),
    );
    trayManager.addListener(AppTrayListener());
    return true;
  } catch (error, stackTrace) {
    AppLogger.e(
      'System tray initialization failed; normal window close remains enabled',
      error,
      stackTrace,
      'Main',
    );
    return false;
  }
}

Future<void> _runDeferredStartup(ProviderContainer container) async {
  await Future.wait([
    _runNonFatalStartupStep('L2 cache cleanup', () async {
      await L2CacheCleaner().checkAndClean();
    }),
    _runNonFatalStartupStep(
      'Isolate metadata service initialization',
      () async {
        await IsolateMetadataService.instance.initialize();
      },
    ),
    _runNonFatalStartupStep('Temp files cleanup', () async {
      await TempImageService().cleanupOldTempFiles();
    }),
    _runNonFatalStartupStep('Random tag library preload', () async {
      await container.read(randomTagLibraryDataSourceProvider).loadData();
    }),
    _runNonFatalStartupStep('Search index service initialization', () async {
      await SearchIndexService().init();
    }),
    _runNonFatalStartupStep('Tag cache service initialization', () async {
      await TagCacheService().init();
    }),
  ]);

  await _runNonFatalStartupStep('Legacy local thumbnail migration', () async {
    final rootPath = await GalleryFolderRepository.instance.getRootPath();
    if (rootPath == null) return;
    final result = await const LocalGalleryThumbnailMigration().runOnce(
      rootPath,
    );
    if (!result.alreadyCompleted) {
      AppLogger.i(
        'Legacy thumbnail migration: removed ${result.removedFiles} files '
            '(${result.removedBytes} bytes), preserved '
            '${result.preservedFiles}, failures ${result.failures}',
        'Main',
      );
    }
  });

  Future.delayed(const Duration(seconds: 8), () async {
    await _runNonFatalStartupStep('Online gallery blacklist sync', () async {
      await container
          .read(onlineGalleryBlacklistNotifierProvider.notifier)
          .syncOnStartup();
    });
  });
}

void main(List<String> args) {
  final agentWindowArguments =
      AgentWindowLaunchArguments.tryParseEntrypointArgs(args);
  if (agentWindowArguments != null && AgentWindowRuntime.isDesktop) {
    unawaited(
      runAgentWindowSecondary(
        arguments: agentWindowArguments,
        builder: buildAgentWindowBridgeShell,
      ).catchError((Object error, StackTrace stackTrace) {
        AppErrorReporter.reportError(
          error,
          stackTrace,
          source: 'agentWindowSecondary',
          fatal: true,
        );
      }),
    );
    return;
  }

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
  if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
    enableFlutterDriverExtension(enableTextEntryEmulation: false);
  }
  WidgetsFlutterBinding.ensureInitialized();
  WindowsClipboardHistoryKeyFix.instance.install();
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

  // 移动端必须给解码图、WebView、视频与 ONNX 留出足够内存余量。
  final isMobile = Platform.isAndroid || Platform.isIOS;
  PaintingBinding.instance.imageCache.maximumSize = isMobile ? 120 : 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      (isMobile ? 64 : 200) << 20;

  // FFI 注册本身不打开数据库，需在数据库调用方出现前完成。
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

  // settings 是 Splash 首帧唯一必需 box，先单独迁移，避免 Windows 文件锁阻止覆盖。
  // 其余 Hive 文件由 Splash Warmup 迁移。
  await HiveStorageHelper.instance.migrateSettingsFromOldLocation(hivePath);

  await _openHiveBoxIfNeeded(StorageKeys.settingsBox, hivePath: hivePath);
  final desktopWindowFuture = _prepareDesktopWindow();

  // Timeago 本地化配置
  timeago.setLocaleMessages('zh', timeago.ZhCnMessages());
  timeago.setLocaleMessages('zh_CN', timeago.ZhCnMessages());
  timeago.setLocaleMessages('zh_Hant', timeago.ZhMessages());
  timeago.setLocaleMessages('ja', timeago.JaMessages());

  final desktopWindow = await desktopWindowFuture;
  final container = ProviderContainer(
    overrides: [
      generationSessionPersistenceEnabledProvider.overrideWithValue(true),
    ],
  );
  if (AgentWindowRuntime.isDesktop) {
    final settings = Hive.box(StorageKeys.settingsBox);
    late AgentWindowBridgeAdapter bridgeAdapter;
    await AgentWindowRuntime.instance.initializeMain(
      preferences: CallbackAgentWindowPreferences(
        boundsReader: () async {
          final value = settings.get('agentWindow.bounds');
          if (value is! Map) return null;
          try {
            return AgentWindowBounds.fromJson(
              Map<Object?, Object?>.from(value),
            );
          } on FormatException {
            return null;
          }
        },
        boundsWriter: (bounds) =>
            settings.put('agentWindow.bounds', bounds.toJson()),
        alwaysOnTopReader: () async {
          final value = settings.get(
            'agentWindow.alwaysOnTop',
            defaultValue: false,
          );
          return value is bool && value;
        },
        alwaysOnTopWriter: (value) =>
            settings.put('agentWindow.alwaysOnTop', value),
        detachedReader: () async =>
            settings.get('agentWindow.detached', defaultValue: false) == true,
        detachedWriter: (value) => settings.put('agentWindow.detached', value),
      ),
      commandHandler: (name, payload) =>
          bridgeAdapter.handleCommand(name, payload),
    );
    bridgeAdapter = await AgentWindowBridgeAdapter.attach(container);
    WidgetsBinding.instance.addObserver(AgentWindowMainLifecycleObserver());
    unawaited(
      AgentWindowRuntime.instance.restoreDetached().catchError((error, stack) {
        AppLogger.e(
          'Failed to restore the detached Agent window',
          error,
          stack,
          'AgentWindow',
        );
      }),
    );
  }
  AppLogger.i('Calling runApp; database warmup has not started', 'Main');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: AppBootstrap(
        onWarmupComplete: () {
          unawaited(_runDeferredStartup(container));
        },
      ),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    AppLogger.i('Flutter first frame completed', 'Main');
    if (desktopWindow != null) {
      unawaited(desktopWindow.show());
    }
  });
}
