import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import 'autocomplete_controller.dart';
import 'generic_suggestion_tile.dart';

/// 通用自动补全建议浮层
///
/// 支持任意数据源，通过 [SuggestionData] 统一接口
class GenericAutocompleteOverlay extends StatelessWidget {
  final List<SuggestionData> suggestions;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final AutocompleteConfig config;
  final bool isLoading;
  final ScrollController? scrollController;
  final String languageCode;

  /// 弹层最大高度（由外部按屏幕可用空间压缩，避免超出窗口边界）
  final double maxHeight;

  const GenericAutocompleteOverlay({
    super.key,
    required this.suggestions,
    required this.selectedIndex,
    required this.onSelect,
    required this.config,
    this.isLoading = false,
    this.scrollController,
    this.languageCode = 'zh',
    this.maxHeight = 300,
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
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
                    final data = suggestions[index];
                    return GenericSuggestionTile(
                      data: data,
                      isSelected: index == selectedIndex,
                      onTap: () => onSelect(index),
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
                        .withValues(alpha: 0.5),
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.autocomplete_resultsCount(
                            suggestions.length,
                          ),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildShortcutHint(
                                theme,
                                context.l10n.autocomplete_keyNavigate,
                                context.l10n.autocomplete_actionSelect,
                              ),
                              const SizedBox(width: 12),
                              _buildShortcutHint(
                                theme,
                                'Enter/Tab',
                                context.l10n.autocomplete_actionConfirm,
                              ),
                              const SizedBox(width: 12),
                              _buildShortcutHint(
                                theme,
                                'Esc',
                                context.l10n.autocomplete_actionClose,
                              ),
                            ],
                          ),
                        ),
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
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
