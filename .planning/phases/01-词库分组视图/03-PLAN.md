---
wave: 3
depends_on: [PLAN-01, PLAN-02]
files_modified:
  - lib/presentation/screens/tag_library_page/widgets/grouped_view/grouped_entries_view.dart
  - lib/presentation/screens/tag_library_page/widgets/grouped_view/category_header.dart
  - lib/presentation/screens/tag_library_page/tag_library_page_screen.dart
autonomous: true
---

# Plan 03: 分组视图实现

## Goal

实现按类别分组的分组视图，使用吸顶标题（Sticky Header）显示类别名称，分组内使用 EntryCard 组件展示条目。

---

## Requirements

- FR-1: 分组视图按类别分组显示条目
- FR-1: 每个类别有清晰的分组标题
- FR-1: 分组视图内容样式使用现有的 EntryCard 组件
- FR-1: 分组视图标题样式为吸顶标题（Sticky Header）

---

## Tasks

### Task 1: 创建分组视图目录结构

**Status:** pending

创建分组视图相关文件的目录：

```
lib/presentation/screens/tag_library_page/widgets/grouped_view/
├── grouped_entries_view.dart    # 分组视图主组件
└── category_header.dart         # 吸顶分类标题
```

### Task 2: 实现 CategoryHeaderDelegate

**Status:** pending

创建 `lib/presentation/screens/tag_library_page/widgets/grouped_view/category_header.dart`：

```dart
import 'package:flutter/material.dart';

/// 吸顶分类标题 Delegate
class CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final int count;

  CategoryHeaderDelegate({required this.title, required this.count});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.folder_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 40;

  @override
  double get minExtent => 40;

  @override
  bool shouldRebuild(covariant CategoryHeaderDelegate oldDelegate) {
    return title != oldDelegate.title || count != oldDelegate.count;
  }
}
```

### Task 3: 实现 GroupedEntriesView

**Status:** pending

创建 `lib/presentation/screens/tag_library_page/widgets/grouped_view/grouped_entries_view.dart`：

```dart
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
  const GroupedEntriesView({super.key});

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
      onTap: () => _showEditDialog(context, ref, entry),
      onDelete: () => _showDeleteConfirmation(context, ref, entry),
      onEdit: () => _showEditDialog(context, ref, entry),
      onSend: () => _showSendDialog(context, ref, entry),
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

  // 以下方法需要与 TagLibraryPageScreen 中的对应方法保持一致
  void _showEditDialog(BuildContext context, WidgetRef ref, TagLibraryEntry entry) {
    // 调用父组件的方法或实现相同逻辑
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, TagLibraryEntry entry) {
    // 调用父组件的方法或实现相同逻辑
  }

  void _showSendDialog(BuildContext context, WidgetRef ref, TagLibraryEntry entry) {
    // 调用父组件的方法或实现相同逻辑
  }
}

/// 分类分组数据类
class CategoryGroup {
  final TagLibraryCategory category;
  final List<TagLibraryEntry> entries;

  CategoryGroup({required this.category, required this.entries});
}
```

### Task 4: 修改 TagLibraryPageScreen 添加分组视图分支

**Status:** pending

修改 `lib/presentation/screens/tag_library_page/tag_library_page_screen.dart` 中的 `_buildContent()` 方法：

```dart
/// 构建内容区域
Widget _buildContent(ThemeData theme, TagLibraryPageState state) {
  final entries = state.filteredEntries;

  if (state.isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  if (entries.isEmpty) {
    return _buildEmptyState(theme, state);
  }

  switch (state.viewMode) {
    case TagLibraryViewMode.card:
      return _buildCardGrid(theme, entries);
    case TagLibraryViewMode.list:
      return _buildListView(theme, entries);
    case TagLibraryViewMode.grouped:
      return const GroupedEntriesView();  // 新增
  }
}
```

添加导入：

```dart
import 'widgets/grouped_view/grouped_entries_view.dart';
```

### Task 5: 处理 GroupedEntriesView 中的回调

**Status:** pending

由于 `GroupedEntriesView` 是一个独立的 ConsumerWidget，它需要能够调用编辑、删除、发送等操作。有两种方案：

**方案A（推荐）：** 将回调方法通过构造函数传入

修改 `GroupedEntriesView`：

```dart
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
  // ...
}
```

在 `_buildContent()` 中传入回调：

```dart
case TagLibraryViewMode.grouped:
  return GroupedEntriesView(
    onEdit: _showEditDialog,
    onDelete: _showDeleteEntryConfirmation,
    onSend: _showEntryDetail,
  );
```

**方案B：** 使用全局状态或事件总线（不推荐，会增加复杂度）

---

## Verification

- [ ] 分组视图正确按类别分组显示条目
- [ ] 每个类别有吸顶标题，标题显示分类名称和条目数量
- [ ] 滚动时类别标题固定在顶部
- [ ] 分组内使用 EntryCard 组件展示条目
- [ ] 空分类不显示（或显示占位提示）
- [ ] 未分类条目显示在"未分类"分组中
- [ ] 分类按 sortOrder 排序
- [ ] 条目操作（编辑、删除、收藏、发送）正常工作
- [ ] `flutter analyze` 无错误

---

## Must-Haves for Goal Backward Verification

1. **必须有吸顶标题** - 这是分组视图的核心交互特征
2. **必须按类别分组** - 否则无法满足分组视图的需求
3. **必须使用 EntryCard** - 这是设计决策中锁定的内容样式
4. **必须处理未分类条目** - 否则 categoryId 为 null 的条目会丢失
5. **回调必须正常工作** - 否则无法进行编辑、删除等操作

---

## Notes

- 使用 Flutter 内置的 `SliverPersistentHeader` 实现吸顶效果，无需第三方库
- 空分类默认隐藏，保持界面整洁
- 未分类条目使用特殊的 "未分类" 分组显示
- 分组视图中 EntryCard 不显示分类名称（因为已经在标题中显示）
