import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../providers/fixed_tags_provider.dart';
import 'fixed_tags_dialog.dart';

/// 固定词按钮组件
/// 显示当前启用的固定词数量，点击打开管理对话框
class FixedTagsButton extends ConsumerStatefulWidget {
  const FixedTagsButton({super.key});

  @override
  ConsumerState<FixedTagsButton> createState() => _FixedTagsButtonState();
}

class _FixedTagsButtonState extends ConsumerState<FixedTagsButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fixedTagsState = ref.watch(fixedTagsNotifierProvider);
    final enabledCount = fixedTagsState.enabledCount;
    final hasEntries = fixedTagsState.entries.isNotEmpty;
    final hasEnabled = enabledCount > 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        richMessage: WidgetSpan(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: _buildTooltipContent(theme, fixedTagsState),
          ),
        ),
        preferBelow: true,
        verticalOffset: 20,
        waitDuration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => _showFixedTagsDialog(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasEnabled
                  ? (_isHovering
                      ? theme.colorScheme.secondary.withOpacity(0.2)
                      : theme.colorScheme.secondary.withOpacity(0.1))
                  : (_isHovering
                      ? theme.colorScheme.surfaceContainerHighest
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasEnabled
                    ? theme.colorScheme.secondary.withOpacity(0.5)
                    : theme.colorScheme.secondary.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasEnabled ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 14,
                  color: hasEnabled
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.fixedTags_label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: hasEnabled ? FontWeight.w600 : FontWeight.w500,
                    color: hasEnabled
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                if (hasEnabled) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      enabledCount.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ] else if (hasEntries) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.visibility_off,
                    size: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTooltipContent(ThemeData theme, FixedTagsState state) {
    final entries = state.entries;

    if (entries.isEmpty) {
      return Text(
        context.l10n.fixedTags_empty,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 12,
        ),
      );
    }

    final enabledPrefixes = state.enabledPrefixes;
    final enabledSuffixes = state.enabledSuffixes;
    final disabledEntries = entries.where((e) => !e.enabled).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 统计摘要
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '${enabledPrefixes.length}${context.l10n.fixedTags_prefix} · ${enabledSuffixes.length}${context.l10n.fixedTags_suffix}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),

        // 启用的前缀
        if (enabledPrefixes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSectionHeader(
            theme,
            Icons.arrow_forward,
            context.l10n.fixedTags_prefix,
            theme.colorScheme.primary,
          ),
          const SizedBox(height: 6),
          ...enabledPrefixes.map(
            (entry) => _buildEntryCard(theme, entry, isEnabled: true),
          ),
        ],

        // 启用的后缀
        if (enabledSuffixes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildSectionHeader(
            theme,
            Icons.arrow_back,
            context.l10n.fixedTags_suffix,
            theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 6),
          ...enabledSuffixes.map(
            (entry) => _buildEntryCard(theme, entry, isEnabled: true),
          ),
        ],

        // 禁用的条目
        if (disabledEntries.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 1,
            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          _buildSectionHeader(
            theme,
            Icons.visibility_off,
            '${context.l10n.fixedTags_disabled} (${disabledEntries.length})',
            theme.colorScheme.outline,
          ),
          const SizedBox(height: 6),
          ...disabledEntries.map(
            (entry) => _buildEntryRow(
              theme,
              entry,
              isEnabled: false,
            ),
          ),
        ],

        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            context.l10n.fixedTags_clickToManage,
            style: TextStyle(
              color: theme.colorScheme.outline,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    IconData icon,
    String label,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 启用条目的卡片样式
  Widget _buildEntryCard(
    ThemeData theme,
    FixedTagEntry entry, {
    required bool isEnabled,
  }) {
    final isPrefix = entry.position == FixedTagPosition.prefix;
    final positionColor =
        isPrefix ? theme.colorScheme.primary : theme.colorScheme.tertiary;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：名称 + 权重 + 位置
          Row(
            children: [
              Icon(
                Icons.push_pin,
                size: 12,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 权重徽章
              if (entry.weight != 1.0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.weight > 1.0
                        ? theme.colorScheme.primary.withOpacity(0.15)
                        : theme.colorScheme.tertiary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${entry.weight.toStringAsFixed(2)}x',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: entry.weight > 1.0
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              // 位置标识
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: positionColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPrefix ? Icons.arrow_forward : Icons.arrow_back,
                      size: 9,
                      color: positionColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      isPrefix
                          ? context.l10n.fixedTags_prefix
                          : context.l10n.fixedTags_suffix,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: positionColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 内容预览
          if (entry.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.content.length > 40
                  ? '${entry.content.substring(0, 40)}...'
                  : entry.content,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.outline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryRow(
    ThemeData theme,
    FixedTagEntry entry, {
    required bool isEnabled,
  }) {
    final weightText =
        entry.weight != 1.0 ? ' (${entry.weight.toStringAsFixed(2)}x)' : '';

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              '${entry.displayName}$weightText',
              style: TextStyle(
                fontSize: 11,
                color: isEnabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withOpacity(0.5),
                decoration: isEnabled ? null : TextDecoration.lineThrough,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showFixedTagsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const FixedTagsDialog(),
    );
  }
}
