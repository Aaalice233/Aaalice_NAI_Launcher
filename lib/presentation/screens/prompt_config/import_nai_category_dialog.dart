import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/prompt/category_filter_config.dart';
import '../../../data/models/prompt/prompt_config.dart';
import '../../../data/models/prompt/tag_category.dart';
import '../../../data/models/prompt/weighted_tag.dart';
import '../../providers/tag_library_provider.dart';
import '../../utils/category_icon_utils.dart';

/// 从NAI词库导入类别的弹窗
///
/// 让用户选择要导入到自定义预设的NAI类别
class ImportNaiCategoryDialog extends ConsumerStatefulWidget {
  /// 导入完成回调
  final void Function(List<PromptConfig> configs)? onImport;

  const ImportNaiCategoryDialog({
    super.key,
    this.onImport,
  });

  /// 显示导入弹窗
  static Future<List<PromptConfig>?> show(BuildContext context) async {
    return showDialog<List<PromptConfig>>(
      context: context,
      builder: (context) => const ImportNaiCategoryDialog(),
    );
  }

  @override
  ConsumerState<ImportNaiCategoryDialog> createState() =>
      _ImportNaiCategoryDialogState();
}

class _ImportNaiCategoryDialogState
    extends ConsumerState<ImportNaiCategoryDialog> {
  // 选中的类别
  final _selectedCategories = <TagSubCategory>{};

  // 可导入的类别列表（与NAI算法使用的类别一致）
  static const _availableCategories = [
    TagSubCategory.hairColor,
    TagSubCategory.eyeColor,
    TagSubCategory.hairStyle,
    TagSubCategory.expression,
    TagSubCategory.pose,
    TagSubCategory.background,
    TagSubCategory.scene,
    TagSubCategory.style,
    TagSubCategory.characterCount,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final library = libraryState.library;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.download,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(context.l10n.importNai_title),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.importNai_selectCategories,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),

            // 类别选择列表
            if (library == null)
              Center(
                child: Text(
                  context.l10n.naiMode_noLibrary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              )
            else
              ...(_availableCategories.map((category) {
                final includeSupplement =
                    libraryState.categoryFilterConfig.isEnabled(category);
                final tags = library.getFilteredCategory(
                  category,
                  includeDanbooruSupplement: includeSupplement,
                );
                final isSelected = _selectedCategories.contains(category);
                final categoryName =
                    TagSubCategoryHelper.getDisplayName(category);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: tags.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              _selectedCategories.add(category);
                            } else {
                              _selectedCategories.remove(category);
                            }
                          });
                        },
                  title: Row(
                    children: [
                      Icon(
                        CategoryIconUtils.getCategoryIcon(category),
                        size: 18,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          categoryName,
                          style: TextStyle(
                            color:
                                tags.isEmpty ? theme.colorScheme.outline : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          context.l10n
                              .importNai_tagCount(tags.length.toString()),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                );
              })),

            // 全选/取消全选
            const Divider(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: library == null
                      ? null
                      : () {
                          final filterConfig =
                              libraryState.categoryFilterConfig;
                          setState(() {
                            _selectedCategories.clear();
                            for (final cat in _availableCategories) {
                              if (library
                                  .getFilteredCategory(
                                    cat,
                                    includeDanbooruSupplement:
                                        filterConfig.isEnabled(cat),
                                  )
                                  .isNotEmpty) {
                                _selectedCategories.add(cat);
                              }
                            }
                          });
                        },
                  child: Text(context.l10n.common_selectAll),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategories.clear();
                    });
                  },
                  child: Text(context.l10n.common_deselectAll),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _selectedCategories.isEmpty
              ? null
              : () => _doImport(library!, libraryState.categoryFilterConfig),
          child: Text(
            context.l10n
                .importNai_import(_selectedCategories.length.toString()),
          ),
        ),
      ],
    );
  }

  void _doImport(dynamic library, CategoryFilterConfig filterConfig) {
    final configs = <PromptConfig>[];

    for (final category in _selectedCategories) {
      final includeSupplement = filterConfig.isEnabled(category);
      final tags = library.getFilteredCategory(
        category,
        includeDanbooruSupplement: includeSupplement,
      ) as List<WeightedTag>;
      if (tags.isEmpty) continue;

      // 按权重排序后取标签名称
      final sortedTags = List<WeightedTag>.from(tags)
        ..sort((a, b) => b.weight.compareTo(a.weight));
      final tagNames = sortedTags.map((t) => t.tag).toList();

      // 创建配置组
      final config = PromptConfig.create(
        name: TagSubCategoryHelper.getDisplayName(category),
        selectionMode: SelectionMode.singleRandom,
        contentType: ContentType.string,
        stringContents: tagNames,
      );

      configs.add(config);
    }

    widget.onImport?.call(configs);
    Navigator.pop(context, configs);
  }
}
