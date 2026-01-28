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
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.2),
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
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 16,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.fixedTags_empty,
            style: TextStyle(
              color: theme.colorScheme.outline,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    final enabledPrefixes = state.enabledPrefixes;
    final enabledSuffixes = state.enabledSuffixes;
    final disabledEntries = entries.where((e) => !e.enabled).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 统计摘要 - 玻璃态风格
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.12),
                theme.colorScheme.secondary.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.push_pin_rounded,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${enabledPrefixes.length}${context.l10n.fixedTags_prefix}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '·',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              Text(
                '${enabledSuffixes.length}${context.l10n.fixedTags_suffix}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.tertiary,
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
            Icons.arrow_forward_rounded,
            context.l10n.fixedTags_prefix,
            theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          ...enabledPrefixes.map(
            (entry) => _buildEntryCard(theme, entry, isEnabled: true),
          ),
        ],

        // 启用的后缀
        if (enabledSuffixes.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildSectionHeader(
            theme,
            Icons.arrow_back_rounded,
            context.l10n.fixedTags_suffix,
            theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 8),
          ...enabledSuffixes.map(
            (entry) => _buildEntryCard(theme, entry, isEnabled: true),
          ),
        ],

        // 禁用的条目
        if (disabledEntries.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  theme.colorScheme.outlineVariant.withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildSectionHeader(
            theme,
            Icons.visibility_off_rounded,
            '${context.l10n.fixedTags_disabled} (${disabledEntries.length})',
            theme.colorScheme.outline,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: disabledEntries
                .map((entry) => _buildDisabledChip(theme, entry))
                .toList(),
          ),
        ],

        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 12,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.fixedTags_clickToManage,
                  style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
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
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color,
                color.withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  /// 启用条目的卡片样式 - 单行紧凑布局
  Widget _buildEntryCard(
    ThemeData theme,
    FixedTagEntry entry, {
    required bool isEnabled,
  }) {
    final isPrefix = entry.position == FixedTagPosition.prefix;
    final positionColor =
        isPrefix ? theme.colorScheme.primary : theme.colorScheme.tertiary;

    // 判断名称和内容是否不同（需要显示内容）
    final showContent = entry.content.isNotEmpty &&
        entry.content.trim() != entry.displayName.trim();
    // 截断内容
    final truncatedContent = entry.content.length > 30
        ? '${entry.content.substring(0, 30)}...'
        : entry.content;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: positionColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // 左侧位置标识条
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: positionColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          // 名称
          Text(
            entry.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          // 权重徽章（紧跟名称）
          if (entry.weight != 1.0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: entry.weight > 1.0
                    ? theme.colorScheme.error.withOpacity(0.12)
                    : theme.colorScheme.tertiary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${entry.weight.toStringAsFixed(2)}x',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: entry.weight > 1.0
                      ? theme.colorScheme.error
                      : theme.colorScheme.tertiary,
                ),
              ),
            ),
          ],
          // 分隔点 + 内容
          if (showContent) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Text(
                truncatedContent,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),
          // 末尾位置标识
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: positionColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isPrefix
                  ? context.l10n.fixedTags_prefix
                  : context.l10n.fixedTags_suffix,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: positionColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 禁用条目的紧凑样式
  Widget _buildDisabledChip(ThemeData theme, FixedTagEntry entry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.push_pin_outlined,
            size: 10,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              entry.displayName,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.outline,
                decoration: TextDecoration.lineThrough,
                decorationColor: theme.colorScheme.outline.withOpacity(0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (entry.weight != 1.0) ...[
            const SizedBox(width: 4),
            Text(
              '${entry.weight.toStringAsFixed(1)}x',
              style: TextStyle(
                fontSize: 9,
                color: theme.colorScheme.outline,
              ),
            ),
          ],
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
