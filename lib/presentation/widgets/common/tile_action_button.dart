import 'package:flutter/material.dart';

import '../../adaptive/interaction_policy.dart';

/// 列表条目行内的密集操作按钮。
///
/// 命中区按交互策略在触屏与指针之间切换，图标尺寸保持不变。
class TileActionButton extends StatefulWidget {
  const TileActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    required this.color,
    required this.hoverColor,
  });

  static const pointerExtent = 25.0;

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color color;
  final Color hoverColor;

  /// 供容器预留空间使用，避免调用方各自硬编码命中区尺寸。
  static double extentOf(BuildContext context) {
    final policy = context.interactionPolicy;
    return policy.touchAvailable ? policy.minimumControlExtent : pointerExtent;
  }

  @override
  State<TileActionButton> createState() => _TileActionButtonState();
}

class _TileActionButtonState extends State<TileActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final interactionPolicy = context.interactionPolicy;
    final extent = TileActionButton.extentOf(context);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: interactionPolicy.precisePointerAvailable
            ? (_) => setState(() => _hovering = true)
            : null,
        onExit: interactionPolicy.precisePointerAvailable
            ? (_) => setState(() => _hovering = false)
            : null,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: extent,
            height: extent,
            child: Center(
              child: Icon(
                widget.icon,
                size: 15,
                color: _hovering ? widget.hoverColor : widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
