import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

/// 通用批量操作工具栏
///
/// 用于本地画廊、在线画廊和Vibe库的批量操作
class BulkActionBar extends StatelessWidget {
  /// 选中数量
  final int selectedCount;

  /// 是否已全选
  final bool isAllSelected;

  /// 是否已选中全部可用项目（例如全部搜索结果）
  final bool isAllAvailableSelected;

  /// 退出多选模式回调
  final VoidCallback? onExit;

  /// 全选/取消全选回调
  final VoidCallback? onSelectAll;

  /// 选择/取消全部可用项目回调
  final VoidCallback? onSelectAllAvailable;

  /// 操作按钮列表
  final List<BulkActionItem> actions;

  /// 当前范围选择标签
  final String? selectAllLabel;
  final String? deselectAllLabel;

  /// 全部可用项目选择标签
  final String? selectAllAvailableLabel;
  final String? deselectAllAvailableLabel;

  const BulkActionBar({
    super.key,
    required this.selectedCount,
    required this.isAllSelected,
    this.isAllAvailableSelected = false,
    this.onExit,
    this.onSelectAll,
    this.onSelectAllAvailable,
    this.actions = const [],
    this.selectAllLabel,
    this.deselectAllLabel,
    this.selectAllAvailableLabel,
    this.deselectAllAvailableLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;
    final hasSelection = selectedCount > 0;

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surface.withValues(alpha: 0.9)
                : theme.colorScheme.surface.withValues(alpha: 0.95),
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(
                  alpha: isDark ? 0.15 : 0.2,
                ),
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactActions = constraints.maxWidth < 900;

              return Row(
                children: [
                  // 退出按钮
                  _ActionButton(
                    icon: Icons.close,
                    label: l10n.common_exit,
                    onPressed: onExit,
                    compact: true,
                  ),
                  const SizedBox(width: 12),

                  // 选中数量徽章
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.8,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.bulkAction_selectedCount(selectedCount),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 全选/取消全选按钮
                  _ActionButton(
                    icon: isAllSelected ? Icons.deselect : Icons.select_all,
                    label: isAllSelected
                        ? deselectAllLabel ?? l10n.common_deselectAll
                        : selectAllLabel ?? l10n.common_selectAll,
                    onPressed: onSelectAll,
                    compact: true,
                  ),
                  if (onSelectAllAvailable != null) ...[
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: isAllAvailableSelected
                          ? Icons.deselect
                          : Icons.library_add_check_outlined,
                      label: isAllAvailableSelected
                          ? deselectAllAvailableLabel ?? l10n.common_deselectAll
                          : selectAllAvailableLabel ?? l10n.common_selectAll,
                      onPressed: onSelectAllAvailable,
                      compact: true,
                    ),
                  ],

                  const Spacer(),

                  // 操作按钮组
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < actions.length; i++) ...[
                        if (i > 0 && actions[i].showDividerBefore) ...[
                          const SizedBox(width: 16),
                          Container(
                            width: 1,
                            height: 28,
                            color: theme.dividerColor.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 16),
                        ] else if (i > 0)
                          const SizedBox(width: 8),
                        _ActionButton(
                          icon: actions[i].icon,
                          label: actions[i].label,
                          onPressed: hasSelection ? actions[i].onPressed : null,
                          color: actions[i].color,
                          isDanger: actions[i].isDanger,
                          compact: compactActions,
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 批量操作项配置
class BulkActionItem {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isDanger;
  final bool showDividerBefore;

  /// 选中项的ID列表（用于需要上下文的操作）
  final List<String>? selectedIds;

  const BulkActionItem({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.isDanger = false,
    this.showDividerBefore = false,
    this.selectedIds,
  });
}

/// Action button with icon and optional label
/// 带图标和可选标签的操作按钮
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isDanger;
  final bool compact;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.isDanger = false,
    this.compact = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null;
    final effectiveColor = widget.color ?? theme.colorScheme.onSurface;
    final displayColor = isEnabled
        ? effectiveColor
        : effectiveColor.withValues(alpha: 0.4);

    return MouseRegion(
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 10 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDanger
                        ? effectiveColor.withValues(alpha: isDark ? 0.2 : 0.12)
                        : effectiveColor.withValues(
                            alpha: isDark ? 0.15 : 0.08,
                          ))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: _isHovered
                  ? Border.all(
                      color: effectiveColor.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : Border.all(color: Colors.transparent, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 18, color: displayColor),
                if (!widget.compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: displayColor,
                      fontWeight: _isHovered
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
