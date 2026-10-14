import 'package:flutter/widgets.dart';

/// 页面的焦点归属：焦点退回到所在作用域本身时收回到 [focusNode]
/// 输入框点外部失焦、焦点子树被移除后，焦点会停在路由作用域上，位于页面按键处理器之上
class FallbackFocusHome extends StatefulWidget {
  const FallbackFocusHome({
    super.key,
    required this.focusNode,
    required this.child,
    this.enabled = true,
  });

  /// 收回焦点的节点，必须与本组件处在同一个焦点作用域内
  final FocusNode focusNode;

  final Widget child;

  /// 关闭时只透传子组件，不改变结构
  final bool enabled;

  @override
  State<FallbackFocusHome> createState() => _FallbackFocusHomeState();
}

class _FallbackFocusHomeState extends State<FallbackFocusHome> {
  FocusScopeNode? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = FocusScope.of(context);
    if (identical(scope, _scope)) return;
    _scope?.removeListener(_handleScopeFocusChange);
    _scope = scope..addListener(_handleScopeFocusChange);
  }

  @override
  void dispose() {
    _scope?.removeListener(_handleScopeFocusChange);
    super.dispose();
  }

  void _handleScopeFocusChange() {
    final home = widget.focusNode;
    if (!widget.enabled ||
        !(_scope?.hasPrimaryFocus ?? false) ||
        home.context == null ||
        !home.canRequestFocus) {
      return;
    }
    home.requestFocus();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
