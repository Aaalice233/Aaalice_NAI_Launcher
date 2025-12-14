# Tag Group 悬浮预览功能

## 任务描述
在管理组对话框中，为叶子节点（Tag Group）添加悬浮 Tooltip 预览功能，显示前 20 个标签。

## 技术方案
方案 A：自定义 Tooltip + 异步加载标签数据

## 执行步骤

### 1. 修改 `tag_group_manage_dialog.dart`

#### 1.1 添加状态管理
- 添加 `_previewCache` Map 缓存已加载的标签预览数据
- 添加 `_loadingGroups` Set 跟踪正在加载的组

#### 1.2 添加预览加载方法
```dart
Future<List<String>> _loadTagPreview(String groupTitle) async
```
- 调用 `DanbooruTagGroupService.getTagGroup()`
- 提取前 20 个标签名称
- 缓存到 `_previewCache`

#### 1.3 修改 `_buildLeafNode()` 方法
- 包装 Checkbox 行为 `Tooltip` widget
- Tooltip 使用 `richMessage` 参数显示自定义 Widget
- 实现紧凑的标签预览布局：
  ```
  ┌───────────────────────────────────┐
  │ 📋 发色 · 12 tags                 │
  ├───────────────────────────────────┤
  │ blonde_hair, brown_hair, black_   │
  │ hair, white_hair, red_hair ...    │
  └───────────────────────────────────┘
  ```

#### 1.4 自定义 Tooltip 内容 Widget
```dart
Widget _buildPreviewTooltip(TagGroupTreeNode node, List<String>? tags)
```
- 标题：显示名称 + 标签数量
- 内容：标签列表（逗号分隔，最多 20 个）
- 加载中/无数据状态处理

### 2. UI 设计规范
- 最大宽度：280px
- 背景色：`surfaceContainerHighest`
- 标题：`labelMedium` + primary 色
- 标签：`bodySmall` + onSurface 色
- 圆角：8px
- 内边距：8px 12px

### 3. 预期结果
- 悬浮在 Tag Group 条目上 300ms 后显示 Tooltip
- Tooltip 显示组名 + 前 20 个标签
- 数据已缓存时即时显示
- 首次悬浮时异步加载数据

## 文件变更
- `lib/presentation/screens/prompt_config/tag_group_manage_dialog.dart` (修改)

## 依赖
- `DanbooruTagGroupService` (已有)
- `danbooruTagGroupServiceProvider` (已有)
