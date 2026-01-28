import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import '../../../utils/category_icon_utils.dart';
import '../../../widgets/common/themed_divider.dart';

/// 类别详情对话框
///
/// 显示某个 NAI 类别的详细信息和标签列表
class CategoryDetailDialog extends StatelessWidget {
  final TagSubCategory category;
  final List<WeightedTag> tags;

  const CategoryDetailDialog({
    super.key,
    required this.category,
    required this.tags,
  });

  /// 显示对话框
  static Future<void> show({
    required BuildContext context,
    required TagSubCategory category,
    required List<WeightedTag> tags,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => CategoryDetailDialog(
        category: category,
        tags: tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryName = TagSubCategoryHelper.getDisplayName(category);
    final sortedTags = List<WeightedTag>.from(tags)
      ..sort((a, b) => b.weight.compareTo(a.weight));

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Row(
        children: [
          Icon(
            CategoryIconUtils.getCategoryIcon(category),
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoryName),
                Text(
                  context.l10n.naiMode_tagCount(tags.length.toString()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分类描述
            Text(
              _getCategoryDescription(context, category),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            const ThemedDivider(),
            const SizedBox(height: 12),
            // 标签列表标题
            Text(
              context.l10n.naiMode_tagListTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // 可滚动标签列表
            Expanded(
              child: sortedTags.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.naiMode_noTags,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sortedTags.map((tag) {
                          return _buildTagChip(theme, tag);
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_close),
        ),
      ],
    );
  }

  Widget _buildTagChip(ThemeData theme, WeightedTag tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Text(
        tag.tag,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  String _getCategoryDescription(
    BuildContext context,
    TagSubCategory category,
  ) {
    return switch (category) {
      TagSubCategory.hairColor => context.l10n.naiMode_desc_hairColor,
      TagSubCategory.eyeColor => context.l10n.naiMode_desc_eyeColor,
      TagSubCategory.hairStyle => context.l10n.naiMode_desc_hairStyle,
      TagSubCategory.expression => context.l10n.naiMode_desc_expression,
      TagSubCategory.pose => context.l10n.naiMode_desc_pose,
      TagSubCategory.clothing => context.l10n.naiMode_desc_clothing,
      TagSubCategory.accessory => context.l10n.naiMode_desc_accessory,
      TagSubCategory.bodyFeature => context.l10n.naiMode_desc_bodyFeature,
      TagSubCategory.background => context.l10n.naiMode_desc_background,
      TagSubCategory.scene => context.l10n.naiMode_desc_scene,
      TagSubCategory.style => context.l10n.naiMode_desc_style,
      TagSubCategory.characterCount => context.l10n.naiMode_desc_characterCount,
      _ => '',
    };
  }
}
