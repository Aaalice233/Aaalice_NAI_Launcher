import '../common/delayed_rich_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/layout_state_provider.dart';
import '../../themes/prompt_semantic_colors.dart';
import 'prompt_control_button.dart';
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fixedTagsState = ref.watch(fixedTagsNotifierProvider);
    final enabledCount = fixedTagsState.entries
        .where((entry) => entry.enabled)
        .length;
    final hasEntries = fixedTagsState.entries.isNotEmpty;
    final hasEnabled = enabledCount > 0;
    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.noScaling),
      child: DelayedRichTooltip(
        content: MediaQuery(
          data: mediaQuery,
          child: RichTooltipSurface(
            maxWidth: 420,
            child: _buildTooltipContent(theme, fixedTagsState),
          ),
        ),
        child: MediaQuery(
          data: mediaQuery,
          child: Semantics(
            button: true,
            label: context.l10n.fixedTags_label,
            child: PromptControlButton(
              key: const Key('fixed-tags-button-surface'),
              color: theme.promptSemanticColors.fixedTag,
              active: hasEnabled,
              onPressed: () {
                final sidebarExpanded = ref.read(
                  layoutStateNotifierProvider.select(
                    (state) => state.fixedTagsSidebarExpanded,
                  ),
                );
                if (!sidebarExpanded) _showFixedTagsDialog(context);
              },
              onLongPress: () => ref
                  .read(layoutStateNotifierProvider.notifier)
                  .toggleFixedTagsSidebar(),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 8 : 10,
                vertical: widget.compact ? 4 : 6,
              ),
              builder: (colors) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasEnabled ? Icons.push_pin : Icons.push_pin_outlined,
                    size: widget.compact ? 15 : 16,
                    color: colors.accent,
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
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ],
                  if (hasEnabled) ...[
                    const SizedBox(width: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        enabledCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                  ] else if (hasEntries) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.visibility_off,
                      size: 14,
                      color: colors.foreground,
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

    final enabledCount = entries.where((entry) => entry.enabled).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTooltipHeader(theme, enabledCount, entries.length),

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
        if (state.links.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildLinkSummary(theme, state.links.length),
        ],
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

  Widget _buildTooltipHeader(
    ThemeData theme,
    int enabledCount,
    int totalCount,
  ) {
    final status = context.l10n.fixedTags_enabledCount(
      enabledCount.toString(),
      totalCount.toString(),
    );
    final title = Row(
      children: [
        Icon(
          Icons.push_pin_rounded,
          size: 16,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.l10n.fixedTags_label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
    if (MediaQuery.textScalerOf(context).scale(1) >= 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 4),
          Text(
            status,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 12),
        Text(
          status,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
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
        ? theme.promptSemanticColors.positiveFixedTag
        : theme.promptSemanticColors.negativeFixedTag;
    final mutedColor = Color.lerp(
      theme.colorScheme.onSurfaceVariant,
      color,
      0.24,
    )!;
    final allEnabled = [
      ...prefixes.map((e) => (entry: e, isPrefix: true)),
      ...suffixes.map((e) => (entry: e, isPrefix: false)),
    ];
    final promptLabel =
        '${isPositive ? context.l10n.prompt_positive : context.l10n.prompt_negative} ${allEnabled.length}';

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
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(
                        isPositive
                            ? Icons.auto_awesome_rounded
                            : Icons.block_rounded,
                        size: 15,
                        color: color,
                      ),
                    ),
                    const WidgetSpan(child: SizedBox(width: 6)),
                    TextSpan(text: promptLabel),
                  ],
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(icon, size: 11, color: displayColor),
          ),
          const WidgetSpan(child: SizedBox(width: 3)),
          TextSpan(text: '$label $count'),
        ],
      ),
      style: theme.textTheme.labelSmall?.copyWith(
        color: displayColor,
        fontWeight: count > 0 ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildPositionBadge(
    ThemeData theme, {
    required bool isPrefix,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPrefix ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
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
    );
  }

  Widget _buildEntryDetails(
    ThemeData theme,
    FixedTagEntry entry,
    String content,
    Color color,
    Color mutedColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (entry.weight != 1.0) ...[
              const SizedBox(width: 8),
              Text(
                '${entry.weight.toStringAsFixed(1)}×',
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ],
        ),
        if (content.isNotEmpty)
          TranslatedPromptText(
            content,
            selectable: false,
            maxLines: 1,
            includeUntranslated: true,
            style: theme.textTheme.bodySmall?.copyWith(
              color: mutedColor,
              height: 1.3,
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
    final positionBadge = _buildPositionBadge(
      theme,
      isPrefix: isPrefix,
      color: color,
    );
    final details = _buildEntryDetails(
      theme,
      entry,
      content,
      color,
      mutedColor,
    );

    if (MediaQuery.textScalerOf(context).scale(1) >= 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [positionBadge, const SizedBox(height: 6), details],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        positionBadge,
        const SizedBox(width: 8),
        Expanded(child: details),
      ],
    );
  }

  Widget _buildLinkSummary(ThemeData theme, int linkCount) {
    final color = theme.colorScheme.secondary;
    return Container(
      key: const ValueKey('fixed-tags-tooltip-links'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.l10n.fixedTags_linkCount(linkCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
        Flexible(
          child: Text(
            context.l10n.fixedTags_clickManageLongPressCompact,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  void _showFixedTagsDialog(BuildContext context) {
    FixedTagsDialog.show(context);
  }
}
