# Phase 1: 词库分组视图 - Research

**Researched:** 2025-02-28
**Domain:** Flutter UI / 词库功能增强
**Confidence:** HIGH

## Summary

本阶段需要为词库页面添加按类别分组的视图模式，并设为默认视图。核心工作包括：修改视图切换为3状态（列表/网格/分组）、实现分组视图的吸顶类别标题、Toolbar 添加全局排序功能。

项目使用 Flutter + Riverpod 架构，词库功能已有良好基础。现有代码包含 `TagLibraryViewMode` 枚举（当前2状态）、`TagLibrarySortBy` 枚举（已有排序选项）、`EntryCard` 组件（可复用）。分组视图需要使用 Flutter 的 `CustomScrollView` + `Sliver` 系列组件实现吸顶效果。

**Primary recommendation:** 使用 Flutter 内置的 `SliverPersistentHeader` 或 `SliverAppBar` 实现吸顶分组标题，无需引入第三方库；视图状态存储从2值改为3值需要迁移逻辑。

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **视图切换样式**: 横排3按钮（列表 | 网格 | 分组）
- **视图切换位置**: Toolbar 右侧，保持现有位置
- **默认视图**: 分组视图
- **分组视图内容样式**: 使用现有的 EntryCard 组件
- **分组视图标题样式**: 吸顶标题（Sticky Header），滚动时类别名称固定在顶部
- **类别排序**: 跟随全局排序设置
- **排序功能位置**: Toolbar，视图切换按钮左边
- **排序范围**: 全局生效，所有视图共享排序设置
- **排序选项**: 时间、字母（名称）、使用频率
- **排序UI**: 下拉菜单样式

### Claude's Discretion
- 吸顶标题具体实现方式（SliverPersistentHeader 或 SliverAppBar）
- 排序下拉菜单的具体UI样式（DropdownButton 或自定义）
- 分组内条目的布局细节（单列还是多列）
- 空类别的占位提示样式

### Deferred Ideas (OUT OF SCOPE)
- 拖拽排序类别（未来版本考虑）
- 折叠/展开类别（如果类别很多时有用）

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FR-1 | 视图切换改为3选项：列表/网格/分组 | 修改 `TagLibraryViewMode` 枚举，添加 `grouped` 值 |
| FR-1 | 分组视图按类别分组显示条目 | 使用 `CustomScrollView` + `SliverList` + `SliverPersistentHeader` |
| FR-1 | 每个类别有清晰的分组标题 | 使用 `SliverPersistentHeader` 实现吸顶效果 |
| FR-1 | 分组视图设为默认视图 | 修改 `TagLibraryPageState` 默认值，处理存储迁移 |

## Standard Stack

### Core (项目已使用)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter | SDK 3.16+ | UI框架 | 项目基础 |
| flutter_riverpod | ^2.5.1 | 状态管理 | 项目标准状态管理方案 |
| go_router | ^14.2.0 | 路由 | 项目标准路由方案 |

### UI Components (项目已使用)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter_staggered_grid_view | ^0.7.0 | 瀑布流布局 | 当前卡片视图使用 |
| flex_color_scheme | ^7.3.1 | 主题方案 | 项目标准主题 |

### 不需要引入的库
| Library | Reason |
|---------|--------|
| flutter_sticky_header | 不需要，Flutter 内置 `SliverPersistentHeader` 即可实现吸顶效果 |
| group_list_view | 不需要，使用 `Sliver` 系列组件更灵活 |

## Architecture Patterns

### Recommended Implementation Structure

```
lib/presentation/screens/tag_library_page/
├── tag_library_page_screen.dart          # 主页面（添加分组视图分支）
├── widgets/
│   ├── tag_library_toolbar.dart          # 工具栏（修改视图切换、添加排序）
│   ├── entry_card.dart                   # 条目卡片（复用）
│   ├── entry_list_item.dart              # 列表项（复用）
│   └── grouped_view/                     # 新增：分组视图相关组件
│       ├── grouped_entries_view.dart     # 分组视图主组件
│       └── category_header.dart          # 吸顶分类标题
```

### Pattern 1: Sliver-based Grouped List
**What:** 使用 Flutter 的 `Sliver` 系列组件实现吸顶分组列表
**When to use:** 需要吸顶标题的分组列表场景
**Example:**
```dart
// Source: Flutter official docs + project patterns
CustomScrollView(
  slivers: [
    for (final category in categories)
      SliverPersistentHeader(
        pinned: true,  // 吸顶关键
        delegate: CategoryHeaderDelegate(
          category: category,
          minHeight: 40,
          maxHeight: 40,
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 240,
            mainAxisExtent: 80,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => EntryCard(...),
            childCount: entries.length,
          ),
        ),
      ),
  ],
)
```

