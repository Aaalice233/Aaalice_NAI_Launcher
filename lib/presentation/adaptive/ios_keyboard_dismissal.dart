import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../core/platform/platform_capabilities.dart';

/// iOS 上点输入框外部即收起键盘。
///
/// Flutter 在 Android / iOS 上对触摸点击输入框外部默认不失焦
/// （`EditableText` 的 `_EditableTextTapOutsideAction`）。Android 有系统返回手势
/// 收起键盘，桌面没有软键盘；iOS 两者都没有，没单独写 `onTapOutside` 的输入框
/// 一旦弹出键盘就收不回去。
///
/// 这里在应用根部覆盖 [EditableTextTapOutsideIntent]：
/// - 显式传了 `onTapOutside` 的输入框不走这个 intent，行为不变；
/// - 自动补全浮层等用 `TextFieldTapRegion` 登记为输入框一部分的区域不算外部，
///   点候选词不会收起键盘；
/// - 非 iOS 平台原样返回 [child]，不改变现有行为。
class IosKeyboardDismissal extends StatelessWidget {
  const IosKeyboardDismissal({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!PlatformCapabilities.current.isIOS) return child;
    return Actions(
      actions: <Type, Action<Intent>>{
        EditableTextTapOutsideIntent: _UnfocusOnTapOutsideAction(),
      },
      child: child,
    );
  }
}

class _UnfocusOnTapOutsideAction extends Action<EditableTextTapOutsideIntent> {
  @override
  void invoke(EditableTextTapOutsideIntent intent) {
    // 与框架默认一致：触控板按下不应出现在这里，忽略而不是抛错。
    if (intent.pointerDownEvent.kind == PointerDeviceKind.trackpad) return;
    intent.focusNode.unfocus();
  }
}
