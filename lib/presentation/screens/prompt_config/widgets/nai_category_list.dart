import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_library_provider.dart';
import 'expandable_category_tile.dart';

/// NAI 类别列表组件
class NaiCategoryList extends ConsumerWidget {
  final Set<TagSubCategory> expandedCategories;
  final void Function(TagSubCategory category, bool expanded) onExpandChanged;
  final void Function(TagSubCategory category) onSyncCategory;
  final void Function(TagSubCategory category, List<WeightedTag> tags)
      onShowDetail;
  final void Function(RandomCategory category) onSettings;
  final void Function(RandomCategory category, bool enabled) onEnabledChanged;
  final void Function(RandomCategory category) onRemove;

  const NaiCategoryList({
    super.key,
    required this.expandedCategories,
    required this.onExpandChanged,
    required this.onSyncCategory,
    required this.onShowDetail,
    required this.onSettings,
    required this.onEnabledChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final presetCategories = preset?.categories ?? [];
    final library = libraryState.library;
    final filterConfig = libraryState.categoryFilterConfig;

    if (library == null) {
      return Center(child: Text(context.l10n.naiMode_noLibrary));
    }

    // 如果类别列表为空，显示空状态
    if (presetCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.naiMode_noCategories,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: presetCategories.length,
      itemBuilder: (context, index) {
        final randomCategory = presetCategories[index];

        // 从 key 获取 TagSubCategory 枚举
        final category = TagSubCategory.values.firstWhere(
          (e) => e.name == randomCategory.key,
          orElse: () => TagSubCategory.hairColor,
        );

        final probability = (randomCategory.probability * 100).round();
        final includeSupplement = filterConfig.isEnabled(category);
        final tags = library.getFilteredCategory(
          category,
          includeDanbooruSupplement: includeSupplement,
        );

        return ExpandableCategoryTile(
          category: category,
          probability: probability,
          tags: tags,
          onSyncCategory: () => onSyncCategory(category),
          onShowDetail: () => onShowDetail(category, tags),
          isExpanded: expandedCategories.contains(category),
          onExpandChanged: (expanded) => onExpandChanged(category, expanded),
          onSettings: () => onSettings(randomCategory),
          isEnabled: randomCategory.enabled,
          onEnabledChanged: (enabled) =>
              onEnabledChanged(randomCategory, enabled),
          onRemove: () => onRemove(randomCategory),
        );
      },
    );
  }
}
