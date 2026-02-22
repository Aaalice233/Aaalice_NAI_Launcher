import 'package:flutter/material.dart';

/// 悬浮操作按钮组
/// 
/// 用于图片卡片等场景，在悬浮时显示的操作按钮组。
/// 特点：
/// - 自动处理悬浮显示/隐藏动画
/// - 阻止点击事件穿透到父级
/// - 即使鼠标移开（透明度为0）也能保持点击状态
/// - 支持自定义按钮列表
///
/// 使用示例：
/// ```dart
/// FloatingActionButtons(
///   isVisible: _isHovered,
///   buttons: [
///     FloatingActionButtonData(
///       icon: Icons.favorite,
///       onTap: () => toggleFavorite(),
///       iconColor: Colors.red,
///     ),
///     FloatingActionButtonData(
///       icon: Icons.copy,
///       onTap: () => copyToClipboard(),
///     ),
///   ],
/// )
/// ```
class FloatingActionButtons extends StatelessWidget {
  /// 是否显示按钮组
  final bool isVisible;

  /// 按钮列表（从上到下排列）
  final List<FloatingActionButtonData> buttons;

  /// 按钮间距
  final double spacing;

  /// 动画持续时间
  final Duration duration;

  /// 按钮位置（默认右上角）
  final Alignment alignment;

  /// 内边距
  final EdgeInsetsGeometry padding;

  const FloatingActionButtons({
    super.key,
    required this.isVisible,
    required this.buttons,
    this.spacing = 8.0,
    this.duration = const Duration(milliseconds: 150),
    this.alignment = Alignment.topRight,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  Widget build(BuildContext context) {
    // 过滤掉不需要显示的按钮
    final visibleButtons = buttons.where((b) => b.visible).toList();
    if (visibleButtons.isEmpty) return const SizedBox.shrink();

    return AnimatedOpacity(
      duration: duration,
      opacity: isVisible ? 1.0 : 0.0,
      // 即使透明度为0，也保持按钮组可交互（防止点击穿透）
      alwaysIncludeSemantics: true,
      child: Container(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildButtonList(visibleButtons),
        ),
      ),
    );
  }

  List<Widget> _buildButtonList(List<FloatingActionButtonData> buttons) {
    final List<Widget> result = [];

    for (var i = 0; i < buttons.length; i++) {
      final button = buttons[i];
      
      // 添加按钮
      result.add(
        _FloatingActionButtonItem(
          icon: button.icon,
          onTap: button.onTap,
          iconColor: button.iconColor,
          backgroundColor: button.backgroundColor,
          hoverBackgroundColor: button.hoverBackgroundColor,
          size: button.size,
          duration: duration,
        ),
      );

      // 添加间距（最后一个按钮后不加）
      if (i < buttons.length - 1) {
        result.add(SizedBox(height: spacing));
      }
    }

    return result;
  }
}

/// 悬浮按钮数据
class FloatingActionButtonData {
  /// 图标
  final IconData icon;

  /// 点击回调
  final VoidCallback? onTap;

  /// 图标颜色
  final Color? iconColor;

  /// 背景颜色（默认半透明黑）
  final Color? backgroundColor;

  /// 悬浮时的背景颜色
  final Color? hoverBackgroundColor;

  /// 按钮大小
  final double size;

  /// 是否显示此按钮
  final bool visible;

  const FloatingActionButtonData({
    required this.icon,
    this.onTap,
    this.iconColor,
    this.backgroundColor,
    this.hoverBackgroundColor,
    this.size = 28.0,
    this.visible = true,
  });
}

/// 单个悬浮按钮
class _FloatingActionButtonItem extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? hoverBackgroundColor;
  final double size;
  final Duration duration;

  const _FloatingActionButtonItem({
    required this.icon,
    this.onTap,
    this.iconColor,
    this.backgroundColor,
    this.hoverBackgroundColor,
    required this.size,
    required this.duration,
  });

  @override
  State<_FloatingActionButtonItem> createState() => _FloatingActionButtonItemState();
}

class _FloatingActionButtonItemState extends State<_FloatingActionButtonItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? Colors.black.withOpacity(0.6);
    final hoverBgColor = widget.hoverBackgroundColor ?? Colors.black.withOpacity(0.85);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        // 执行回调，同时通过 opaque 行为阻止事件冒泡
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          duration: widget.duration,
          scale: _isHovering ? 1.15 : 1.0,
          child: AnimatedContainer(
            duration: widget.duration,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _isHovering ? hoverBgColor : bgColor,
              borderRadius: BorderRadius.circular(widget.size / 2),
              boxShadow: _isHovering
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: widget.size * 0.57, // 图标大小约为按钮的 57%
                color: widget.iconColor ?? Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 悬浮按钮位置枚举
enum FloatingActionButtonsPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// 带位置的悬浮按钮组包装器
/// 
/// 用于需要在特定位置显示悬浮按钮的场景
class PositionedFloatingActionButtons extends StatelessWidget {
  /// 是否显示
  final bool isVisible;

  /// 按钮列表
  final List<FloatingActionButtonData> buttons;

  /// 位置
  final FloatingActionButtonsPosition position;

  /// 距离边缘的偏移
  final EdgeInsetsGeometry margin;

  /// 按钮间距
  final double spacing;

  /// 动画持续时间
  final Duration duration;

  const PositionedFloatingActionButtons({
    super.key,
    required this.isVisible,
    required this.buttons,
    this.position = FloatingActionButtonsPosition.topRight,
    this.margin = const EdgeInsets.all(8.0),
    this.spacing = 8.0,
    this.duration = const Duration(milliseconds: 150),
  });

  @override
  Widget build(BuildContext context) {
    Alignment alignment;
    switch (position) {
      case FloatingActionButtonsPosition.topLeft:
        alignment = Alignment.topLeft;
        break;
      case FloatingActionButtonsPosition.topRight:
        alignment = Alignment.topRight;
        break;
      case FloatingActionButtonsPosition.bottomLeft:
        alignment = Alignment.bottomLeft;
        break;
      case FloatingActionButtonsPosition.bottomRight:
        alignment = Alignment.bottomRight;
        break;
    }

    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: margin,
          child: FloatingActionButtons(
            isVisible: isVisible,
            buttons: buttons,
            spacing: spacing,
            duration: duration,
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
