import 'package:flutter/material.dart';

/// 折叠状态面板
///
/// 当面板折叠时显示的垂直指示器，包含图标和垂直旋转的标签。
/// 悬停时整块高亮，图标与文字变亮；[active] 标记当前展开的视图。
class CollapsedPanel extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const CollapsedPanel({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 20, color: contentColor),
                const SizedBox(height: 8),
                RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: contentColor,
                      fontWeight: widget.active
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
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
