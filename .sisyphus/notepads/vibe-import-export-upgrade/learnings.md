## 2026-02-12

- `image` package can read PNG `tEXt` metadata through `PngDecoder.startDecode(...).info.textData`.
- Re-encoding PNG via `PngEncoder` does not keep every original chunk, so raw chunk-level copy is safer when full metadata preservation is required.
- `tEXt` payload should remain Latin-1 compatible; JSON with non-ASCII characters should be escaped to `\uXXXX` before writing.
- 新的统一导入服务可先解析为 `VibeReferenceV4` 列表，再统一走一套冲突处理与仓储保存流程，能显著减少三种导入来源的重复逻辑。
- 冲突检测基于名称标准化（`trim + lowercase`）时，`replace` 场景可直接复用原条目 `id`，避免额外删除动作并保留历史关联。
- `VibeEncodingUtils` 使用统一 envelope（`version/type/timestamp/encoding/data`）可以同时支持 JSON、Base64、URL-safe Base64，并为后续版本扩展保留兼容空间。
- 解码时先尝试 JSON，再尝试标准/URL-safe Base64（含 padding 归一化）能兼容更多复制粘贴输入场景。
- Unit tests can use an in-memory 1x1 PNG (Base64) to cover embed/extract without filesystem dependency.
- Because VibeReferenceV4 is a Freezed model, round-trip consistency can be asserted with object equality.

- `VibeLibraryEntry` 新增 Hive 字段时，保持历史字段编号不变并在末尾追加（`@HiveField(16-19)`）即可兼容旧数据读取。
- 对 Freezed + Hive 模型调整构造参数后，需要立即执行 `build_runner` 以同步 `*.freezed.dart` 与 `*.g.dart`，否则会出现构造参数不匹配报错。
- 2026-02-12: Vibe library storage now supports hybrid read path (Hive metadata plus file payload) with legacy fallback when filePath is empty.
- 2026-02-12: typeId 迁移可通过“先备份 Hive 文件 -> 旧 Adapter 读取 -> 导出到文件 -> 清空并用新 Adapter 重建”实现，且可避免直接二进制改写。
- 2026-02-12: 回滚时应仅删除本次迁移新建的 `.naiv4vibe/.naiv4vibebundle` 文件，用户原始文件和备份目录需保留。
