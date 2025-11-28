import 'package:flutter/material.dart';

import '../../../data/models/tag/local_tag.dart';
import 'autocomplete_controller.dart';

/// 自动补全建议项
class AutocompleteSuggestionTile extends StatelessWidget {
  final LocalTag tag;
  final bool isSelected;
  final VoidCallback onTap;
  final AutocompleteConfig config;
  final String languageCode;

  const AutocompleteSuggestionTile({
    super.key,
    required this.tag,
    required this.isSelected,
    required this.onTap,
    required this.config,
    this.languageCode = 'zh',
  });

  /// 过滤翻译文本，只保留中文（移除日语、韩语等）
  String? _filterTranslation(String? translation) {
    if (translation == null || translation.isEmpty) return null;
    
    // 如果是英文界面，不显示翻译
    if (languageCode == 'en') return null;
    
    // 按 | 或 , 分割翻译
    final parts = translation.split(RegExp(r'[|,]'));
    final chineseParts = <String>[];
    
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      
      // 检查是否包含日语假名（平假名、片假名）
      final hasJapanese = RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(trimmed);
      // 检查是否包含韩语
      final hasKorean = RegExp(r'[\uAC00-\uD7AF]').hasMatch(trimmed);
      
      // 只保留不含日语和韩语的部分
      if (!hasJapanese && !hasKorean) {
        chineseParts.add(trimmed);
      }
    }
    
    if (chineseParts.isEmpty) return null;
    return chineseParts.join(', ');
  }

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
                child: Builder(
                  builder: (context) {
                    final filteredTranslation = _filterTranslation(tag.translation);
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tag.tag.replaceAll('_', ' '),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (config.showTranslation && filteredTranslation != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            filteredTranslation,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
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

