import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/prompt/random_preset.dart';
import '../../../providers/random_preset_provider.dart';
import '../../common/elevated_card.dart';
import 'category_card.dart';

/// 类别卡片垂直列表组件
///
/// 用于在仪表盘中显示所有类别卡片（垂直列表布局）
/// 采用 Dimensional Layering 风格设计
class CategoryCardList extends ConsumerWidget {
  const CategoryCardList({
    super.key,
    this.onAddCategory,
  });

  final VoidCallback? onAddCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;

    if (preset == null) {
      return const Center(child: Text('请选择一个预设'));
    }

    return ElevatedCard(
      elevation: CardElevation.level1,
      enableHoverEffect: false,
      borderRadius: 8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          _CategoryHeader(
            preset: preset,
            onAddCategory: onAddCategory,
          ),
          const SizedBox(height: 16),
          // 类别卡片垂直列表
          if (preset.categories.isEmpty)
            const EmptyCategoryPlaceholder()
          else
            Expanded(
              child: ListView.separated(
                clipBehavior: Clip.none,
                itemCount: preset.categories.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final category = preset.categories[index];
                  return CategoryCard(
                    category: category,
                    presetId: preset.id,
                    isPresetDefault: preset.isDefault,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 类别卡片网格组件
///
/// 用于在仪表盘中显示所有类别卡片
/// 采用 Dimensional Layering 风格设计
class CategoryCardGrid extends ConsumerWidget {
  const CategoryCardGrid({
    super.key,
    this.onAddCategory,
  });

  final VoidCallback? onAddCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presetState = ref.watch(randomPresetNotifierProvider);
    final preset = presetState.selectedPreset;

    if (preset == null) {
      return const Center(child: Text('请选择一个预设'));
    }

    return ElevatedCard(
      elevation: CardElevation.level1,
      enableHoverEffect: false,
      borderRadius: 8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          _CategoryHeader(
            preset: preset,
            onAddCategory: onAddCategory,
          ),
          const SizedBox(height: 16),
          // 类别卡片网格
          if (preset.categories.isEmpty)
            const EmptyCategoryPlaceholder()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const minCardWidth = 260.0;
                const maxCardWidth = 320.0;
                const spacing = 12.0;

                final availableWidth = constraints.maxWidth;
                final cardsPerRow =
                    ((availableWidth + spacing) / (minCardWidth + spacing))
                        .floor()
                        .clamp(1, 4);
                final cardWidth =
                    (availableWidth - (cardsPerRow - 1) * spacing) /
                        cardsPerRow;
                final finalCardWidth =
                    cardWidth.clamp(minCardWidth, maxCardWidth);

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: preset.categories.map((category) {
                    return SizedBox(
                      width: finalCardWidth,
                      child: CategoryCard(
                        category: category,
                        presetId: preset.id,
                        isPresetDefault: preset.isDefault,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// 构建标题栏
class _CategoryHeader extends ConsumerWidget {
  const _CategoryHeader({
    required this.preset,
    required this.onAddCategory,
  });

  final RandomPreset preset;
  final VoidCallback? onAddCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final tagCount = ref.watch(presetTotalTagCountProvider);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.15),
                colorScheme.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.category_outlined,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.categoryConfiguration,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // 统计信息
        CategoryStats(
          categoryCount: preset.categoryCount,
          groupCount: preset.categories.fold(0, (sum, c) => sum + c.groupCount),
          tagCount: tagCount,
        ),
        const Spacer(),
        // 添加类别按钮
        AddCategoryButton(onPressed: onAddCategory),
      ],
    );
  }
}
