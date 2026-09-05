# NovelAI 价格数据维护

`scripts/nai_pricing_data.json` 是历史捕获数据，不是当前官网价格的实时保证。运行时估算逻辑见 [anlas_calculator.dart](../lib/core/services/anlas_calculator.dart)，回归见 [anlas_calculator_test.dart](../test/core/services/anlas_calculator_test.dart)。

## 采集边界

先核对当前官网显示的模型、订阅类型、尺寸、步数、数量和功能开关，再确定需要验证的组合。不要把旧模型列表、旧 DOM 选择器或“Opus 免费”的历史说明当成当前事实。

只查看价格与设置不需要发起生成。若必须通过真实请求或余额变化核对费用，需用户明确授权本次请求与成本范围；不能为采集自动遍历并发送生成请求。失败、取消、订阅赠送额度与并发请求可能影响余额，单次余额差不能直接解释为该请求价格。

## 更新流程

1. 用当前可用的浏览器工具或开发者工具打开官网，确认实际页面和账号订阅状态；不依赖特定 MCP 名称或旧工具参数。
2. 在 `tool/.tmp/nai-capture/` 记录采集日期、来源、模型 ID、输入参数、界面显示费用，以及是否实际发送请求。
3. 区分观察值、实际账单值和推导公式。保留异常组合和未知项，不用猜测或默认零费用填空。
4. 对照计算器及其调用方分析差异；只有证据充分时才更新数据、逻辑和相关测试。不要为了匹配旧快照修改当前行为。
5. 更新捕获数据的日期与说明，只提交必要的脱敏参数和费用，不提交 cookie、token、账号余额、完整网络抓包或私人 Prompt。

~~~powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1 -Path "lib/core/services/anlas_calculator.dart" -Include "test/core/services/anlas_calculator_test.dart"
~~~

完成后关闭本次采集使用的临时工具并清理原始记录。测试通过只证明计算器符合相应样本，不证明所有官网定价组合。
