import 'package:flutter/material.dart';

import 'autocomplete_controller.dart';

/// 通用补全建议项数据
class SuggestionData {
  final String tag;
  final int category;
  final int count;
  final String? translation;
  final String? alias;

  const SuggestionData({
    required this.tag,
    required this.category,
    required this.count,
    this.translation,
    this.alias,
  });

  /// 获取分类名称
  String get categoryName {
    switch (category) {
      case 1:
        return '艺术家';
      case 3:
        return '版权';
      case 4:
        return '角色';
      case 5:
        return '元数据';
      default:
        return '通用';
    }
  }

  /// 格式化显示的计数
  String get formattedCount {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

/// 通用自动补全建议项
///
/// 支持任意数据源，通过 [SuggestionData] 统一接口
class GenericSuggestionTile extends StatelessWidget {
  final SuggestionData data;
  final bool isSelected;
  final VoidCallback onTap;
  final AutocompleteConfig config;
  final String languageCode;

  const GenericSuggestionTile({
    super.key,
    required this.data,
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
      final hasJapanese =
          RegExp(r'[\u3040-\u309F\u30A0-\u30FF]').hasMatch(trimmed);
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
    final categoryColor = _getCategoryColor(data.category);
    final filteredTranslation = _filterTranslation(data.translation);

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withOpacity(0.15)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              // 分类标签
              if (config.showCategory) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    data.categoryName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: categoryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // 标签名称 + 翻译（单行显示）
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: data.tag.replaceAll('_', ' '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isSelected ? theme.colorScheme.primary : null,
                        ),
                      ),
                      if (config.showTranslation &&
                          filteredTranslation != null) ...[
                        TextSpan(
                          text: '  $filteredTranslation',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // 使用次数
              if (config.showCount) ...[
                const SizedBox(width: 8),
                Text(
                  data.formattedCount,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
