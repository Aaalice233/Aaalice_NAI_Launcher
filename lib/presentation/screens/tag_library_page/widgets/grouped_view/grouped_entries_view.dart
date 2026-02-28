import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../data/models/tag_library/tag_library_category.dart';
import '../../../../../data/models/tag_library/tag_library_entry.dart';
import '../../../../providers/tag_library_page_provider.dart';
import '../../../../providers/tag_library_selection_provider.dart';
import '../entry_card.dart';
import 'category_header.dart';

/// 分组视图 - 按类别分组显示条目
class GroupedEntriesView extends ConsumerWidget {
  final void Function(TagLibraryEntry) onEdit;
  final void Function(TagLibraryEntry) onDelete;
  final void Function(TagLibraryEntry) onSend;

  const GroupedEntriesView({
    super.key,
    required this.onEdit,
    required this.onDelete,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tagLibraryPageNotifierProvider);
    final selectionState = ref.watch(tagLibrarySelectionNotifierProvider);

    // 按分类分组
    final grouped = _groupEntriesByCategory(
      state.filteredEntries,
      state.categories,
    );

    // 过滤掉空分类（可选：根据需求决定是否显示空分类）
    final nonEmptyGroups = grouped.where((g) => g.entries.isNotEmpty).toList();

    if (nonEmptyGroups.isEmpty) {
      return _buildEmptyState(context);
    }

    return CustomScrollView(
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
                (context, index) => _buildEntryCard(
                  context,
                  ref,
                  group.entries[index],
                  selectionState,
                ),
                childCount: group.entries.length,
              ),
            ),
          ),
        ],
        // 底部留白
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

  /// 构建条目卡片
  Widget _buildEntryCard(
    BuildContext context,
    WidgetRef ref,
    TagLibraryEntry entry,
    dynamic selectionState,
  ) {
    final state = ref.read(tagLibraryPageNotifierProvider);
    final allIds = state.filteredEntries.map((e) => e.id).toList();
    final isSelected = selectionState.isSelected(entry.id);

    return EntryCard(
      key: ValueKey(entry.id),
      entry: entry,
      categoryName: null, // 分组视图中不显示分类名称（已经在标题中）
      enableDrag: !selectionState.isActive,
      isSelectionMode: selectionState.isActive,
      isSelected: isSelected,
      onToggleSelection: () {
        final notifier = ref.read(tagLibrarySelectionNotifierProvider.notifier);
        if (!selectionState.isActive) {
          notifier.enterAndSelect(entry.id);
        } else {
          notifier.toggle(entry.id);
        }
      },
      onTap: () => onEdit(entry),
      onDelete: () => onDelete(entry),
      onEdit: () => onEdit(entry),
      onSend: () => onSend(entry),
      onToggleFavorite: () => ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .toggleFavorite(entry.id),
    );
  }

  /// 按分类分组条目
  List<CategoryGroup> _groupEntriesByCategory(
    List<TagLibraryEntry> entries,
    List<TagLibraryCategory> categories,
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
        groups.add(CategoryGroup(
          category: category,
          entries: categoryEntries,
        ));
      }
    }

    // 处理未分类条目（categoryId 为 null）
    final uncategorizedEntries = entries.where((e) => e.categoryId == null).toList();
    if (uncategorizedEntries.isNotEmpty) {
      groups.add(CategoryGroup(
        category: TagLibraryCategory(
          id: 'uncategorized',
          name: '未分类',
          sortOrder: -1,
          createdAt: DateTime.now(),
        ),
        entries: uncategorizedEntries,
      ));
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
            color: theme.colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无条目',
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
