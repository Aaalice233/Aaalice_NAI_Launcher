## 2026-02-12

- Implemented PNG embedding by inserting/replacing only the `naiv4vibe` `tEXt` chunk while copying all other chunks unchanged.
- Validated PNG input with `image` package (`PngDecoder`) before embed/extract to provide clear invalid-format errors.
- Stored envelope metadata with explicit fields: `version`, `type`, `timestamp`, and `data` for forward compatibility.
- 新建 `lib/data/services/vibe_import_service.dart`，采用构造函数注入 `VibeLibraryImportRepository`，服务层不直接触达 Hive/数据库。
- 导入 API 拆分为 `importFromFile` / `importFromImage` / `importFromEncoding`，并复用内部 `_importParsedSources` 实现统一结果模型、进度回调与冲突策略。
- 对 `ConflictResolution.ask` 在服务层按 `skip` 处理，保持无 UI 依赖，交互决策应由调用方在进入服务前完成。
- 新增 `lib/core/utils/vibe_encoding_utils.dart`，提供 `encodeToJson` / `encodeToBase64` / `encodeToUrlSafeBase64` / `decode` / `isVibeEncoding` 五个统一入口。
- 编码结果只保留分享所需字段（名称、强度、infoExtracted、vibeEncoding），显式不包含文件路径等敏感信息。
- 解码器加入 payload 大小上限（2MB）与结构校验，避免超长字符串和畸形数据直接进入业务层。