### Pattern 2: State Management with Riverpod
**What:** 使用 `@Riverpod` 控制器管理页面状态
**When to use:** 所有状态变更场景
**Example:**
```dart
// Source: lib/presentation/providers/tag_library_page_provider.dart
@Riverpod(keepAlive: true)
class TagLibraryPageNotifier extends _$TagLibraryPageNotifier {
  @override
  TagLibraryPageState build() {
    _storage = ref.watch(localStorageServiceProvider);
    return _loadData();
  }

  void setViewMode(TagLibraryViewMode mode) {
    state = state.copyWith(viewMode: mode);
    _storage.setTagLibraryViewMode(mode.index);  // 存储3值
  }
}
```

### Pattern 3: View Mode Storage Migration
**What:** 视图模式存储从2值改为3值需要向后兼容
**When to use:** 修改枚举后需要处理旧数据
**Example:**
```dart
// Source: project pattern
TagLibraryViewMode _parseViewMode(int? index) {
  // 旧数据：0=card, 1=list
  // 新数据：0=card, 1=list, 2=grouped
  return switch (index) {
    1 => TagLibraryViewMode.list,
    2 => TagLibraryViewMode.grouped,
    _ => TagLibraryViewMode.grouped,  // 默认改为 grouped
  };
}
```

### Anti-Patterns to Avoid
- **不要在 build 方法中计算分组数据**: 应该在 provider 中预处理，避免重复计算
- **不要为每个分组使用独立的 ScrollView**: 使用统一的 `CustomScrollView` 保持滚动连贯性
- **不要忽略空类别**: 空类别应该显示占位提示或隐藏

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| 吸顶标题 | 自定义 ScrollController 监听 | `SliverPersistentHeader` | 性能更好，Flutter 原生支持 |
| 分组列表 | 多个 ListView 嵌套 | `CustomScrollView` + `Sliver` | 保持滚动连贯性，支持吸顶 |
| 下拉菜单 | 完全自定义 Popup | `DropdownButton` / `PopupMenuButton` | Material Design 规范，无障碍支持 |

**Key insight:** Flutter 的 `Sliver` 系列组件专门用于复杂滚动场景，性能优于手动实现。

## Common Pitfalls

### Pitfall 1: Sliver 嵌套错误
**What goes wrong:** 在非 Sliver 组件中直接使用 Sliver 组件导致渲染错误
**Why it happens:** `Sliver` 组件只能作为 `CustomScrollView` 的 slivers 参数
**How to avoid:** 使用 `SliverToBoxAdapter` 包装普通 Widget，或确保只在 `CustomScrollView` 中使用 Sliver
**Warning signs:** 运行时报错 "Sliver child must be a Sliver"

### Pitfall 2: 状态存储不兼容
**What goes wrong:** 修改枚举后，旧用户存储的 viewMode 值对应错误的视图
**Why it happens:** `TagLibraryViewMode.card.index` 从 0 变为其他值，或新增值插入中间
**How to avoid:**
1. 只在枚举末尾添加新值
2. 或编写迁移逻辑解析旧值
3. 默认值改为新的 `grouped`

### Pitfall 3: 分组数据重复计算
**What goes wrong:** 每次 build 都重新计算分组，导致性能问题
**Why it happens:** 在 widget 的 build 方法中直接进行 groupBy 操作
**How to avoid:** 在 provider 中使用 `select` 或缓存分组结果

### Pitfall 4: 吸顶标题高度不一致
**What goes wrong:** `minHeight` 和 `maxHeight` 不一致导致吸顶时跳动
**Why it happens:** `SliverPersistentHeader` 的 delegate 中 min/max 高度不同
**How to avoid:** 对于固定高度标题，minHeight 和 maxHeight 设置为相同值

## Code Examples

### 1. 修改 TagLibraryViewMode 枚举
```dart
// lib/presentation/providers/tag_library_page_provider.dart
enum TagLibraryViewMode {
  /// 卡片视图
  card,

  /// 列表视图
  list,

  /// 分组视图（新增）
  grouped,
}
```

