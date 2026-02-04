import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'package:timeago/timeago.dart' as timeago;

import 'core/constants/storage_keys.dart';
import 'core/network/proxy_service.dart';
import 'core/network/system_proxy_http_overrides.dart';
import 'core/utils/app_logger.dart';
import 'data/datasources/local/nai_tags_data_source.dart';
import 'presentation/screens/splash/app_bootstrap.dart';

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
        final size = await windowManager.getSize();
        final position = await windowManager.getPosition();
        final box = Hive.box(StorageKeys.settingsBox);

        await box.put(StorageKeys.windowWidth, size.width);
        await box.put(StorageKeys.windowHeight, size.height);
        await box.put(StorageKeys.windowX, position.dx);
        await box.put(StorageKeys.windowY, position.dy);

        AppLogger.i(
          'Window state saved: ${size.width}x${size.height} at (${position.dx}, ${position.dy})',
          'Main',
        );
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
        // 1. 先销毁托盘图标，避免残留在系统托盘中
        await trayManager.destroy();
        // 2. 解除 preventClose，再销毁窗口
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
        AppLogger.d('Application exited via tray menu', 'TrayListener');
        // 强制退出进程，确保 dart.exe 不会残留
        exit(0);
      }
    } catch (e) {
      AppLogger.e('Failed to handle tray menu click: $e', 'TrayListener');
    }
  }
}

/// 窗口监听器，处理窗口关闭和显示事件
class AppWindowListener extends WindowListener {
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
    AppLogger.d('Window focused', 'WindowListener');
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 增加图片缓存限制，防止本地画廊滚动时图片被回收变白
  PaintingBinding.instance.imageCache.maximumSize = 500; // 最大缓存 500 张图片
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20; // 200MB

  // 初始化 Windows 视频播放支持
  VideoPlayerMediaKit.ensureInitialized(
    windows: true,
  );

  // 初始化日志系统
  await AppLogger.init();

  // 初始化 SQLite FFI（Windows/Linux 桌面端必需）
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppLogger.i('SQLite FFI initialized for desktop', 'Main');
  }

  // 初始化 Hive
  await Hive.initFlutter();

  // 预先打开 Hive boxes (确保 LocalStorageService 可用)
  await Hive.openBox(StorageKeys.settingsBox);
  await Hive.openBox(StorageKeys.historyBox);
  await Hive.openBox(StorageKeys.tagCacheBox);
  await Hive.openBox(StorageKeys.galleryBox);
  await Hive.openBox(StorageKeys.localMetadataCacheBox);
  // Local Gallery 新功能所需的 Hive boxes
  await Hive.openBox(StorageKeys.localFavoritesBox);
  await Hive.openBox(StorageKeys.tagsBox);
  await Hive.openBox(StorageKeys.searchIndexBox);
  // 统计数据缓存 Box
  await Hive.openBox(StorageKeys.statisticsCacheBox);
  // 队列相关 Box（预加载以避免首次打开队列管理页面时的延迟）
  await Hive.openBox<String>(StorageKeys.replicationQueueBox);
  await Hive.openBox<String>(StorageKeys.queueExecutionStateBox);

  // Timeago 本地化配置
  timeago.setLocaleMessages('zh', timeago.ZhCnMessages());
  timeago.setLocaleMessages('zh_CN', timeago.ZhCnMessages());

  // 后台预加载 NAI 标签数据（不阻塞启动）
  final container = ProviderContainer();
  Future.microtask(() async {
    try {
      await container.read(naiTagsDataSourceProvider).loadData();
      AppLogger.d('NAI tags preloaded successfully', 'Main');
    } catch (e) {
      AppLogger.w('NAI tags preload failed: $e', 'Main');
      // 预加载失败不影响应用启动
    }
  });

  // 桌面端窗口配置
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    
    // 设置 Windows 唤醒消息处理（单实例唤醒）
    if (Platform.isWindows) {
      setupWindowsWakeUpChannel();
    }

    // 从 Hive 读取保存的窗口状态
    final box = Hive.box(StorageKeys.settingsBox);
    final savedWidth =
        box.get(StorageKeys.windowWidth, defaultValue: 1400.0) as double;
    final savedHeight =
        box.get(StorageKeys.windowHeight, defaultValue: 900.0) as double;
    final savedX = box.get(StorageKeys.windowX) as double?;
    final savedY = box.get(StorageKeys.windowY) as double?;

    final windowOptions = WindowOptions(
      size: Size(savedWidth, savedHeight),
      minimumSize: const Size(800, 600),
      center: savedX == null || savedY == null, // 首次启动居中，之后恢复位置
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'NAI Launcher',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      // 如果有保存的位置，恢复窗口位置
      if (savedX != null && savedY != null) {
        await windowManager.setPosition(Offset(savedX, savedY));
        AppLogger.d(
          'Window state restored: ${savedWidth}x$savedHeight at ($savedX, $savedY)',
          'Main',
        );
      } else {
        AppLogger.d(
          'Window initialized with default state: ${savedWidth}x$savedHeight (centered)',
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

        final menu = Menu(
          items: [
            MenuItem(
              key: 'show',
              label: '显示窗口',
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'exit',
              label: '退出',
            ),
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
  }

  // 系统代理配置（根据用户设置）
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final settingsBox = Hive.box(StorageKeys.settingsBox);
    final proxyEnabled =
        settingsBox.get(StorageKeys.proxyEnabled, defaultValue: true) as bool;

    if (proxyEnabled) {
      final proxyMode = settingsBox.get(
        StorageKeys.proxyMode,
        defaultValue: 'auto',
      ) as String;

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

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AppBootstrap(),
    ),
  );
}
