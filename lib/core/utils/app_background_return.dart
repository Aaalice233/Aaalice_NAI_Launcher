import 'package:flutter/widgets.dart';

import 'app_lifecycle_visibility.dart';

// 桌面切换窗口焦点只在 inactive 与 resumed 之间往返，不算离开或回到屏幕。

enum AppVisibilityChange { unchanged, leftView, returnedToView }

final class AppBackgroundReturnTracker {
  /// [initialState] 为空时按可见处理。
  AppBackgroundReturnTracker({AppLifecycleState? initialState})
    : _visible = AppLifecycleVisibility.isVisible(initialState);

  bool _visible;

  bool get isVisible => _visible;

  /// 送入每一次生命周期变化，返回窗口是否就此离开屏幕或重新可见（含未获得焦点）。
  AppVisibilityChange observe(AppLifecycleState state) {
    final visible = AppLifecycleVisibility.isVisible(state);
    if (visible == _visible) return AppVisibilityChange.unchanged;
    _visible = visible;
    return visible
        ? AppVisibilityChange.returnedToView
        : AppVisibilityChange.leftView;
  }

  /// 窗口离开过屏幕后第一次重新可见（含未获得焦点）时返回 true。
  bool returnedToView(AppLifecycleState state) =>
      observe(state) == AppVisibilityChange.returnedToView;
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

  final AppBackgroundReturnTracker _tracker = AppBackgroundReturnTracker(
    initialState: WidgetsBinding.instance.lifecycleState,
  );
  late final AppLifecycleListener _listener;

  void dispose() => _listener.dispose();
}
