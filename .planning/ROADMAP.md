# NAI Launcher — Roadmap

## Milestone: v1.0 稳定版

---

## Phase 1: 词库分组视图
**Goal**: 实现按类别分组的词库视图，并设为默认

**Depends**: None

**Plans**:
1. **枚举和状态**: 修改 `TagLibraryViewMode` 添加 `grouped`，更新默认值为 `grouped`
2. **Toolbar 改造**: 将视图切换从 2 按钮改为 3 按钮（列表/网格/分组）
3. **分组渲染**: 实现按类别分组的列表渲染逻辑
4. **UI 优化**: 分组标题样式、分组内卡片布局

**Success Criteria**:
- [x] 3 状态视图切换正常工作
- [x] 分组视图正确按类别分组显示
- [x] 分组视图设为默认
- [x] 界面美观，交互流畅

---

## Phase 2: desktop_layout.dart 拆分

**Goal:** 将 desktop_layout.dart (356行) 拆分为更小、更可维护的组件，目标行数控制在500行以内。

**Requirements**:
- desktop_layout.dart 行数控制在 500 行以内
- 所有组件功能正常，无回归
- flutter analyze 无错误
- 代码结构清晰，导入关系合理

**Depends on:** Phase 1

**Status:** 5/5 plans completed

| Plan | Wave | Description | Status |
|------|------|-------------|--------|
| PLAN-01 | 1 | 提取服务方法到 GenerationSaveService | ✅ 完成 |
| PLAN-02 | 1 | 提取 GenerationControls 及其内嵌组件 | ✅ 完成 |
| PLAN-03 | 2 | 提取布局辅助组件（ResizeHandle, CollapsedPanel） | ✅ 完成 |
| PLAN-04 | 3 | 提取面板组件并简化 desktop_layout.dart | ✅ 完成 |
| PLAN-05 | 4 | 清理、验证和最终优化 | Complete    | 2026-02-28 | Plan | Wave | Description | Status |
|------|------|-------------|--------|
| PLAN-01 | 1 | 实现 add_to_library_dialog 的 TagLibrary 接入 | ✅ 完成 |
| PLAN-02 | 1 | 实现 save_as_preset_dialog 的预设保存 | ✅ 完成 |
| PLAN-03 | 2 | 实现 detail_metadata_panel 的 Vibe 保存对话框 | ✅ 完成 |
| PLAN-04 | 3 | 实现 vibe_export_handler 的 PNG 元数据嵌入（可选）| ⏭️ 跳过 |
| PLAN-05 | 3 | 测试验证和代码清理 | ✅ 完成 |

**TODO 清单**:
- [x] add_to_library_dialog.dart (2 TODOs) - 接入 TagLibraryProvider
- [x] save_as_preset_dialog.dart (2 TODOs) - 接入 PromptConfigProvider
- [x] detail_metadata_panel.dart (1 TODO) - 实现 Vibe 保存对话框
- [ ] vibe_export_handler.dart (1 TODO) - 实现 PNG iTXt 嵌入（用户决定跳过）

**完成总结**:
- flutter analyze: 零错误
- 代码格式化: 修复 23 处尾随逗号问题
- 所有已实现功能代码质量达标

### Phase 4: 词库条目编辑界面添加预览图显示范围调整功能

**Goal:** 在词库条目编辑对话框中添加预览图显示范围调整功能，允许用户通过拖拽平移和缩放来选择图片的显示区域。调整后该设置应用于所有显示该预览图的地方（卡片、悬浮预览等）。

**Requirements**:
- 使用 InteractiveViewer 实现拖拽平移 + 缩放调整
- 扩展 TagLibraryEntry 模型，添加 offsetX/Y 和 scale 字段
- 编辑对话框集成调整入口（点击预览图显示选项菜单）
- EntryCard 和悬浮预览应用新的显示范围设置
- 所有用户可见字符串支持中英文本地化
- flutter analyze 无错误

**Depends on:** Phase 3

**Status:** 5/5 plans completed

| Plan | Wave | Description | Status |
|------|------|-------------|--------|
| PLAN-01 | 1 | 数据模型扩展 - TagLibraryEntry 添加 offset/scale 字段 | ✅ 完成 |
| PLAN-02 | 2 | 调整对话框实现 - 使用 InteractiveViewer 实现调整界面 | ✅ 完成 |
| PLAN-03 | 3 | 编辑对话框集成 - 添加调整入口和实时预览 | ✅ 完成 |
| PLAN-04 | 4 | EntryCard 和悬浮预览集成 - 应用显示范围设置 | ✅ 完成 |
| PLAN-05 | 5 | 本地化与测试验证 - 添加本地化字符串，运行分析验证 | ✅ 完成 |

**完成总结**:
- 添加 9 个本地化键值（中英文）
- flutter analyze: 零错误
- dart fix: 无需要修复的问题
- 创建组件导出索引文件
- 285 个测试通过（11 个预先存在的失败）

**实现决策**:
- 调整方式: 拖拽平移 + 缩放（使用 Flutter 原生 InteractiveViewer）
- 数据存储: TagLibraryEntry 添加 thumbnailOffsetX, thumbnailOffsetY, thumbnailScale 字段
- 交互方式: 点击预览图显示选项菜单，选择"调整显示范围"进入调整模式
- 应用范围: EntryCard 背景图、悬浮预览、编辑对话框预览区域
- 默认值: offset(0,0) 居中，scale 1.0（向后兼容）

### Phase 5: 给设置-外观里添加字体大小控制功能

**Goal:** 在设置-外观区域添加字体大小调整功能，允许用户通过滑块控制应用全局字体缩放比例

**Requirements**:
- 使用 Slider 滑块控件，范围 80%-150%，步长 10%
- 实时预览三种字号文本效果
- 设置即时生效并持久化存储
- 提供重置按钮恢复默认值
- flutter analyze 无错误

**Depends on:** Phase 4

**Status:** 4/6 plans completed

| Plan | Wave | Description | Status |
|------|------|-------------|--------|
| PLAN-01 | 1 | 创建 FontScaleNotifier Provider - 状态管理 | ✅ 完成 |
| PLAN-02 | 1 | 扩展 LocalStorageService 和 StorageKeys - 存储支持 | ✅ 完成 |
| PLAN-03 | 2 | 修改 app.dart 集成字体缩放 - 全局应用 | ✅ 完成 |
| PLAN-04 | 3 | 添加外观设置 UI - 滑块和预览 | ✅ 完成 |
| PLAN-05 | 4 | 添加本地化字符串 - 中英文支持 | Ready |
| PLAN-06 | 5 | 验证和测试 - 功能验证和代码分析 | Ready |

**实现决策**:
- 控件类型: Slider 滑块（与队列优先级等数字选择保持一致）
- 范围与粒度: 80%-150%，步长 10%，默认值 100%
- 应用方式: MediaQuery.textScaler 全局应用
- 实时预览: 滑块拖动时字体大小实时变化
- 预览文本: "落霞与孤鹜齐飞，秋水共长天一色"（展示中文显示效果）

---
