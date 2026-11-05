import 'package:flutter/widgets.dart';

import 'app_lifecycle_visibility.dart';

// 桌面切换窗口焦点只在 inactive 与 resumed 之间往返，不算从后台返回。

final class AppBackgroundReturnTracker {
  bool _leftView = false;

  /// 送入每一次生命周期变化；窗口离开过屏幕后第一次重新可见（含未获得焦点）时返回 true。
  bool returnedToView(AppLifecycleState state) {
    if (!AppLifecycleVisibility.isVisible(state)) {
      _leftView = true;
      return false;
    }
    if (!_leftView) return false;
    _leftView = false;
    return true;
  }
}

/// 只在窗口离开过屏幕、再重新可见时回调 [onReturn]。
final class AppBackgroundReturnListener {
  AppBackgroundReturnListener({required VoidCallback onReturn}) {
    _listener = AppLifecycleListener(
      onStateChange: (state) {
        if (_tracker.returnedToView(state)) onReturn();
      },
    );
  }

  final AppBackgroundReturnTracker _tracker = AppBackgroundReturnTracker();
  late final AppLifecycleListener _listener;

  void dispose() => _listener.dispose();
}
