# 测试与验证

工程规则见 [AGENTS.md](../AGENTS.md#测试规范)。命令从仓库根目录执行；先核对改动影响，再选择能证明行为的最小检查。

## 受控测试入口

~~~powershell
# 只查看当前改动会选中哪些测试
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1 -ListOnly

# 根据当前改动运行相关测试；每批默认 120 秒 watchdog
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1

# 限定源码范围并补充回归测试
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1 -Path "lib/core/services/anlas_calculator.dart" -Include "test/core/services/anlas_calculator_test.dart"

# 适用于共享契约、核心流程或发布验证；总计最多 600 秒
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run_flutter_tests.ps1
~~~

`dart_test.yaml` 限制单个测试 30 秒、默认并发 4。不得直接运行无总时限的 `flutter test`；超时必须终止进程树并定位未完成异步资源，不能原样重跑或提高上限。

## 分层与证据

| 检查 | 用途 | 不能证明 |
|---|---|---|
| core/data/provider 单测 | 状态、请求、格式、IO、异常与恢复 | 真实设备界面和公网服务行为 |
| Widget test | 布局、语义、状态与输入事件；模拟尺寸/IME/SafeArea | 真实窗口、系统文件选择器或平台输入链 |
| Analyze/格式/diff | 静态问题与改动范围 | 用户操作后的功能结果 |
| 构建 | 目标平台编译、链接与打包 | 已启动或交互正常 |
| 运行验收 | 实际页面操作、截图与增量日志 | 未操作的平台、尺寸或状态 |

真实 UI 验收使用 [aaalice-runtime-verify](../.agents/skills/aaalice-runtime-verify/SKILL.md)：用户提出自动化验收时，Agent 自动启动或复用热重载，Windows 使用 Computer Use，Android 使用 ADB，并实际查看截图。单纯运行测试或修改文档不会自动触发该流程。

## 测试维护

- 测试路径对应 `lib/` 分层，文件以 `_test.dart` 结尾，按需使用 `mocktail`。
- fake/mock、时钟与异步操作必须受控；测试结束释放 timer、isolate、进程、ProviderContainer 和待完成 Future。
- 需要真实插件、长异步图像流程或平台交互的场景，拆出可测试的 service 边界或使用有总时限与清理的 integration/runtime 验证。
- UI 变更按 [自适应覆盖清单](../docs/design/adaptive_ui_inventory.md) 选择相关状态；不能因父级测试存在就认定菜单、弹窗和编辑态已覆盖。
- 新增 fixture 必须与实际解析器一致、来源可用且无凭据和用户私有数据；大样本优先运行时确定性生成，结束后清理。
- 仅修复由本次修改引起且属于任务范围的失败，既有或环境问题保留原始错误并单独报告。

验证结果写在本次交付或 CI 记录中，包含命令、范围和结果。仓库不维护无版本、无运行证据的“全部测试通过”报告，历史结果不能作为当前通过证明。
