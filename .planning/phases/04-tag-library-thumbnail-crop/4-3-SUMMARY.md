---
phase: 4
plan: 3
subsystem: tag-library
status: completed
dependencies:
  - PLAN-01
  - PLAN-02
key-decisions:
  - 使用 showModalBottomSheet 显示选项菜单，移动端和桌面端体验一致
  - 预览图变换使用 Transform widget 直接应用 offset/scale
  - 编辑模式自动加载已保存的显示范围设置
metrics:
  duration: 25min
  tasks_completed: 6
  files_modified: 2
  lines_added: 111
  lines_removed: 12
---

# Phase 4 Plan 3: 编辑对话框集成调整入口 总结

## 概述

在 `entry_add_dialog.dart` 中成功集成预览图显示范围调整功能，实现了点击预览图显示选项菜单、打开调整对话框、实时预览调整效果、保存调整参数的完整流程。

## 实现内容

### 1. 状态管理扩展

**文件**: `lib/presentation/screens/tag_library_page/widgets/entry_add_dialog.dart`

- 添加三个状态变量：`_thumbnailOffsetX`, `_thumbnailOffsetY`, `_thumbnailScale`
- 编辑模式时从 `widget.entry` 加载已保存的显示范围设置
- 新建模式时使用默认值 (0.0, 0.0, 1.0)

### 2. 预览图点击行为修改

- **无图片时**: 直接调用 `_selectThumbnail()` 选择新图片
- **有图片时**: 显示底部选项菜单

### 3. 选项菜单实现

使用 `showModalBottomSheet` 显示两个选项：
- **选择新图片**: 打开文件选择器更换图片
- **调整显示范围**: 打开 `ThumbnailCropDialog` 进行调整

### 4. 调整对话框集成

- 调用 `showThumbnailCropDialog` 打开调整界面
- 传递当前图片路径和初始 offset/scale 值
- 确认后更新状态，预览图实时显示调整效果

### 5. 预览图显示逻辑

使用 `Transform` widget 应用变换：
```dart
Transform(
  alignment: Alignment.center,
  transform: Matrix4.identity()
    ..translate(
      _thumbnailOffsetX * 80 * (_thumbnailScale - 1.0),
      _thumbnailOffsetY * 80 * (_thumbnailScale - 1.0),
    )
    ..scale(_thumbnailScale),
  child: Image.file(...),
)
```

### 6. 保存逻辑更新

- 编辑模式：`copyWith` 包含新的显示范围字段
- 新建模式：调用 `addEntry` 传递 offset/scale 参数

**文件**: `lib/presentation/providers/tag_library_page_provider.dart`

- 扩展 `addEntry` 方法签名，添加 `thumbnailOffsetX`, `thumbnailOffsetY`, `thumbnailScale` 参数
- 创建条目时传递这些参数给 `TagLibraryEntry.create`

## 验证结果

- [x] 无图片时点击直接选择新图片
- [x] 有图片时点击显示选项菜单
- [x] 菜单有两个选项：选择新图片、调整显示范围
- [x] 选择"调整显示范围"打开 ThumbnailCropDialog
- [x] 调整完成后预览图实时更新
- [x] 保存条目时 offset/scale 被正确保存
- [x] 编辑现有条目时能加载已保存的 offset/scale
- [x] `flutter analyze` 无错误

## 修改的文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/presentation/screens/tag_library_page/widgets/entry_add_dialog.dart` | 修改 | 集成调整功能，添加状态管理和交互逻辑 |
| `lib/presentation/providers/tag_library_page_provider.dart` | 修改 | 扩展 addEntry 方法支持新参数 |

## 提交记录

```
c84d4c11 feat(4-3): 编辑对话框集成预览图显示范围调整功能
```

## 后续工作

- **PLAN-04**: EntryCard 和悬浮预览集成 — 在卡片和悬浮预览中应用显示范围设置
- **PLAN-05**: 本地化与测试验证 — 添加本地化字符串，运行完整分析验证

## 偏差记录

无偏差，计划按预期执行完成。
