import 'package:flutter/widgets.dart';

import '../utils/app_background_return.dart';
import '../utils/app_logger.dart';
import '../utils/file_system_error_summary.dart';
import 'desktop_window_state_controller.dart';

/// 窗口离开屏幕时把最后一个有效的普通窗口状态写盘。
class DesktopWindowStateObserver extends WidgetsBindingObserver {
  DesktopWindowStateObserver(
    this.controller, {
    Future<void> Function() flushLogs = AppLogger.flush,
  }) : _flushLogs = flushLogs,
       _visibility = AppBackgroundReturnTracker(
         initialState: WidgetsBinding.instance.lifecycleState,
       );

  final DesktopWindowStateController controller;
  final Future<void> Function() _flushLogs;
  final AppBackgroundReturnTracker _visibility;

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    // Windows 最小化只报 hidden 不报 paused；只在可见变为不可见那一次写，后续 paused、detached 不再重复
    if (_visibility.observe(state) != AppVisibilityChange.leftView) return;

    try {
      await controller.flush();
      await _flushLogs();
    } catch (error) {
      final cause = error is WindowStatePersistenceException
          ? error.cause
          : error;
      AppLogger.e(
        'Failed to flush window state after the window left the screen',
        fileSystemErrorSummary(cause),
        null,
        'WindowState',
      );
    }
  }
}
