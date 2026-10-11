import 'dart:async';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../database/database_manager.dart';
import '../utils/app_logger.dart';

/// 桌面应用统一退出入口。
///
/// 更新安装和托盘退出都必须先释放数据库、托盘与窗口资源，避免直接
/// `exit` 留下未刷新的日志或 Windows 文件锁。
class DesktopAppShutdownService {
  DesktopAppShutdownService._();

  static Future<void>? _shutdownFuture;
  static bool get isShuttingDown => _shutdownFuture != null;
  static Future<void> Function()? _windowStateFlushHandler;

  static void setWindowStateFlushHandler(Future<void> Function() handler) {
    _windowStateFlushHandler = handler;
  }

  static final List<Future<void> Function()> _cleanupHandlers = [];

  /// 托盘退出直接 `exit`，ProviderContainer 不会被释放，需要在这里注销外部资源。
  static void Function() addCleanupHandler(Future<void> Function() handler) {
    _cleanupHandlers.add(handler);
    return () => _cleanupHandlers.remove(handler);
  }

  static Future<void> shutdownAndExit(int code) {
    return _shutdownFuture ??= _performShutdown(code);
  }

  static Future<void> _performShutdown(int code) async {
    AppLogger.i('Application shutdown started', 'AppShutdown');

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Hide immediately without destroying the engine needed to finish cleanup.
      try {
        await windowManager.hide();
      } catch (error, stackTrace) {
        AppLogger.e(
          'Window hide failed during shutdown',
          error,
          stackTrace,
          'AppShutdown',
        );
      }
      try {
        await trayManager.destroy();
      } catch (error) {
        AppLogger.w('Tray shutdown failed: $error', 'AppShutdown');
      }
    }

    try {
      await _windowStateFlushHandler?.call();
      AppLogger.i('Window state flushed successfully', 'AppShutdown');
    } catch (error, stackTrace) {
      AppLogger.e(
        'Window state flush failed during shutdown',
        error,
        stackTrace,
        'AppShutdown',
      );
    }

    for (final handler in List.of(_cleanupHandlers)) {
      try {
        await handler();
      } catch (error) {
        AppLogger.w('Shutdown cleanup failed: $error', 'AppShutdown');
      }
    }

    try {
      await DatabaseManager.instance.dispose();
      AppLogger.i('Database closed successfully', 'AppShutdown');
    } catch (error) {
      AppLogger.w('Database shutdown skipped or failed: $error', 'AppShutdown');
    }

    try {
      await Hive.close();
      AppLogger.i('Hive boxes closed successfully', 'AppShutdown');
    } catch (error) {
      AppLogger.w('Hive shutdown skipped or failed: $error', 'AppShutdown');
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      try {
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
      } catch (error) {
        AppLogger.w('Window shutdown failed: $error', 'AppShutdown');
      }
    }

    AppLogger.i('Application shutdown completed', 'AppShutdown');
    await AppLogger.flush();
    exit(code);
  }
}
