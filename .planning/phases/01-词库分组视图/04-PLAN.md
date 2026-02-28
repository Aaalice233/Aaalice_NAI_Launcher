---
wave: 4
depends_on: [PLAN-01, PLAN-02, PLAN-03]
files_modified:
  - lib/presentation/screens/tag_library_page/widgets/grouped_view/grouped_entries_view.dart
  - lib/presentation/screens/tag_library_page/widgets/grouped_view/category_header.dart
  - lib/presentation/screens/tag_library_page/widgets/tag_library_toolbar.dart
autonomous: true
---

# Plan 04: UI 优化和验证

## Goal

优化分组视图的 UI 细节，确保界面美观、交互流畅，并通过完整的功能验证。

---

## Requirements

- FR-1: 界面美观，交互流畅
- NFR-3: 代码质量达标，`flutter analyze` 无错误

---

## Tasks

### Task 1: 优化吸顶标题样式

**Status:** pending

调整 `category_header.dart` 的样式，使其更加美观：

```dart
@override
Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
  final theme = Theme.of(context);
  final isPinned = shrinkOffset > 0 || overlapsContent;

  return Container(
    color: isPinned
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerLow,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.folder_outlined,
            size: 18,
            color: isPinned
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isPinned
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: isPinned
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isPinned
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ),
  );
}
```

### Task 2: 优化分组内卡片布局

**Status:** pending

调整 `grouped_entries_view.dart` 中的网格布局参数，确保卡片显示美观：

```dart
SliverPadding(
  padding: const EdgeInsets.all(16),
  sliver: SliverGrid(
    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 240,
      mainAxisExtent: 80,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
    ),
    delegate: SliverChildBuilderDelegate(
      (context, index) => _buildEntryCard(...),
      childCount: group.entries.length,
    ),
  ),
)
```

### Task 3: 优化排序下拉菜单样式

**Status:** pending

调整 `tag_library_toolbar.dart` 中的排序下拉菜单，使其与整体风格一致：

```dart
Widget _buildSortDropdown(ThemeData theme, TagLibraryPageState state) {
  return Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: theme.colorScheme.outline.withOpacity(0.1),
        width: 1,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<TagLibrarySortBy>(
        value: state.sortBy,
        icon: Icon(
          Icons.arrow_drop_down,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        borderRadius: BorderRadius.circular(8),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13,
          color: theme.colorScheme.onSurface,
        ),
        dropdownColor: theme.colorScheme.surfaceContainerHigh,
        items: [
          DropdownMenuItem(
            value: TagLibrarySortBy.order,
            child: _buildSortItem(Icons.sort, '自定义排序'),
          ),
          DropdownMenuItem(
            value: TagLibrarySortBy.name,
            child: _buildSortItem(Icons.sort_by_alpha, '名称'),
          ),
          DropdownMenuItem(
            value: TagLibrarySortBy.useCount,
            child: _buildSortItem(Icons.trending_up, '使用频率'),
          ),
          DropdownMenuItem(
            value: TagLibrarySortBy.updatedAt,
            child: _buildSortItem(Icons.access_time, '更新时间'),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            ref.read(tagLibraryPageNotifierProvider.notifier).setSortBy(value);
          }
        },
      ),
    ),
  );
}
```

### Task 4: 添加空分类占位提示（可选）

**Status:** pending

如果需要显示空分类，添加占位提示样式：

```dart
// 在 CategoryGroup 中处理空条目
if (group.entries.isEmpty) {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          '该分类暂无条目',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    ),
  );
}
```

### Task 5: 运行代码生成

**Status:** pending

确保所有代码生成文件都是最新的：

```bash
/mnt/e/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs
```

### Task 6: 运行代码分析

**Status:** pending

检查代码质量：

```bash
/mnt/e/flutter/bin/flutter.bat analyze
```

修复任何分析错误。

### Task 7: 运行快速修复

**Status:** pending

自动修复可以自动修复的问题：

```bash
/mnt/e/flutter/bin/dart.bat fix --apply
```

---

## Verification

- [ ] 吸顶标题在滚动时有视觉反馈（颜色变化）
- [ ] 分组内卡片布局整齐，间距一致
- [ ] 排序下拉菜单样式与整体风格一致
- [ ] 所有视图模式（列表/网格/分组）切换流畅
- [ ] 分组视图设为默认后，首次进入页面显示分组视图
- [ ] 排序设置在所有视图中保持一致
- [ ] `flutter analyze` 无错误
- [ ] `dart fix --apply` 无未修复问题

---

## Must-Haves for Goal Backward Verification

1. **吸顶标题必须有视觉反馈** - 用户需要知道当前固定在顶部的是哪个分类
2. **代码必须通过分析** - 这是代码质量的基本要求
3. **视图切换必须流畅** - 影响用户体验
4. **默认视图必须是分组** - 这是需求的核心

---

## Notes

- UI 优化是迭代过程，可能需要根据实际效果调整
- 保持与现有代码风格一致
- 避免过度设计，保持简洁
