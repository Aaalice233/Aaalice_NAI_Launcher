# Tag Group 多语言修复与按钮清理

## 目标
1. 修复补充词库对话框中的多语言显示问题
2. 删除主屏幕的"展开全部"和"扩展标签"按钮
3. 按钮文字修改

## 执行步骤

### 1. 修复多语言 - `tag_group_mapping_panel.dart`

#### 1.1 修复分类名称显示
- 第 327 行：`TagSubCategoryHelper.getDisplayName(category)` 添加 locale 参数
- 获取当前 locale：`Localizations.localeOf(context).languageCode`

#### 1.2 修复 MiniChip 显示
- `_buildMiniChip` 方法需要根据 groupTitle 查找节点获取本地化名称
- 添加 `_getDisplayNameByTitle(String groupTitle)` 方法
- 或者直接在 `_buildCategoryRow` 中传入节点信息

### 2. 删除主屏幕按钮 - `prompt_config_screen.dart`

#### 2.1 删除"展开全部"按钮
- 删除第 193-217 行（收起/展开全部按钮）

#### 2.2 删除"扩展标签"开关
- 删除第 218-244 行（全局扩展标签开关）

#### 2.3 清理相关状态
- 如果 `_expandedNaiCategories` 不再使用，删除相关代码

### 3. 修改 l10n 文件

#### 3.1 `app_zh.arb`
- 修改 `common_deselectAll`: "取消全选" → "全不选"
- 添加 `naiMode_manageExtendedLibrary`: "管理扩展词库"

#### 3.2 `app_en.arb`
- 修改 `common_deselectAll`: "Deselect All" → "Deselect All" (保持不变)
- 添加 `naiMode_manageExtendedLibrary`: "Manage Extended Library"

### 4. 修改按钮文字 - `prompt_config_screen.dart`
- 第 262 行：`context.l10n.naiMode_syncLibrary` → `context.l10n.naiMode_manageExtendedLibrary`

## 文件变更
- `lib/presentation/screens/prompt_config/tag_group_mapping_panel.dart`
- `lib/presentation/screens/prompt_config/prompt_config_screen.dart`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_en.arb`
