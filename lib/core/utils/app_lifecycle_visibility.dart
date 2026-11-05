import 'package:flutter/widgets.dart' show AppLifecycleState;

// 桌面窗口失焦只报 inactive，画面仍在屏幕上；hidden、paused、detached 才算看不见。

abstract final class AppLifecycleVisibility {
  /// 还没收到生命周期时按可见处理。
  static bool isVisible(AppLifecycleState? state) => switch (state) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
  };
}
