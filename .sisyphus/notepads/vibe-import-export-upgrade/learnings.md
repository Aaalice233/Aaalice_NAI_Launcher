## 2026-02-12

- `image` package can read PNG `tEXt` metadata through `PngDecoder.startDecode(...).info.textData`.
- Re-encoding PNG via `PngEncoder` does not keep every original chunk, so raw chunk-level copy is safer when full metadata preservation is required.
- `tEXt` payload should remain Latin-1 compatible; JSON with non-ASCII characters should be escaped to `\uXXXX` before writing.
- 新的统一导入服务可先解析为 `VibeReferenceV4` 列表，再统一走一套冲突处理与仓储保存流程，能显著减少三种导入来源的重复逻辑。
- 冲突检测基于名称标准化（`trim + lowercase`）时，`replace` 场景可直接复用原条目 `id`，避免额外删除动作并保留历史关联。
- `VibeEncodingUtils` 使用统一 envelope（`version/type/timestamp/encoding/data`）可以同时支持 JSON、Base64、URL-safe Base64，并为后续版本扩展保留兼容空间。
- 解码时先尝试 JSON，再尝试标准/URL-safe Base64（含 padding 归一化）能兼容更多复制粘贴输入场景。
