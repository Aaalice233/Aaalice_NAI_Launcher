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
    final isDark = theme.brightness == Brightness.dark;

    if (entries.isEmpty) {
      return _buildEmptyState(theme);
    }

    final enabledPrefixes = state.enabledPrefixes;
    final enabledSuffixes = state.enabledSuffixes;
    final disabledEntries = entries.where((e) => !e.enabled).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部双列统计卡片
        _buildStatisticsHeader(
          theme,
          isDark,
          enabledPrefixes.length,
          enabledSuffixes.length,
        ),

        // 启用的条目列表
        if (enabledPrefixes.isNotEmpty || enabledSuffixes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildEnabledEntriesSection(
            theme,
            isDark,
            enabledPrefixes,
            enabledSuffixes,
          ),
        ],

        // 禁用的条目
        if (disabledEntries.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildDisabledSection(theme, isDark, disabledEntries),
        ],

        // 底部操作提示
        const SizedBox(height: 10),
        _buildFooterHint(theme),
      ],
    );
  }

  /// 空状态 - 精致插画风格
  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.surfaceContainerHigh,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.push_pin_outlined,
              size: 18,
              color: theme.colorScheme.outline.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.fixedTags_empty,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.fixedTags_clickToManage,
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 顶部统计卡片 - 双列 Bento 风格
  Widget _buildStatisticsHeader(
    ThemeData theme,
    bool isDark,
    int prefixCount,
    int suffixCount,
  ) {
    return Row(
      children: [
        // 前缀统计卡片
        Expanded(
          child: _buildStatCard(
            theme,
            isDark,
            icon: Icons.arrow_forward_rounded,
            count: prefixCount,
            label: context.l10n.fixedTags_prefix,
            color: theme.colorScheme.primary,
            isActive: prefixCount > 0,
          ),
        ),
        const SizedBox(width: 8),
        // 后缀统计卡片
        Expanded(
          child: _buildStatCard(
            theme,
            isDark,
            icon: Icons.arrow_back_rounded,
            count: suffixCount,
            label: context.l10n.fixedTags_suffix,
            color: theme.colorScheme.tertiary,
            isActive: suffixCount > 0,
          ),
        ),
      ],
    );
  }

  /// 单个统计卡片
  Widget _buildStatCard(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  color.withOpacity(isDark ? 0.2 : 0.12),
                  color.withOpacity(isDark ? 0.1 : 0.06),
                ]
              : [
                  theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? color.withOpacity(0.3)
              : theme.colorScheme.outlineVariant.withOpacity(0.2),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // 图标容器
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withOpacity(0.15)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 14,
              color: isActive ? color : theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 10),
          // 数字和标签
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isActive ? color : theme.colorScheme.outline,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? color.withOpacity(0.8)
                      : theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 启用条目列表区域
  Widget _buildEnabledEntriesSection(
    ThemeData theme,
    bool isDark,
    List<FixedTagEntry> prefixes,
    List<FixedTagEntry> suffixes,
  ) {
    final allEnabled = [
      ...prefixes.map((e) => (entry: e, isPrefix: true)),
      ...suffixes.map((e) => (entry: e, isPrefix: false)),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHigh.withOpacity(0.3)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < allEnabled.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _buildCompactEntryRow(
              theme,
              allEnabled[i].entry,
              allEnabled[i].isPrefix,
            ),
          ],
        ],
      ),
    );
  }

  /// 紧凑条目行
  Widget _buildCompactEntryRow(
    ThemeData theme,
    FixedTagEntry entry,
    bool isPrefix,
  ) {
    final color =
        isPrefix ? theme.colorScheme.primary : theme.colorScheme.tertiary;
    final hasWeight = entry.weight != 1.0;
    final showContent = entry.content.isNotEmpty &&
        entry.content.trim() != entry.displayName.trim();
    final truncatedContent = entry.content.length > 25
        ? '${entry.content.substring(0, 25)}...'
        : entry.content;

    return Row(
      children: [
        // 位置指示条
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withOpacity(0.4)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        // 名称
        Flexible(
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
        if (hasWeight) ...[
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
        // 内容预览
        if (showContent) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              truncatedContent,
              style: TextStyle(
                fontSize: 10,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        // 位置标签
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isPrefix
                ? context.l10n.fixedTags_prefix
                : context.l10n.fixedTags_suffix,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// 禁用条目区域
  Widget _buildDisabledSection(
    ThemeData theme,
    bool isDark,
    List<FixedTagEntry> disabledEntries,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 区域标题
          Row(
            children: [
              Icon(
                Icons.visibility_off_rounded,
                size: 12,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                '${context.l10n.fixedTags_disabled} (${disabledEntries.length})',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 禁用标签
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: disabledEntries
                .map((entry) => _buildDisabledChip(theme, entry))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// 底部操作提示
  Widget _buildFooterHint(ThemeData theme) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  theme.colorScheme.outlineVariant.withOpacity(0.4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.touch_app_rounded,
            size: 11,
            color: theme.colorScheme.outline.withOpacity(0.6),
          ),
          const SizedBox(width: 4),
          Text(
            context.l10n.fixedTags_clickToManage,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.outline.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 20,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.outlineVariant.withOpacity(0.4),
                  Colors.transparent,
                ],
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
