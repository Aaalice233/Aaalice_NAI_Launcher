---
wave: 1
depends_on: []
files_modified:
  - lib/presentation/providers/tag_library_page_provider.dart
  - lib/presentation/providers/tag_library_page_provider.g.dart
autonomous: true
---

# Plan 01: 枚举和状态修改

## Goal

修改 `TagLibraryViewMode` 枚举，添加 `grouped` 值，并将默认值改为 `grouped`。同时更新存储读写逻辑以兼容3值状态。

---

## Requirements

- FR-1: 视图切换改为3选项：列表/网格/分组
- FR-1: 分组视图设为默认视图

---

## Tasks

### Task 1: 修改 TagLibraryViewMode 枚举

**Status:** pending

修改 `lib/presentation/providers/tag_library_page_provider.dart` 中的枚举定义：

```dart
/// 词库视图模式
enum TagLibraryViewMode {
  /// 卡片视图
  card,

  /// 列表视图
  list,

  /// 分组视图（新增）
  grouped,
}
```

### Task 2: 修改默认视图模式

**Status:** pending

在 `TagLibraryPageState` 中将默认 `viewMode` 从 `TagLibraryViewMode.card` 改为 `TagLibraryViewMode.grouped`：

```dart
this.viewMode = TagLibraryViewMode.grouped,  // 修改这里
```

### Task 3: 更新存储读写逻辑

**Status:** pending

修改 `_loadData()` 方法中的视图模式解析逻辑，支持3值存储：

```dart
// 加载视图模式
final viewModeIndex = _storage.getTagLibraryViewMode();
final viewMode = switch (viewModeIndex) {
  0 => TagLibraryViewMode.card,
  1 => TagLibraryViewMode.list,
  2 => TagLibraryViewMode.grouped,
  _ => TagLibraryViewMode.grouped,  // 默认改为 grouped
};
```

修改 `setViewMode()` 方法以存储3值：

```dart
void setViewMode(TagLibraryViewMode mode) {
  state = state.copyWith(viewMode: mode);
  // 持久化视图模式
  _storage.setTagLibraryViewMode(mode.index);  // 现在可以存储 0/1/2
}
```

### Task 4: 重新生成代码

**Status:** pending

运行 build_runner 重新生成 `.g.dart` 文件：

```bash
/mnt/e/flutter/bin/dart.bat run build_runner build --delete-conflicting-outputs
```

---

## Verification

- [ ] `TagLibraryViewMode` 枚举包含 `card`, `list`, `grouped` 三个值
- [ ] `TagLibraryPageState` 默认 `viewMode` 为 `TagLibraryViewMode.grouped`
- [ ] 存储读写逻辑正确处理3值状态
- [ ] 代码生成文件已更新且无错误
- [ ] `flutter analyze` 无错误

---

## Must-Haves for Goal Backward Verification

1. **枚举必须有3个值** - 缺少 `grouped` 值则无法支持分组视图
2. **默认必须是 grouped** - 否则无法满足"分组视图设为默认"的需求
3. **存储必须兼容** - 旧数据（0/1）需要正确映射，新数据（2）需要正确存储

---

## Notes

- 存储键 `tagLibraryViewMode` 保持不变，无需迁移
- 旧用户存储的值 0/1 仍然有效，会正确映射到 card/list
- 新默认值 grouped 会在新用户或清除存储后生效
