# 测试

测试规则以仓库根目录 [`AGENTS.md`](../AGENTS.md#测试规范) 为准。

```powershell
# 根据当前改动运行相关测试；每批最多 120 秒
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1

# 运行全量测试；总计最多 600 秒，超时会终止整个进程树
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run_flutter_tests.ps1
```

单个测试由 `dart_test.yaml` 限制为 30 秒。测试必须使用可控的 fake/mock 和确定性输入；需要真实平台插件、长异步图像流程或完整 UI 交互的场景放入带清理步骤的 runtime/integration verification，不得写成无法取消的 Widget test。
