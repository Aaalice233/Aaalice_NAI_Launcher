# 子代理任务模板

将尖括号内容替换为当前任务事实。所有代理都必须遵守仓库 `AGENTS.md`，并以文件、diff、测试和框架实现为依据。

## 独立审查代理

```text
只读审查 <repo> 中 <refactor-scope> 的重构等价性。

基线：<baseline-sha-or-files>
当前：<current-sha-or-working-tree>
允许变化：<allowed-changes>
禁止变化：<preserved-contracts>
你的唯一维度：<functional | lifecycle | layout | wiring | platform>

独立比较基线和当前实现，不读取或复述其他审查结论。主动检查调用方、测试和框架机制。不要因为文件长、缺少额外测试或个人抽象偏好登记问题。

每条候选发现输出：
- ID: R<round>-<dimension>-<number>
- 结论
- 基线行为
- 当前行为
- 触发路径
- 证据（准确路径和行号）
- 用户/维护影响
- 最小验证方式
- 置信度

如果没有发现真实差异，明确写“该维度未发现候选回归”，并列出实际核查过的关键契约。
```

## 对抗性确认代理

```text
只读确认以下候选问题是否真实存在：<finding-ids-and-statements>。

基线：<baseline>
当前：<current>
允许变化：<allowed-changes>

默认候选结论可能是错的。先尝试反证：查找 guard、fallback、共享入口、最近作用域处理、框架真实事件机制、现有测试和调用链。不得因为原审查者有信心就接受结论。

逐项输出：
- ID
- 分类：已确认 | 已反证 | 未决
- 反证尝试
- 支持与反对证据
- 真实触发路径或不可能发生的机制
- 最小复现/测试建议
- 严重度（仅已确认）
- 置信度

同时检查这些发现之外是否存在同一调用链上的遗漏。不要修改文件。
```

## 清洁轮挑战代理

```text
上一批独立审查在 <dimensions> 没有留下已确认问题。请作为新的怀疑者只读挑战“重构已经等价”这一结论。

比较 <baseline> 与 <current>，围绕 <acceptance-matrix> 主动寻找遗漏。优先检查容易在文件移动中丢失的回调、Widget key、Provider 生命周期、路由返回、焦点/手势、响应式分支、Overlay、平台能力、本地化和资源接线。

如果发现候选问题，使用标准发现格式并提供直接证据；如果没有，列出反证尝试和已核验契约。不要用“看起来没问题”代替证据，不要修改文件。
```

## 修复代理

```text
修复已确认的重构回归：<finding-ids>。

仓库：<repo>
基线契约：<expected-behavior>
允许修改：<owned-files>
禁止修改：<out-of-scope-files-and-behavior>
验证：<targeted-checks>
独立报告：tool/.tmp/refactor-parity/<task>/workers/round-<N>-<worker>.md

只处理分配的问题，不增加功能、不改变 UI 设计、不修改 Changelog、不吞异常、不降低测试。修改前核对当前文件和调用方；修改后运行最小充分验证并检查 diff。

报告必须写明：
- 问题 ID 与确认依据
- 修改文件和行为恢复方式
- 保持不变的契约
- 执行的验证及真实结果
- 未解决项或潜在冲突

不要宣布整个重构通过；主 Agent 将整合后重新发起完整审查轮。
```
