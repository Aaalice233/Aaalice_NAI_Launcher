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

## Phase 2: 图像解析稳定性修复
**Goal**: 修复影响稳定性的图像解析相关问题

**Depends**: Phase 1

**Plans**:
1. **诊断**: 分析图像解析相关崩溃报告和日志
2. **修复**: 修复解析逻辑中的错误处理和边界情况
3. **测试**: 验证各种格式图像的正确解析

**Success Criteria**:
- [ ] 图像解析无崩溃
- [ ] 常见格式（PNG/JPG/WebP）正确解析
- [ ] 元数据读取稳定

---

## Phase 3: 界面和性能优化
**Goal**: 根据用户反馈优化界面和性能

**Depends**: Phase 2

**Plans**:
1. **界面调整**: 实现用户反馈的布局和交互改进
2. **性能优化**: 词库加载、图片缓存优化
3. **代码质量**: 修复分析错误，清理代码

**Success Criteria**:
- [ ] 界面改进完成
- [ ] 性能明显提升
- [ ] `flutter analyze` 无错误

---

## Milestone 完成标准

- [ ] 所有 Phase 完成并通过验证
- [ ] 无恶性 Bug
- [ ] 代码质量达标

---

*Next Action*: Run `/gsd:plan-phase 1` to start planning.
*Created*: 2025-02-28
