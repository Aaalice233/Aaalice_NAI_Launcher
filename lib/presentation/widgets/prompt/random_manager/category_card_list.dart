import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_preset.dart';
import '../../../providers/random_preset_provider.dart';
import 'category_card.dart';

class CategoryCardList extends ConsumerWidget {
  const CategoryCardList({
    super.key,
    this.onAddCategory,
    this.query = '',
    this.shrinkWrap = false,
  });

  final VoidCallback? onAddCategory;
  final String query;
  final bool shrinkWrap;

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
        ? _NoCategoryResults(hasQuery: query.isNotEmpty)
        : ListView.separated(
            shrinkWrap: shrinkWrap,
            physics: shrinkWrap
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.zero,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _CategoryHeader(
          preset: preset,
          visibleCount: categories.length,
          onAddCategory: onAddCategory,
        ),
        const SizedBox(height: 12),
        if (shrinkWrap) list else Expanded(child: list),
      ],
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

/// Compatibility wrapper retained for callers that previously requested a grid.
/// A stable vertical list avoids narrow-card overflows and keeps expansion
/// geometry predictable at every supported desktop width.
class CategoryCardGrid extends StatelessWidget {
  const CategoryCardGrid({super.key, this.onAddCategory, this.query = ''});

  final VoidCallback? onAddCategory;
  final String query;

  @override
  Widget build(BuildContext context) {
    return CategoryCardList(
      onAddCategory: onAddCategory,
      query: query,
      shrinkWrap: true,
    );
  }
}

class _CategoryHeader extends ConsumerWidget {
  const _CategoryHeader({
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
    final tagCount = ref.watch(presetTotalTagCountProvider);
    final groupCount = preset.categories.fold<int>(
      0,
      (total, category) => total + category.groupCount,
    );

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 8,
      children: [
        Text(
          context.l10n.categoryConfiguration,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        _CountBadge(
          icon: Icons.category_outlined,
          value: '$visibleCount/${preset.categoryCount}',
        ),
        _CountBadge(icon: Icons.layers_outlined, value: '$groupCount'),
        _CountBadge(icon: Icons.sell_outlined, value: '$tagCount'),
        if (onAddCategory != null && !preset.isDefault)
          IconButton.filledTonal(
            onPressed: onAddCategory,
            tooltip: context.l10n.randomManager_addCategory,
            icon: const Icon(Icons.add_rounded),
          ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(value, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _NoCategoryResults extends StatelessWidget {
  const _NoCategoryResults({required this.hasQuery});

  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 36),
          const SizedBox(height: 10),
          Text(
            hasQuery
                ? context.l10n.randomManager_noCategoryResults
                : context.l10n.randomManager_noCategories,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
