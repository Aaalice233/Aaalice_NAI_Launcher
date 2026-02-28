---
wave: 2
depends_on: [PLAN-01]
files_modified:
  - lib/presentation/screens/tag_library_page/widgets/tag_library_toolbar.dart
autonomous: true
---

# Plan 02: Toolbar 改造

## Goal

将 Toolbar 中的视图切换从2按钮改为3按钮（列表/网格/分组），并在视图切换按钮左侧添加全局排序下拉菜单。

---

## Requirements

- FR-1: 视图切换改为3选项：列表/网格/分组
- FR-1: 排序功能位置在 Toolbar，视图切换按钮左边
- FR-1: 排序范围全局生效，所有视图共享排序设置
- FR-1: 排序选项：时间、字母（名称）、使用频率

---

## Tasks

### Task 1: 修改视图切换为3按钮

**Status:** pending

修改 `_buildViewModeToggle()` 方法，添加分组视图按钮：

```dart
Widget _buildViewModeToggle(ThemeData theme, TagLibraryPageState state) {
  return Container(
    decoration: BoxDecoration(...),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewModeButton(
          icon: Icons.view_list_rounded,
          isSelected: state.viewMode == TagLibraryViewMode.list,
          onTap: () => ref
              .read(tagLibraryPageNotifierProvider.notifier)
              .setViewMode(TagLibraryViewMode.list),
        ),
        _ViewModeButton(
          icon: Icons.grid_view_rounded,
          isSelected: state.viewMode == TagLibraryViewMode.card,
          onTap: () => ref
              .read(tagLibraryPageNotifierProvider.notifier)
              .setViewMode(TagLibraryViewMode.card),
        ),
        _ViewModeButton(
          icon: Icons.folder_copy_outlined,  // 分组视图图标
          isSelected: state.viewMode == TagLibraryViewMode.grouped,
          onTap: () => ref
              .read(tagLibraryPageNotifierProvider.notifier)
              .setViewMode(TagLibraryViewMode.grouped),
        ),
      ],
    ),
  );
}
```

### Task 2: 添加排序下拉菜单

**Status:** pending

在 Toolbar 中添加 `_buildSortDropdown()` 方法：

```dart
Widget _buildSortDropdown(ThemeData theme, TagLibraryPageState state) {
  return Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      borderRadius: BorderRadius.circular(8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<TagLibrarySortBy>(
        value: state.sortBy,
        icon: const Icon(Icons.arrow_drop_down, size: 18),
        borderRadius: BorderRadius.circular(8),
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
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

Widget _buildSortItem(IconData icon, String label) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16),
      const SizedBox(width: 8),
      Text(label),
    ],
  );
}
```

### Task 3: 调整 Toolbar 布局

**Status:** pending

修改 `build()` 方法中的布局，将排序下拉菜单放在视图切换按钮左侧：

```dart
// 在 build 方法的 Row children 中：
children: [
  // 添加条目按钮...
  const SizedBox(width: 12),

  // 搜索框...
  const SizedBox(width: 12),

  // 排序下拉菜单（新增）
  _buildSortDropdown(theme, state),
  const SizedBox(width: 8),

  // 视图切换
  _buildViewModeToggle(theme, state),

  // 分隔线和后续按钮...
]
```

---

## Verification

- [ ] Toolbar 显示3个视图切换按钮（列表/网格/分组）
- [ ] 分组视图按钮使用 `Icons.folder_copy_outlined` 图标
- [ ] 排序下拉菜单显示在视图切换按钮左侧
- [ ] 排序下拉菜单包含4个选项：自定义排序、名称、使用频率、更新时间
- [ ] 切换排序选项后，条目按正确顺序排列
- [ ] 排序设置在所有视图模式（列表/网格/分组）中共享
- [ ] `flutter analyze` 无错误

---

## Must-Haves for Goal Backward Verification

1. **必须有3个视图按钮** - 缺少任何一个都会影响视图切换功能
2. **排序必须在视图切换左侧** - 这是设计决策中锁定的位置
3. **排序必须全局生效** - 切换视图后排序设置应保持不变
4. **必须有4个排序选项** - 对应 `TagLibrarySortBy` 枚举的所有值

---

## Notes

- 排序功能的状态管理已在 `TagLibraryPageNotifier` 中实现，无需修改
- 排序下拉菜单使用 Material Design 风格的 `DropdownButton`
- 视图切换按钮保持现有的视觉样式
