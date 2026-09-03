import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../themes/core/layered_surface_style.dart';
import 'category_card.dart';

class CategoryCardList extends ConsumerWidget {
  const CategoryCardList({
    super.key,
    this.onAddCategory,
    this.query = '',
    this.shrinkWrap = false,
    this.overviewHeader,
  });

  final VoidCallback? onAddCategory;
  final String query;
  final bool shrinkWrap;
  final Widget? overviewHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(randomPresetNotifierProvider).selectedPreset;
    if (preset == null) {
      return Center(
        child: Text(context.l10n.randomManager_selectPresetRequired),
      );
    }

    final categories = _filteredCategories(preset, query);
    final list = categories.isEmpty
        ? _NoCategoryResults(
            hasQuery: query.isNotEmpty,
            canEdit: !preset.isDefault,
          )
        : ListView.separated(
            shrinkWrap: shrinkWrap,
            physics: shrinkWrap
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.only(bottom: 4),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return CategoryCard(
                key: ValueKey(category.id),
                category: category,
                presetId: preset.id,
                isPresetDefault: preset.isDefault,
              );
            },
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(overviewHeader == null ? 0 : 16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Container(
            key: const ValueKey('random-manager-overview-card'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sectionSurfaceColor(Theme.of(context).colorScheme),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (overviewHeader != null) ...[
                  overviewHeader!,
                  const SizedBox(height: 14),
                ],
                _RecipeSummary(
                  preset: preset,
                  visibleCount: categories.length,
                  onAddCategory: onAddCategory,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (shrinkWrap) list else Expanded(child: list),
        ],
      ),
    );
  }

  List<RandomCategory> _filteredCategories(
    RandomPreset preset,
    String normalizedQuery,
  ) {
    if (normalizedQuery.isEmpty) return preset.categories;
    return preset.categories
        .where((category) {
          if (category.name.toLowerCase().contains(normalizedQuery) ||
              category.key.toLowerCase().contains(normalizedQuery)) {
            return true;
          }
          return category.groups.any((group) {
            return group.name.toLowerCase().contains(normalizedQuery) ||
                (group.sourceId?.toLowerCase().contains(normalizedQuery) ??
                    false) ||
                group.tags.any(
                  (tag) => tag.tag.toLowerCase().contains(normalizedQuery),
                );
          });
        })
        .toList(growable: false);
  }
}

class _RecipeSummary extends ConsumerWidget {
  const _RecipeSummary({
    required this.preset,
    required this.visibleCount,
    required this.onAddCategory,
  });

  final RandomPreset preset;
  final int visibleCount;
  final VoidCallback? onAddCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tagCount = ref.watch(presetTotalTagCountProvider);
    final groupCount = preset.categories.fold<int>(
      0,
      (total, category) => total + category.groupCount,
    );
    final enabledCount = preset.categories.where((item) => item.enabled).length;

    final metrics = Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$enabledCount/${preset.categoryCount}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.randomManager_categories,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        _InlineMetric(
          icon: Icons.layers_outlined,
          value: groupCount.toString(),
        ),
        _InlineMetric(icon: Icons.sell_outlined, value: tagCount.toString()),
        if (visibleCount != preset.categoryCount)
          Text(
            '$visibleCount/${preset.categoryCount}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.primary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
    final addButton = !preset.isDefault && preset.categories.isNotEmpty
        ? AddCategoryButton(onPressed: onAddCategory)
        : null;
    if (addButton == null) return metrics;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < 520 || textScale > 1.5) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [metrics, const SizedBox(height: 8), addButton],
          );
        }
        return Row(
          children: [
            Expanded(child: metrics),
            const SizedBox(width: 12),
            addButton,
          ],
        );
      },
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _NoCategoryResults extends StatelessWidget {
  const _NoCategoryResults({required this.hasQuery, required this.canEdit});

  final bool hasQuery;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            hasQuery ? Icons.search_off_rounded : Icons.category_outlined,
            size: 32,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            hasQuery
                ? context.l10n.randomManager_noCategoryResults
                : context.l10n.randomManager_noCategories,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          if (!hasQuery && canEdit) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.randomManager_noCategoriesHint,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            const AddCategoryButton(),
          ],
        ],
      ),
    );
  }
}
