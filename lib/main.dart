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
import 'core/utils/app_error_reporter.dart';
import 'core/utils/app_locale.dart';
import 'core/utils/fatal_diagnostics.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/hive_startup_box_opener.dart';
import 'core/utils/hive_storage_helper.dart';
import 'core/utils/window_focus_tracker.dart';
import 'core/utils/windows_clipboard_history_key_fix.dart';
import 'core/utils/window_state_persistence.dart';
import 'core/windowing/desktop_window_state_controller.dart';
import 'core/windowing/windows_native_window_state.dart';
import 'data/models/gallery/nai_image_metadata.dart';
import 'data/repositories/gallery_folder_repository.dart';
import 'core/cache/local_gallery_thumbnail_migration.dart';
import 'core/services/sqflite_bootstrap_service.dart';
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

/// 在桌面生命周期切换时刷新最后一个有效的普通窗口状态。
class WindowStateObserver extends WidgetsBindingObserver {
  WindowStateObserver(this.controller);

  final DesktopWindowStateController controller;

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached) {
      return;
    }

    try {
      await controller.flush();
      await AppLogger.flush();
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to flush window state during lifecycle transition',
        error,
        stackTrace,
        'Main',
      );
    }
  }
}

Future<void> _restoreWindowIfMinimized() async {
  if (await windowManager.isMinimized()) await windowManager.restore();
}

/// 系统托盘监听器，处理托盘图标交互
class AppTrayListener extends TrayListener {
  @override
  Future<void> onTrayIconMouseDown() async {
    // 左键点击托盘图标 - 恢复窗口
    try {
      await _restoreWindowIfMinimized();
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
        await _restoreWindowIfMinimized();
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

/// 窗口监听器只保存有效普通 bounds；最大化与最小化不覆盖它。
class AppWindowListener extends WindowListener {
  AppWindowListener(this.controller, {required this.hideOnClose});

  final DesktopWindowStateController controller;
  final bool hideOnClose;

  @override
  Future<void> onWindowClose() async {
    if (!hideOnClose) return;
    try {
      await controller.flush();
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to persist window state before hiding to tray',
        error,
        stackTrace,
        'WindowListener',
      );
    }

    try {
      await windowManager.hide();
      AppLogger.d('Window hidden to tray', 'WindowListener');
    } catch (error, stackTrace) {
      AppLogger.e('Failed to hide window', error, stackTrace, 'WindowListener');
    }
  }

  @override
  void onWindowFocus() {
    WindowFocusTracker.markFocused();
    AppLogger.d('Window focused', 'WindowListener');
  }

  @override
  void onWindowBlur() {
    WindowFocusTracker.markBlurred();
    AppLogger.d('Window blurred', 'WindowListener');
  }

  @override
  void onWindowResize() {
    if (Platform.isLinux) unawaited(_capture('resize'));
  }

  @override
  void onWindowResized() {
    if (Platform.isMacOS) unawaited(_capture('resize end'));
  }

  @override
  void onWindowMove() {
    if (Platform.isLinux) unawaited(_capture('move'));
  }

  @override
  void onWindowMoved() {
    if (Platform.isMacOS) unawaited(_capture('move end'));
  }

  @override
  void onWindowMaximize() => unawaited(_recordMaximized());

  @override
  void onWindowUnmaximize() => unawaited(_recordUnmaximized());

  @override
  void onWindowRestore() => unawaited(_capture('restore'));

  Future<void> _capture(String reason) async {
    try {
      await controller.captureCurrentState();
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to capture window state after $reason',
        error,
        stackTrace,
        'WindowListener',
      );
    }
  }

  Future<void> _recordMaximized() async {
    try {
      await controller.recordMaximized();
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to persist maximized window state',
        error,
        stackTrace,
        'WindowListener',
      );
    }
  }

  Future<void> _recordUnmaximized() async {
    try {
      await controller.recordUnmaximized();
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to persist restored window state',
        error,
        stackTrace,
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
        await _restoreWindowIfMinimized();
        await windowManager.show();
        await windowManager.focus();
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
    required this.restorePlan,
    required this.stateController,
    required this.nativePlatform,
  });

  final WindowOptions options;
  final WindowRestorePlan restorePlan;
  final DesktopWindowStateController stateController;
  final WindowsNativeWindowStatePlatform? nativePlatform;

