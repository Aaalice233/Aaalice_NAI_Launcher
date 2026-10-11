import 'package:flutter/material.dart';

/// 折叠状态面板
///
/// 当面板折叠时显示的指示条：竖向为图标加旋转标签，横向为图标加标签。
/// 悬停时整块高亮，图标与文字变亮；[active] 标记当前展开的视图。
class CollapsedPanel extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Axis axis;

  const CollapsedPanel({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.axis = Axis.vertical,
  });

  @override
  State<CollapsedPanel> createState() => _CollapsedPanelState();
}

class _CollapsedPanelState extends State<CollapsedPanel> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseAlpha = widget.active ? 0.9 : 0.6;
    final alpha = _hovering ? 0.95 : baseAlpha;
    final contentColor = widget.active
        ? theme.colorScheme.primary.withValues(alpha: alpha)
        : theme.colorScheme.onSurface.withValues(alpha: alpha);
    final icon = Icon(widget.icon, size: 20, color: contentColor);
    final labelStyle = TextStyle(
      fontSize: 12,
      color: contentColor,
      fontWeight: widget.active ? FontWeight.w600 : FontWeight.w400,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: _hovering
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)
            : widget.active
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: SizedBox.expand(
            child: widget.axis == Axis.vertical
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(height: 8),
                      RotatedBox(
                        quarterTurns: 1,
                        child: Text(widget.label, style: labelStyle),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
