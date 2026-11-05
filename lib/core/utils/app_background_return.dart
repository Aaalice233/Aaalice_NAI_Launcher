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
