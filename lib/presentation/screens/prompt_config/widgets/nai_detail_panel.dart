import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../../../../data/models/prompt/weighted_tag.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_library_provider.dart';
import 'nai_info_header.dart';
import 'nai_category_list.dart';

/// NAI 模式详情面板
/// 组合 NaiInfoHeader 和 NaiCategoryList
class NaiDetailPanel extends ConsumerWidget {
  final Set<TagSubCategory> expandedCategories;
  final VoidCallback onEditPresetName;
  final VoidCallback onEditDescription;
  final VoidCallback onResetPreset;
  final VoidCallback onAddCategory;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;
  final VoidCallback onToggleExpand;
  final void Function(TagSubCategory category, bool expanded) onExpandChanged;
  final void Function(TagSubCategory category) onSyncCategory;
  final void Function(TagSubCategory category, List<WeightedTag> tags)
      onShowDetail;
  final void Function(RandomCategory category) onSettings;
  final void Function(RandomCategory category, bool enabled) onEnabledChanged;
  final void Function(RandomCategory category) onRemove;

  const NaiDetailPanel({
    super.key,
    required this.expandedCategories,
    required this.onEditPresetName,
    required this.onEditDescription,
    required this.onResetPreset,
    required this.onAddCategory,
    required this.onSelectAll,
    required this.onDeselectAll,
    required this.onToggleExpand,
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

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 信息卡片（包含操作按钮）
          NaiInfoHeader(
            onEditPresetName: onEditPresetName,
            onEditDescription: onEditDescription,
            onResetPreset: onResetPreset,
            onAddCategory: onAddCategory,
            onSelectAll: onSelectAll,
            onDeselectAll: onDeselectAll,
            onToggleExpand: onToggleExpand,
            allExpanded: _isAllExpanded(ref),
            expandedCategoryCount: expandedCategories.length,
          ),

          // 类别列表
          Expanded(
            child: libraryState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : NaiCategoryList(
                    expandedCategories: expandedCategories,
                    onExpandChanged: onExpandChanged,
                    onSyncCategory: onSyncCategory,
                    onShowDetail: onShowDetail,
                    onSettings: onSettings,
                    onEnabledChanged: onEnabledChanged,
                    onRemove: onRemove,
                  ),
          ),
        ],
      ),
    );
  }

  bool _isAllExpanded(WidgetRef ref) {
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;
    final presetCategories = preset?.categories ?? [];
    return expandedCategories.length == presetCategories.length &&
        presetCategories.isNotEmpty;
  }
}
