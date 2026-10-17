import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import '../shortcuts/editable_text_focus.dart';
import '../shortcuts/fallback_focus_home.dart';

/// 子组件出现后显式请求焦点
/// autofocus 只在所在作用域没有已聚焦节点时生效，页面锚点、多选处理器、画布持有焦点时它会被静默丢弃
class FocusOnAppear extends StatefulWidget {
  /// 焦点交给子树里的输入框，没有输入框时交给第一个可聚焦节点；用于重命名等内联编辑框
  const FocusOnAppear({super.key, required this.child}) : focusSelf = false;

  /// 焦点停在本组件上，子树输入框失焦后也收回到这里；用于弹层，外层的 Esc 等按键绑定始终可达且不弹软键盘
  const FocusOnAppear.self({super.key, required this.child}) : focusSelf = true;

  final bool focusSelf;

  final Widget child;

  @override
  State<FocusOnAppear> createState() => _FocusOnAppearState();
}

class _FocusOnAppearState extends State<FocusOnAppear> {
  late final FocusNode _host = FocusNode(
    debugLabel: 'FocusOnAppear',
    canRequestFocus: widget.focusSelf,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    // 等子树挂上焦点树；关闭菜单引起的焦点恢复也在这之前完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusTarget()?.requestFocus();
    });
  }

  FocusNode? _focusTarget() {
    if (widget.focusSelf) return _host;
    final candidates = _host.descendants.where((node) => node.canRequestFocus);
    return candidates.firstWhereOrNull(isEditableTextNode) ??
        candidates.firstOrNull;
  }

  @override
  void didUpdateWidget(FocusOnAppear oldWidget) {
    super.didUpdateWidget(oldWidget);
    _host.canRequestFocus = widget.focusSelf;
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FallbackFocusHome(
    focusNode: _host,
    enabled: widget.focusSelf,
    child: Focus(focusNode: _host, child: widget.child),
  );
}
