import 'package:flutter/material.dart';

import '../../../data/models/tag/local_tag.dart';
import 'autocomplete_controller.dart';
import 'autocomplete_suggestion_tile.dart';

/// 自动补全建议浮层
class AutocompleteOverlay extends StatelessWidget {
  final List<LocalTag> suggestions;
  final int selectedIndex;
  final ValueChanged<LocalTag> onSelect;
  final AutocompleteConfig config;
  final bool isLoading;
  final ScrollController? scrollController;
  final String languageCode;

  const AutocompleteOverlay({
    super.key,
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelect,
    required this.config,
    this.isLoading = false,
    this.scrollController,
    this.languageCode = 'zh',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (suggestions.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(4),
      color: theme.colorScheme.surfaceContainerHigh,
      child: Container(
        constraints: const BoxConstraints(
          maxHeight: 300,
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 加载指示器
              if (isLoading)
                LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              // 建议列表
              Flexible(
                child: ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final tag = suggestions[index];
                    return AutocompleteSuggestionTile(
                      tag: tag,
                      isSelected: index == selectedIndex,
                      onTap: () => onSelect(tag),
                      config: config,
                      languageCode: languageCode,
                    );
                  },
                ),
              ),
              // 底部提示
              if (suggestions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.5),
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${suggestions.length} 个结果',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildShortcutHint(theme, '↑↓', '选择'),
                          const SizedBox(width: 12),
                          _buildShortcutHint(theme, 'Enter', '确认'),
                          const SizedBox(width: 12),
                          _buildShortcutHint(theme, 'Esc', '关闭'),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutHint(ThemeData theme, String key, String action) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Text(
            key,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          action,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

