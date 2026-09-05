# Vibe 测试样本

本目录目前只保留说明，不预置二进制样本，也没有名为 `valid/bundle_single.naiv4vibe` 的现成测试文件。导入与导出协议以当前服务和测试构造为准，不维护独立的手写 JSON schema。

相关入口：

- [vibe_import_service.dart](../../../lib/data/services/vibe_import_service.dart)
- [vibe_export_service.dart](../../../lib/data/services/vibe_export_service.dart)
- [vibe_metadata_service.dart](../../../lib/data/services/vibe_metadata_service.dart)
- [vibe_import_service_test.dart](../../data/services/vibe_import_service_test.dart)
- [vibe_export_utils_test.dart](../../core/utils/vibe_export_utils_test.dart)

新增样本优先复用上述测试中的确定性构造。需要检查真实文件兼容性时，使用经授权的最小脱敏样本，并说明来源、格式、对应测试与预期结果。

有效、损坏、截断、空文件及大数据量分别验证；损坏文件的预期错误必须明确。不要提交用户参考图、私有 Prompt、凭据或无授权媒体。大型样本在测试临时目录生成并在结束后清理，不用虚构 fixture 路径或任意大小表替代实际解析验证。
