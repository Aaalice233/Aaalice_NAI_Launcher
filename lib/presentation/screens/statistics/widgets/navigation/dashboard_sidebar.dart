import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../themes/theme_extension.dart';

/// Dashboard sidebar navigation for statistics screen
/// 仪表盘左侧边栏导航组件
class DashboardSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onIndexChanged;
  final List<DashboardNavItem> items;
  final bool isCollapsed;
  final VoidCallback? onCollapsedChanged;

  const DashboardSidebar({
    super.key,
    required this.selectedIndex,
    required this.onIndexChanged,
    required this.items,
    this.isCollapsed = false,
    this.onCollapsedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final extension = theme.extension<AppThemeExtension>();
    final screenHeight = MediaQuery.of(context).size.height;
    final isCompact = screenHeight < 600;

    // 计算边栏宽度
    final sidebarWidth = isCollapsed ? 64.0 : 200.0;

    // 获取主题相关的装饰
    final blurStrength = extension?.blurStrength ?? 0.0;
    final shadowIntensity = extension?.shadowIntensity ?? 0.15;
    final borderColor = extension?.borderColor ?? colorScheme.outlineVariant;

    // 构建装饰
    final decoration = BoxDecoration(
      color: blurStrength > 0
          ? colorScheme.surface.withOpacity(0.85)
          : colorScheme.surfaceContainerLow,
      border: Border(
        right: BorderSide(
          color: borderColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(shadowIntensity * 0.5),
          blurRadius: 12,
          offset: const Offset(2, 0),
        ),
      ],
    );

    Widget content = Container(
      width: sidebarWidth,
      decoration: decoration,
      child: Column(
        children: [
          // 导航项列表
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                vertical: isCompact ? 8 : 16,
                horizontal: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;

                return _DashboardNavTile(
                  icon: item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  isCollapsed: isCollapsed,
                  isCompact: isCompact,
                  onTap: () => onIndexChanged(index),
                );
              },
            ),
          ),
          // 底部折叠按钮（可选）
          if (onCollapsedChanged != null)
            _CollapseButton(
              isCollapsed: isCollapsed,
              onTap: onCollapsedChanged!,
            ),
        ],
      ),
    );

    // 如果启用模糊效果
    if (blurStrength > 0) {
      content = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurStrength,
            sigmaY: blurStrength,
          ),
          child: content,
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOutCubic,
      width: sidebarWidth,
      child: content,
    );
  }
}

/// 单个导航项组件
class _DashboardNavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final bool isCompact;
  final VoidCallback onTap;

  const _DashboardNavTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.isCompact,
    required this.onTap,
  });

  @override
  State<_DashboardNavTile> createState() => _DashboardNavTileState();
}

class _DashboardNavTileState extends State<_DashboardNavTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 计算颜色
    final backgroundColor = widget.isSelected
        ? colorScheme.primary.withOpacity(0.15)
        : _isHovered
            ? colorScheme.onSurface.withOpacity(0.08)
            : Colors.transparent;

    final iconColor = widget.isSelected
        ? colorScheme.primary
        : _isHovered
            ? colorScheme.onSurface
            : colorScheme.onSurfaceVariant;

    final textColor = widget.isSelected
        ? colorScheme.primary
        : _isHovered
            ? colorScheme.onSurface
            : colorScheme.onSurfaceVariant;

    // 获取边框圆角
    final borderRadius = BorderRadius.circular(12);

    // 计算尺寸
    final tileHeight = widget.isCompact ? 44.0 : 48.0;
    final iconSize = widget.isCompact ? 20.0 : 22.0;

    Widget tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: tileHeight,
      margin: EdgeInsets.symmetric(vertical: widget.isCompact ? 2 : 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: widget.isSelected
            ? Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1,
              )
            : null,
        boxShadow: widget.isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: borderRadius,
          onHover: (hovering) {
            setState(() => _isHovered = hovering);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCollapsed ? 0 : 12,
            ),
            child: widget.isCollapsed
                ? Center(
                    child: Icon(
                      widget.icon,
                      size: iconSize,
                      color: iconColor,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        widget.icon,
                        size: iconSize,
                        color: iconColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            fontWeight: widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    // 折叠模式下添加 Tooltip
    if (widget.isCollapsed) {
      tile = Tooltip(
        message: widget.label,
        preferBelow: false,
        child: tile,
      );
    }

    return tile;
  }
}

/// 折叠按钮组件
class _CollapseButton extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onTap;

  const _CollapseButton({
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: AnimatedRotation(
          duration: const Duration(milliseconds: 200),
          turns: isCollapsed ? 0.5 : 0,
          child: const Icon(Icons.chevron_left),
        ),
        tooltip: isCollapsed ? '展开' : '折叠',
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 导航项数据模型
class DashboardNavItem {
  final IconData icon;
  final String label;
  final String? badge;

  const DashboardNavItem({
    required this.icon,
    required this.label,
    this.badge,
  });
}
