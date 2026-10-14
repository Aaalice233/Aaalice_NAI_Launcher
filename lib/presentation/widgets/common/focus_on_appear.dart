import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import '../shortcuts/editable_text_focus.dart';

/// 子组件出现后把焦点交给其中的输入框（没有输入框时交给第一个可聚焦节点）
/// 用于重命名等内联编辑框：autofocus 只在所在作用域没有已聚焦节点时生效，
/// 页面锚点、多选处理器、画布持有焦点时它会被静默丢弃
class FocusOnAppear extends StatefulWidget {
  const FocusOnAppear({super.key, required this.child});

  final Widget child;

  @override
  State<FocusOnAppear> createState() => _FocusOnAppearState();
}

class _FocusOnAppearState extends State<FocusOnAppear> {
  final FocusNode _host = FocusNode(
    debugLabel: 'FocusOnAppear',
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    // 等子树挂上焦点树；关闭菜单引起的焦点恢复也在这之前完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final candidates = _host.descendants.where(
        (node) => node.canRequestFocus,
      );
      (candidates.firstWhereOrNull(isEditableTextNode) ??
              candidates.firstOrNull)
          ?.requestFocus();
    });
  }

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Focus(focusNode: _host, child: widget.child);
}
