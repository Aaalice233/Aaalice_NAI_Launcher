import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/localization_extension.dart';
import '../../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../../providers/tag_library_page_provider.dart';
import 'category_header.dart';

/// 分组视图 - 按类别分组显示条目
class GroupedEntriesView extends ConsumerWidget {
  final ScrollController? scrollController;
  final Widget Function(TagLibraryEntry) entryBuilder;

  const GroupedEntriesView({
    super.key,
    this.scrollController,
    required this.entryBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tagLibraryPageNotifierProvider);

    // 按分类分组
    final grouped = _groupEntriesByCategory(
      state.filteredEntries,
      state.categories,
      context.l10n.tagLibrary_uncategorized,
    );

    // 过滤掉空分类（可选：根据需求决定是否显示空分类）
    final nonEmptyGroups = grouped.where((g) => g.entries.isNotEmpty).toList();

    if (nonEmptyGroups.isEmpty) {
      return _buildEmptyState(context);
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        for (final group in nonEmptyGroups) ...[
          // 吸顶分类标题
          SliverPersistentHeader(
            pinned: true,
            delegate: CategoryHeaderDelegate(
              title: group.category.displayName,
              count: group.entries.length,
            ),
          ),
          // 该分类的条目网格
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisExtent: 80,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => entryBuilder(group.entries[index]),
                childCount: group.entries.length,
              ),
            ),
          ),
        ],
        // 底部留白
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  /// 按分类分组条目
  List<CategoryGroup> _groupEntriesByCategory(
    List<TagLibraryEntry> entries,
    List<TagLibraryCategory> categories,
    String uncategorizedLabel,
  ) {
    // 获取所有有条目的分类ID
    final categoryIdsWithEntries = entries.map((e) => e.categoryId).toSet();

    // 构建分类顺序（按 sortOrder）
    final sortedCategories = categories.sortedByOrder();

    // 创建分组
    final groups = <CategoryGroup>[];

    for (final category in sortedCategories) {
      // 只包含有条目的分类
      if (categoryIdsWithEntries.contains(category.id)) {
        final categoryEntries = entries
            .where((e) => e.categoryId == category.id)
            .toList();
        groups.add(CategoryGroup(category: category, entries: categoryEntries));
      }
    }

    // 处理未分类条目（categoryId 为 null）
    final uncategorizedEntries = entries
        .where((e) => e.categoryId == null)
        .toList();
    if (uncategorizedEntries.isNotEmpty) {
      groups.add(
        CategoryGroup(
          category: TagLibraryCategory(
            id: 'uncategorized',
            name: uncategorizedLabel,
            sortOrder: -1,
            createdAt: DateTime.now(),
          ),
          entries: uncategorizedEntries,
        ),
      );
    }

    return groups;
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open_outlined,
            size: 64,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.tagLibrary_empty,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分类分组数据类
class CategoryGroup {
  final TagLibraryCategory category;
  final List<TagLibraryEntry> entries;

  CategoryGroup({required this.category, required this.entries});
}
