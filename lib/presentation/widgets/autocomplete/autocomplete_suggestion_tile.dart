import 'package:flutter/material.dart';

import '../../../data/models/tag/local_tag.dart';
import 'autocomplete_controller.dart';

/// 自动补全建议项
class AutocompleteSuggestionTile extends StatelessWidget {
  final LocalTag tag;
  final bool isSelected;
  final VoidCallback onTap;
  final AutocompleteConfig config;

  const AutocompleteSuggestionTile({
    super.key,
    required this.tag,
    required this.isSelected,
    required this.onTap,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = _getCategoryColor(tag.category);

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 分类标签
              if (config.showCategory) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag.categoryName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // 标签名称
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag.tag.replaceAll('_', ' '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (config.showTranslation && tag.translation != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        tag.translation!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                    if (tag.alias != null && tag.alias != tag.translation) ...[
                      const SizedBox(height: 2),
                      Text(
                        tag.alias!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 使用次数
              if (config.showCount) ...[
                const SizedBox(width: 8),
                Text(
                  tag.formattedCount,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(int category) {
    switch (category) {
      case 1: // artist
        return const Color(0xFFFF8A8A);
      case 3: // copyright
        return const Color(0xFFCC8AFF);
      case 4: // character
        return const Color(0xFF8AFF8A);
      case 5: // meta
        return const Color(0xFFFFB38A);
      default: // general
        return const Color(0xFF8AC8FF);
    }
  }
}

