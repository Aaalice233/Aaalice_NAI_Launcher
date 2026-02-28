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

**Status:** 4/5 plans completed

| Plan | Wave | Description | Status |
|------|------|-------------|--------|
| PLAN-01 | 1 | 提取服务方法到 GenerationSaveService | ✅ 完成 |
| PLAN-02 | 1 | 提取 GenerationControls 及其内嵌组件 | ✅ 完成 |
| PLAN-03 | 2 | 提取布局辅助组件（ResizeHandle, CollapsedPanel） | ✅ 完成 |
| PLAN-04 | 3 | 提取面板组件并简化 desktop_layout.dart | ✅ 完成 |
| PLAN-05 | 4 | 清理、验证和最终优化 | 🟡 Ready |

**Progress:**
- desktop_layout.dart: 356 行 → 191 行（减少 46%）
- 新组件: LeftPanel, RightPanel, MainWorkspace
- 导出文件: widgets/index.dart

---
