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
          padding: const EdgeInsets.only(
            left: 16,
            top: 10,
            right: 8,
            bottom: 10,
          ),
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
              final showSelectionLabels = constraints.maxWidth >= 1180;
              final compactActions = constraints.maxWidth < 1180;

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
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
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
                    icon: isAllSelected
                        ? Icons.indeterminate_check_box_outlined
                        : Icons.check_box_outlined,
                    label: isAllSelected
                        ? deselectAllLabel ?? l10n.common_deselectAll
                        : selectAllLabel ?? l10n.common_selectAll,
                    onPressed: onSelectAll,
                    compact: !showSelectionLabels,
                    isActive: isAllSelected,
                  ),
                  if (onSelectAllAvailable != null) ...[
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: isAllAvailableSelected
                          ? Icons.remove_done
                          : Icons.done_all,
                      label: isAllAvailableSelected
                          ? deselectAllAvailableLabel ?? l10n.common_deselectAll
                          : selectAllAvailableLabel ?? l10n.common_selectAll,
                      onPressed: onSelectAllAvailable,
                      compact: !showSelectionLabels,
                      isActive: isAllAvailableSelected,
                    ),
                  ],

                  const SizedBox(width: 12),

                  // Expanded + Align makes the action group meet the trailing
                  // edge instead of inheriting spare space from the left group.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow
                              .withValues(alpha: isDark ? 0.56 : 0.72),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int i = 0; i < actions.length; i++) ...[
                                if (i > 0) ...[
                                  if (actions[i].showDividerBefore)
                                    Container(
                                      width: 1,
                                      height: 22,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.55),
                                    )
                                  else
                                    const SizedBox(width: 2),
                                ],
                                _ActionButton(
                                  icon: actions[i].icon,
                                  label: actions[i].label,
                                  onPressed: hasSelection
                                      ? actions[i].onPressed
                                      : null,
                                  color: actions[i].color,
                                  isDanger: actions[i].isDanger,
                                  compact: compactActions,
                                  prominent: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
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
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isDanger;
  final bool compact;
  final bool prominent;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.isDanger = false,
    this.compact = false,
    this.prominent = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = color ?? colorScheme.primary;

    Color foreground(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) {
        return colorScheme.onSurface.withValues(alpha: 0.32);
      }
      if (isDanger) return colorScheme.error;
      if (isActive) return colorScheme.onPrimaryContainer;
      if (prominent) return colorScheme.onSurfaceVariant;
      return colorScheme.onSurface;
    }

    Color background(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (isActive) {
        return colorScheme.primaryContainer.withValues(
          alpha: states.contains(WidgetState.hovered) ? 1 : 0.82,
        );
      }
      if (states.contains(WidgetState.pressed)) {
        return isDanger
            ? colorScheme.errorContainer.withValues(alpha: 0.72)
            : colorScheme.surfaceContainerHighest;
      }
      if (states.contains(WidgetState.hovered)) {
        return isDanger
            ? colorScheme.errorContainer.withValues(alpha: 0.48)
            : colorScheme.surfaceContainerHigh;
      }
      return Colors.transparent;
    }

    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(40, 38)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: compact ? 10 : 11, vertical: 8),
      ),
      foregroundColor: WidgetStateProperty.resolveWith(foreground),
      backgroundColor: WidgetStateProperty.resolveWith(background),
      overlayColor: WidgetStatePropertyAll(
        accentColor.withValues(alpha: isDanger ? 0.10 : 0.08),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      side: const WidgetStatePropertyAll(BorderSide.none),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      visualDensity: VisualDensity.standard,
    );

    return Tooltip(
      message: label,
      child: TextButton(
        onPressed: onPressed,
        style: style,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: prominent || isDanger || isActive ? null : accentColor,
            ),
            if (!compact) ...[const SizedBox(width: 6), Text(label)],
          ],
        ),
      ),
    );
  }
}
