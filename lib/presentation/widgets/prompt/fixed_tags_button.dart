import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/layout_state_provider.dart';
import '../common/rich_tooltip_surface.dart';
import '../common/translated_tag_text.dart';
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
          child: RichTooltipSurface(
            maxWidth: 380,
            child: _buildTooltipContent(theme, fixedTagsState),
          ),
        ),
        preferBelow: true,
        verticalOffset: 20,
        waitDuration: const Duration(milliseconds: 300),
        ignorePointer: false,
        decoration: richTooltipOuterDecoration,
        padding: EdgeInsets.zero,
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

    final disabledEntries = entries.where((e) => !e.enabled).toList();
    final enabledCount = entries.where((entry) => entry.enabled).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTooltipHeader(theme, enabledCount, state.links.length),

        if (state.enabledEntries.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildPromptSection(
            theme,
            promptType: FixedTagPromptType.positive,
            prefixes: state.enabledPrefixes,
            suffixes: state.enabledSuffixes,
          ),
        ],
        if (state.negativeEnabledEntries.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildPromptSection(
            theme,
            promptType: FixedTagPromptType.negative,
            prefixes: state.negativeEnabledPrefixes,
            suffixes: state.negativeEnabledSuffixes,
          ),
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

  Widget _buildTooltipHeader(ThemeData theme, int enabledCount, int linkCount) {
    return Row(
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
        Text(
          '${context.l10n.fixedTags_enabled} $enabledCount',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (linkCount > 0) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.link_rounded,
            size: 12,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 3),
          Text(
            '$linkCount',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPromptSection(
    ThemeData theme, {
    required FixedTagPromptType promptType,
    required List<FixedTagEntry> prefixes,
    required List<FixedTagEntry> suffixes,
  }) {
    final isPositive = promptType == FixedTagPromptType.positive;
    final color = isPositive
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    final mutedColor = Color.lerp(
      theme.colorScheme.onSurfaceVariant,
      color,
      0.24,
    )!;
    final allEnabled = [
      ...prefixes.map((e) => (entry: e, isPrefix: true)),
      ...suffixes.map((e) => (entry: e, isPrefix: false)),
    ];

    return Container(
      key: ValueKey(
        isPositive
            ? 'fixed-tags-tooltip-positive'
            : 'fixed-tags-tooltip-negative',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.auto_awesome_rounded : Icons.block_rounded,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isPositive
                      ? context.l10n.prompt_positive
                      : context.l10n.prompt_negative,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _buildPositionStat(
                theme,
                color: color,
                icon: Icons.arrow_forward_rounded,
                label: context.l10n.fixedTags_prefix,
                count: prefixes.length,
              ),
              _buildPositionStat(
                theme,
                color: color,
                icon: Icons.arrow_back_rounded,
                label: context.l10n.fixedTags_suffix,
                count: suffixes.length,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < allEnabled.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            _buildCompactEntryRow(
              theme,
              allEnabled[i].entry,
              allEnabled[i].isPrefix,
              color,
              mutedColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPositionStat(
    ThemeData theme, {
    required Color color,
    required IconData icon,
    required String label,
    required int count,
  }) {
    final displayColor = count > 0 ? color : theme.colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: displayColor),
        const SizedBox(width: 3),
        Text(
          '$label $count',
          style: theme.textTheme.labelSmall?.copyWith(
            color: displayColor,
            fontWeight: count > 0 ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactEntryRow(
    ThemeData theme,
    FixedTagEntry entry,
    bool isPrefix,
    Color color,
    Color mutedColor,
  ) {
    final content = entry.content.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPrefix
                    ? Icons.arrow_forward_rounded
                    : Icons.arrow_back_rounded,
                size: 11,
                color: color,
              ),
              const SizedBox(width: 3),
              Text(
                isPrefix
                    ? context.l10n.fixedTags_prefix
                    : context.l10n.fixedTags_suffix,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
                TranslatedPromptText(
                  content,
                  selectable: false,
                  includeUntranslated: true,
                  style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
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
              ...disabledEntries.map(
                (entry) => _buildDisabledChip(theme, entry),
              ),
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
    final promptLabel = entry.promptType == FixedTagPromptType.positive
        ? context.l10n.prompt_positive
        : context.l10n.prompt_negative;
    return Text(
      '$promptLabel · ${entry.displayName}',
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