  Future<void> show() async {
    await windowManager.waitUntilReadyToShow(options, () async {
      if (Platform.isWindows) {
        await const WindowsNativeWindowStatePlatform().restore(restorePlan);
      } else {
        await windowManager.setBounds(restorePlan.normalBounds);
        if (restorePlan.maximized) await windowManager.maximize();
        await windowManager.show();
      }
      await windowManager.focus();
      AppLogger.i(
        'Desktop window restored to ${restorePlan.normalBounds} '
            '(maximized: ${restorePlan.maximized})',
        'Main',
      );
    });

    WidgetsBinding.instance.addObserver(WindowStateObserver(stateController));
    nativePlatform?.setBoundsChangedHandler(() async {
      try {
        await stateController.captureCurrentState();
      } catch (error, stackTrace) {
        AppLogger.e(
          'Failed to capture native Windows bounds change',
          error,
          stackTrace,
          'Main',
        );
      }
    });
    final trayReady = await _initializeSystemTray();
    if (trayReady) await windowManager.setPreventClose(true);
    windowManager.addListener(
      AppWindowListener(stateController, hideOnClose: trayReady),
    );
  }
}

Rect _displayWorkArea(Display display) {
  final size = display.visibleSize ?? display.size;
  final position = display.visiblePosition ?? Offset.zero;
  return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
}

Future<_DesktopWindowConfiguration?> _prepareDesktopWindow() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return null;
  }

  try {
    await windowManager.ensureInitialized();
    if (Platform.isWindows) setupWindowsWakeUpChannel();

    var workAreas = const <Rect>[];
    var workAreaScaleFactors = const <Rect, double>{};
    Rect? primaryWorkArea;
    var legacyScale = 1.0;
    DesktopWindowStatePlatform statePlatform =
        const WindowManagerStatePlatform();
    WindowsNativeWindowStatePlatform? nativePlatform;
    if (Platform.isWindows) {
      nativePlatform = const WindowsNativeWindowStatePlatform();
      final nativeWorkAreas = await nativePlatform.getWorkAreas();
      workAreas = nativeWorkAreas.all;
      primaryWorkArea = nativeWorkAreas.primary;
      workAreaScaleFactors = nativeWorkAreas.scaleFactors;
      legacyScale = nativeWorkAreas.primaryScaleFactor;
      statePlatform = nativePlatform;
    } else {
      try {
        final displays = await screenRetriever.getAllDisplays();
        final primaryDisplay = await screenRetriever.getPrimaryDisplay();
        workAreas = displays.map(_displayWorkArea).toList(growable: false);
        primaryWorkArea = _displayWorkArea(primaryDisplay);
      } catch (error, stackTrace) {
        AppLogger.e(
          'Unable to read desktop work areas; using validated saved bounds',
          error,
          stackTrace,
          'Main',
        );
      }
    }

    final box = Hive.box(StorageKeys.settingsBox);
    final storedState = readWindowStateSnapshot(
      storedState: box.get(StorageKeys.windowStateV2),
      legacyWidth: box.get(StorageKeys.windowWidth),
      legacyHeight: box.get(StorageKeys.windowHeight),
      legacyX: box.get(StorageKeys.windowX),
      legacyY: box.get(StorageKeys.windowY),
      legacyScale: legacyScale,
      legacyWorkAreaScaleFactors: workAreaScaleFactors,
    );
    final restorePlan = resolveWindowRestorePlan(
      snapshot: storedState,
      workAreas: workAreas,
      primaryWorkArea: primaryWorkArea,
      workAreaScaleFactors: workAreaScaleFactors,
    );
    final resolvedState = WindowStateSnapshot(
      normalBounds: restorePlan.normalBounds,
      maximized: restorePlan.maximized,
      scaleFactor: restorePlan.scaleFactor,
    );
    Future<void> persist(WindowStateSnapshot snapshot) {
      return persistWindowStateSnapshot(
        put: (key, value) => box.put(key, value),
        snapshot: snapshot,
      );
    }

    await persist(resolvedState);
    final stateController = DesktopWindowStateController(
      initialState: resolvedState,
      persist: persist,
      platform: statePlatform,
    );
    DesktopAppShutdownService.setWindowStateFlushHandler(stateController.flush);

    await windowManager.setMinimumSize(
      const Size(minimumWindowWidth, minimumWindowHeight),
    );
    AppLogger.d('Desktop window restore plan prepared', 'Main');

    final initialLogicalSize = Platform.isWindows
        ? Size(
            restorePlan.normalBounds.width / legacyScale,
            restorePlan.normalBounds.height / legacyScale,
          )
        : restorePlan.normalBounds.size;
    return _DesktopWindowConfiguration(
      options: WindowOptions(
        size: initialLogicalSize,
        minimumSize: const Size(minimumWindowWidth, minimumWindowHeight),
        center: false,
        backgroundColor: const Color(0xFF121212),
        skipTaskbar: false,
        titleBarStyle: Platform.isWindows
            ? TitleBarStyle.hidden
            : TitleBarStyle.normal,
        windowButtonVisibility: !Platform.isWindows,
        title: 'NAI Launcher',
      ),
      restorePlan: restorePlan,
      stateController: stateController,
      nativePlatform: nativePlatform,
    );
  } catch (error, stackTrace) {
    AppLogger.e('Desktop window preparation failed', error, stackTrace, 'Main');
    rethrow;
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
