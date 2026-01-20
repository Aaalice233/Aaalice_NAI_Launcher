import 'dart:ui';
import 'package:flutter/material.dart';
import '../../themes/design_tokens.dart';

/// 多选工具栏操作项
class SelectionAction {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const SelectionAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });
}

/// 多选工具栏组件
/// 
/// 特性：
/// - 底部浮动
/// - 毛玻璃效果
/// - 进入/退出动画
class SelectionToolbar extends StatefulWidget {
  /// 是否显示
  final bool visible;
  
  /// 选中数量
  final int selectedCount;
  
  /// 退出多选回调
  final VoidCallback onExit;
  
  /// 操作按钮列表
  final List<SelectionAction> actions;

  const SelectionToolbar({
    super.key,
    required this.visible,
    required this.selectedCount,
    required this.onExit,
    required this.actions,
  });

  @override
  State<SelectionToolbar> createState() => _SelectionToolbarState();
}

class _SelectionToolbarState extends State<SelectionToolbar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: DesignTokens.animationNormal,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: DesignTokens.curveEnter,
      reverseCurve: DesignTokens.curveExit,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: DesignTokens.curveEnter,
    ));

    if (widget.visible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: EdgeInsets.all(DesignTokens.spacingMd),
          child: ClipRRect(
            borderRadius: DesignTokens.borderRadiusLg,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: DesignTokens.glassBlurRadius,
                sigmaY: DesignTokens.glassBlurRadius,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacingMd,
                  vertical: DesignTokens.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh
                      .withOpacity(DesignTokens.glassOpacity),
                  borderRadius: DesignTokens.borderRadiusLg,
                  border: Border.all(
                    color: theme.colorScheme.outline
                        .withOpacity(DesignTokens.glassBorderOpacity),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.15),
                      blurRadius: DesignTokens.glassBlurRadius,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 关闭按钮
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onExit,
                      tooltip: '退出多选',
                      iconSize: DesignTokens.iconMd,
                    ),
                    SizedBox(width: DesignTokens.spacingXs),
                    
                    // 选中数量
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacingSm,
                        vertical: DesignTokens.spacingXxs,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: DesignTokens.borderRadiusSm,
                      ),
                      child: Text(
                        '已选择 ${widget.selectedCount} 项',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    SizedBox(width: DesignTokens.spacingMd),
                    
                    // 分隔线
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                    
                    SizedBox(width: DesignTokens.spacingSm),
                    
                    // 操作按钮
                    ...widget.actions.map((action) => IconButton(
                      icon: Icon(action.icon),
                      onPressed: action.onPressed,
                      tooltip: action.tooltip,
                      iconSize: DesignTokens.iconMd,
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