### 2. 视图切换按钮（3状态）
```dart
// lib/presentation/screens/tag_library_page/widgets/tag_library_toolbar.dart
Widget _buildViewModeToggle(ThemeData theme, TagLibraryPageState state) {
  return Container(
    decoration: BoxDecoration(...),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ViewModeButton(
          icon: Icons.view_list_rounded,
          isSelected: state.viewMode == TagLibraryViewMode.list,
          onTap: () => setViewMode(TagLibraryViewMode.list),
        ),
        _ViewModeButton(
          icon: Icons.grid_view_rounded,
          isSelected: state.viewMode == TagLibraryViewMode.card,
          onTap: () => setViewMode(TagLibraryViewMode.card),
        ),
        _ViewModeButton(
          icon: Icons.folder_copy_outlined,  // 分组视图图标
          isSelected: state.viewMode == TagLibraryViewMode.grouped,
          onTap: () => setViewMode(TagLibraryViewMode.grouped),
        ),
      ],
    ),
  );
}
```

### 3. 分组视图实现
```dart
// lib/presentation/screens/tag_library_page/widgets/grouped_view/grouped_entries_view.dart
class GroupedEntriesView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tagLibraryPageNotifierProvider);

    // 按分类分组
    final grouped = _groupEntriesByCategory(state.filteredEntries, state.categories);

    return CustomScrollView(
      slivers: [
        for (final group in grouped) ...[
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
                (context, index) => EntryCard(
                  entry: group.entries[index],
                  // ... 其他参数
                ),
                childCount: group.entries.length,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

### 4. 吸顶标题 Delegate
```dart
// lib/presentation/screens/tag_library_page/widgets/grouped_view/category_header.dart
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
          Icon(Icons.folder_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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

### 5. Toolbar 排序下拉菜单
```dart
// 添加到 TagLibraryToolbar 的 build 方法中
Widget _buildSortDropdown(ThemeData theme, TagLibraryPageState state) {
  return DropdownButtonHideUnderline(
    child: DropdownButton<TagLibrarySortBy>(
      value: state.sortBy,
      icon: const Icon(Icons.arrow_drop_down, size: 18),
      borderRadius: BorderRadius.circular(8),
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
  );
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| 2状态视图切换 | 3状态视图切换 | Phase 1 | 新增分组视图，默认改为分组 |
| 无全局排序 | Toolbar 全局排序 | Phase 1 | 所有视图共享排序设置 |
| 普通滚动列表 | 吸顶分组列表 | Phase 1 | 更好的类别导航体验 |

## Open Questions

1. **存储迁移策略**
   - What we know: 当前存储 0=card, 1=list
   - What's unclear: 是否需要向后兼容，还是直接改默认值为 grouped
   - Recommendation: 修改解析逻辑，旧值 0/1 映射到 card/list，默认值改为 grouped

2. **空类别处理**
   - What we know: 分组视图需要显示所有类别
   - What's unclear: 空类别是显示占位提示还是隐藏
   - Recommendation: 在 Claude's Discretion 中决定，建议显示占位提示保持结构清晰

3. **排序与分组的交互**
   - What we know: 类别排序跟随全局排序
   - What's unclear: 当按"名称"排序时，类别本身是否也按名称排序
   - Recommendation: 类别固定按 sortOrder 排序，只有条目跟随全局排序

## Validation Architecture

> Skip this section entirely if workflow.nyquist_validation is false in .planning/config.json

根据 `.planning/config.json`，`workflow.nyquist_validation` 未显式设置，默认为 false。跳过此部分。

## Sources

### Primary (HIGH confidence)
- `/mnt/e/Aaalice_NAI_Launcher/lib/presentation/screens/tag_library_page/tag_library_page_screen.dart` - 主页面结构
- `/mnt/e/Aaalice_NAI_Launcher/lib/presentation/providers/tag_library_page_provider.dart` - 状态管理
- `/mnt/e/Aaalice_NAI_Launcher/lib/presentation/screens/tag_library_page/widgets/tag_library_toolbar.dart` - 工具栏实现
- `/mnt/e/Aaalice_NAI_Launcher/lib/presentation/screens/tag_library_page/widgets/entry_card.dart` - 条目卡片组件
- `/mnt/e/Aaalice_NAI_Launcher/lib/data/models/tag_library/tag_library_category.dart` - 分类数据模型
- `/mnt/e/Aaalice_NAI_Launcher/lib/data/models/tag_library/tag_library_entry.dart` - 条目数据模型
- Flutter official docs - Sliver components

### Secondary (MEDIUM confidence)
- Flutter API docs - `SliverPersistentHeader` 使用模式
- Material Design 3 规范 - 下拉菜单样式

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - 项目已有明确技术栈
- Architecture: HIGH - 基于现有代码分析
- Pitfalls: MEDIUM - 基于 Flutter Sliver 常见问题和项目经验

**Research date:** 2025-02-28
**Valid until:** 2025-03-30 (Flutter 稳定版本周期)
