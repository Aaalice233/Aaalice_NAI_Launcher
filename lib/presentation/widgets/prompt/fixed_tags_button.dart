import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/layout_state_provider.dart';
import 'fixed_tags_dialog.dart';

/// 固定词按钮组件
/// 显示当前启用的固定词数量，点击打开管理对话框
class FixedTagsButton extends ConsumerStatefulWidget {
  const FixedTagsButton({
    super.key,
    this.compact = false,
    this.iconOnly = false,
    this.maxLabelWidth,
  });

  /// 经典桌面提示词工具栏使用紧凑外观；触屏和独立入口保留标准命中高度。
  final bool compact;
  final bool iconOnly;
  final double? maxLabelWidth;

  @override
  ConsumerState<FixedTagsButton> createState() => _FixedTagsButtonState();
}

class _FixedTagsButtonState extends ConsumerState<FixedTagsButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fixedTagsState = ref.watch(fixedTagsNotifierProvider);
    final enabledCount = fixedTagsState.entries
        .where((entry) => entry.enabled)
        .length;
    final hasEntries = fixedTagsState.entries.isNotEmpty;
    final hasEnabled = enabledCount > 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        richMessage: WidgetSpan(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: _buildTooltipContent(theme, fixedTagsState),
          ),
        ),
        preferBelow: true,
        verticalOffset: 20,
        waitDuration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Semantics(
          button: true,
          label: context.l10n.fixedTags_label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final sidebarExpanded = ref.read(
                layoutStateNotifierProvider.select(
                  (state) => state.fixedTagsSidebarExpanded,
                ),
              );
              if (!sidebarExpanded) {
                _showFixedTagsDialog(context);
              }
            },
            onLongPress: () => ref
                .read(layoutStateNotifierProvider.notifier)
                .toggleFixedTagsSidebar(),
            child: AnimatedContainer(
              key: const Key('fixed-tags-button-surface'),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              constraints: BoxConstraints(minHeight: widget.compact ? 36 : 44),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 8 : 10,
                vertical: widget.compact ? 4 : 6,
              ),
              decoration: BoxDecoration(
                color: hasEnabled
                    ? theme.colorScheme.secondary.withValues(
                        alpha: _isHovering ? 0.18 : 0.12,
                      )
                    : (_isHovering
                          ? theme.colorScheme.surfaceContainerHigh
                          : theme.colorScheme.surfaceContainerLow),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasEnabled ? Icons.push_pin : Icons.push_pin_outlined,
                    size: widget.compact ? 15 : 16,
                    color: hasEnabled
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  if (!widget.iconOnly) ...[
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: widget.maxLabelWidth ?? double.infinity,
                      ),
                      child: Text(
                        context.l10n.fixedTags_label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.compact ? 11 : 12,
                          fontWeight: hasEnabled
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: hasEnabled
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                    ),
                  ],
                  if (hasEnabled) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        enabledCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ] else if (hasEntries) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.visibility_off,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTooltipContent(ThemeData theme, FixedTagsState state) {
    final entries = state.entries;

    if (entries.isEmpty) {
      return _buildEmptyState(theme);
    }

    final enabledPrefixes = [
      ...state.enabledPrefixes,
      ...state.negativeEnabledPrefixes,
    ].take(4).toList(growable: false);
    final enabledSuffixes = [
      ...state.enabledSuffixes,
      ...state.negativeEnabledSuffixes,
    ].take(4).toList(growable: false);
    final disabledEntries = entries.where((e) => !e.enabled).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部双列统计卡片
        _buildStatisticsHeader(
          theme,
          enabledPrefixes.length,
          enabledSuffixes.length,
          state.links.length,
        ),

        // 启用的条目列表
        if (enabledPrefixes.isNotEmpty || enabledSuffixes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildEnabledEntriesSection(theme, enabledPrefixes, enabledSuffixes),
        ],

        // 禁用的条目
        if (disabledEntries.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildDisabledSection(theme, disabledEntries),
        ],

        // 底部操作提示
        const SizedBox(height: 10),
        _buildFooterHint(theme),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.push_pin_outlined,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.fixedTags_empty,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.fixedTags_clickManageLongPressSidebar,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsHeader(
    ThemeData theme,
    int prefixCount,
    int suffixCount,
    int linkCount,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.push_pin_rounded,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.fixedTags_label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        _buildCompactStat(
          theme,
          icon: Icons.arrow_forward_rounded,
          count: prefixCount,
          label: context.l10n.fixedTags_prefix,
          color: theme.colorScheme.primary,
          isActive: prefixCount > 0,
        ),
        const SizedBox(width: 10),
        _buildCompactStat(
          theme,
          icon: Icons.arrow_back_rounded,
          count: suffixCount,
          label: context.l10n.fixedTags_suffix,
          color: theme.colorScheme.tertiary,
          isActive: suffixCount > 0,
        ),
        if (linkCount > 0) ...[
          const SizedBox(width: 10),
          _buildCompactStat(
            theme,
            icon: Icons.link_rounded,
            count: linkCount,
            label: context.l10n.fixedTags_linked,
            color: theme.colorScheme.secondary,
            isActive: true,
          ),
        ],
      ],
    );
  }

  /// 紧凑统计项
  Widget _buildCompactStat(
    ThemeData theme, {
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required bool isActive,
  }) {
    final displayColor = isActive ? color : theme.colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: displayColor),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: displayColor,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: displayColor.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// 启用条目列表区域
  Widget _buildEnabledEntriesSection(
    ThemeData theme,
    List<FixedTagEntry> prefixes,
    List<FixedTagEntry> suffixes,
  ) {
    final allEnabled = [
      ...prefixes.map((e) => (entry: e, isPrefix: true)),
      ...suffixes.map((e) => (entry: e, isPrefix: false)),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < allEnabled.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildCompactEntryRow(
            theme,
            allEnabled[i].entry,
            allEnabled[i].isPrefix,
          ),
        ],
      ],
    );
  }

  Widget _buildCompactEntryRow(
    ThemeData theme,
    FixedTagEntry entry,
    bool isPrefix,
  ) {
    final color = isPrefix
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    final content = entry.content.trim();

    return Row(
      children: [
        Icon(
          isPrefix ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (content.isNotEmpty)
                Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (entry.weight != 1.0) ...[
          const SizedBox(width: 8),
          Text(
            '${entry.weight.toStringAsFixed(1)}×',
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
        if (entry.sourceEntryId != null) ...[
          const SizedBox(width: 6),
          Icon(Icons.sync_alt_rounded, size: 12, color: color),
        ],
      ],
    );
  }

  Widget _buildDisabledSection(
    ThemeData theme,
    List<FixedTagEntry> disabledEntries,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.visibility_off_rounded,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                '${context.l10n.fixedTags_disabled} ${disabledEntries.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              ...disabledEntries
                  .take(3)
                  .map((entry) => _buildDisabledChip(theme, entry)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterHint(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.touch_app_rounded,
          size: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          context.l10n.fixedTags_clickManageLongPressCompact,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledChip(ThemeData theme, FixedTagEntry entry) {
    return Text(
      entry.displayName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        decoration: TextDecoration.lineThrough,
      ),
    );
  }

  void _showFixedTagsDialog(BuildContext context) {
    FixedTagsDialog.show(context);
  }
}
