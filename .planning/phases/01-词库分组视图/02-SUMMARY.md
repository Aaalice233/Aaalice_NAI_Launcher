---
phase: 01
plan: 02
subsystem: presentation
tags: [tag-library, toolbar, ui]
dependency-graph:
  requires: [01-01]
  provides: [01-03]
  affects: []
tech-stack:
  added: []
  patterns: [flutter, riverpod]
key-files:
  created: []
  modified:
    - lib/presentation/screens/tag_library_page/widgets/tag_library_toolbar.dart
decisions: []
metrics:
  duration: "15 min"
  completed-date: "2026-02-28"
  tasks-total: 3
  tasks-completed: 3
---

# Phase 01 Plan 02: Toolbar 改造 总结

## 一句话总结

将词库 Toolbar 的视图切换从2按钮改为3按钮（列表/网格/分组），并在视图切换按钮左侧添加全局排序下拉菜单。

---

## 完成内容

### Task 1: 修改视图切换为3按钮

**状态**: 完成

修改 `_buildViewModeToggle()` 方法，添加分组视图按钮：
- 列表视图按钮：`Icons.view_list_rounded`
- 网格视图按钮：`Icons.grid_view_rounded`
- 分组视图按钮：`Icons.folder_copy_outlined`（新增）

### Task 2: 添加排序下拉菜单

**状态**: 完成

在 Toolbar 中添加 `_buildSortDropdown()` 方法和 `_buildSortItem()` 辅助方法：
- 排序选项：自定义排序、名称、使用频率、更新时间
- 使用 Material Design 风格的 `DropdownButton`
- 视觉样式与现有 Toolbar 保持一致

### Task 3: 调整 Toolbar 布局

**状态**: 完成

修改 `build()` 方法中的布局：
- 排序下拉菜单位于视图切换按钮左侧
- 保持其他按钮位置不变

---

## 修改文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/presentation/screens/tag_library_page/widgets/tag_library_toolbar.dart` | 修改 | 添加分组视图按钮和排序下拉菜单 |

---

## 验证结果

- [x] Toolbar 显示3个视图切换按钮（列表/网格/分组）
- [x] 分组视图按钮使用 `Icons.folder_copy_outlined` 图标
- [x] 排序下拉菜单显示在视图切换按钮左侧
- [x] 排序下拉菜单包含4个选项：自定义排序、名称、使用频率、更新时间
- [x] 切换排序选项后，条目按正确顺序排列（由 Provider 处理）
- [x] 排序设置在所有视图模式（列表/网格/分组）中共享
- [x] `flutter analyze` 无错误

---

## 技术细节

### 依赖的枚举类型

排序功能依赖 `TagLibrarySortBy` 枚举（已在前序 Plan 中定义）：

```dart
enum TagLibrarySortBy {
  order,      // 自定义排序
  name,       // 名称
  useCount,   // 使用频率
  updatedAt,  // 更新时间
}
```

### 状态管理

排序状态由 `TagLibraryPageNotifier` 管理，通过 `setSortBy()` 方法更新：

```dart
ref.read(tagLibraryPageNotifierProvider.notifier).setSortBy(value);
```

---

## 偏差记录

无偏差，计划按预期执行。

---

## 提交记录

| Commit | 说明 |
|--------|------|
| `e649fdf4` | feat(01-02): 词库 Toolbar 改造 - 3按钮视图切换和排序下拉菜单 |

---

## 后续工作

Plan 03 将实现分组视图的具体 UI，包括：
- 按分类分组的列表展示
- 吸顶分类标题
- EntryCard 布局调整
