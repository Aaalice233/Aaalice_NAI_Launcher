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
            constraints: const BoxConstraints(maxWidth: 320),
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
                    ? theme.colorScheme.secondary.withOpacity(0.3)
                    : Colors.transparent,
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
        // 启用的前缀
        if (enabledPrefixes.isNotEmpty) ...[
          _buildSectionHeader(
            theme,
            Icons.arrow_forward,
            context.l10n.fixedTags_prefix,
            theme.colorScheme.primary,
          ),
          const SizedBox(height: 4),
          ...enabledPrefixes.map(
            (entry) => _buildEntryRow(
              theme,
              entry,
              isEnabled: true,
            ),
          ),
        ],

        // 启用的后缀
        if (enabledSuffixes.isNotEmpty) ...[
          if (enabledPrefixes.isNotEmpty) const SizedBox(height: 8),
          _buildSectionHeader(
            theme,
            Icons.arrow_back,
            context.l10n.fixedTags_suffix,
            theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 4),
          ...enabledSuffixes.map(
            (entry) => _buildEntryRow(
              theme,
              entry,
              isEnabled: true,
            ),
          ),
        ],

        // 禁用的条目
        if (disabledEntries.isNotEmpty) ...[
          if (enabledPrefixes.isNotEmpty || enabledSuffixes.isNotEmpty)
            const Divider(height: 16),
          _buildSectionHeader(
            theme,
            Icons.visibility_off,
            context.l10n.fixedTags_disabled,
            theme.colorScheme.outline,
          ),
          const SizedBox(height: 4),
          ...disabledEntries.map(
            (entry) => _buildEntryRow(
              theme,
              entry,
              isEnabled: false,
            ),
          ),
        ],

        const SizedBox(height: 8),
        Text(
          context.l10n.fixedTags_clickToManage,
          style: TextStyle(
            color: theme.colorScheme.outline,
            fontSize: 10,
            fontStyle: FontStyle.italic,
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
