# NovelAI 预设数据维护

`scripts/nai_presets_captured.json` 保存历史质量词与负面词样本。它不保证覆盖当前官网全部模型和预设。运行时解析入口见 [prompt_preset_resolution.dart](../lib/core/utils/prompt_preset_resolution.dart)，相关回归见 [prompt_preset_resolution_test.dart](../test/core/utils/prompt_preset_resolution_test.dart)。

## 采集流程

1. 使用当前可用的浏览器工具或开发者工具检查官网实际模型、质量词开关、UC 预设及其请求字段，不依赖固定 DOM、旧工具名或历史预设编号。
2. 优先从可读配置或既有授权请求中提取数据；不为抓取预设自行发起真实生成。需要真实请求时，先取得本次成本与请求范围的明确授权，不假定某订阅或尺寸免费。
3. 在 `tool/.tmp/nai-capture/` 保存采集日期、来源、模型 ID、质量词开关和预设 ID/名称/原始文案。区分用户自己输入的 Prompt 与系统补充词。
4. 原样保留顺序、标点、权重与字段语义；空字符串、关闭预设与未知字段分别处理，不能把缺失值猜成空预设。
5. 对照当前解析器、请求构造和模型映射，核实新增或变化项后再更新 JSON、代码与测试。前端 bundle 与原始网络记录只作本地证据，不提交凭据或用户内容。

~~~powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1 -Path "lib/core/utils/prompt_preset_resolution.dart" -Include "test/core/utils/prompt_preset_resolution_test.dart"
~~~

随机 Prompt 词库使用独立的锁定来源与确定性生成流程，见 [随机词库说明](../tool/random_tag_library/README.md)，不要把这里的质量词/负面词样本混入随机词库。
