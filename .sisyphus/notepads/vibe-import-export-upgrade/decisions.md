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

- 将 `VibeLibraryEntry` 的 `@HiveType` 从 `20` 升级到 `23`，并新增 `filePath`/`bundleId`/`bundledVibeNames`/`bundledVibePreviews` 四个可选字段以支持文件系统存储与 bundle 缓存。
- 将 bundle 判定与计数设计为计算属性（`isBundle`、`bundledVibeCount`），不落库，避免引入冗余持久化字段。
- 2026-02-12: Cross-store atomicity rule kept: save does file then Hive, delete does file then Hive.
- 2026-02-12: 新增 `lib/data/services/vibe_library_migration_service.dart`，用 settings 键（schema version / in-progress / backup dir）驱动可恢复迁移流程。
- 2026-02-12: 迁移导出统一复用 `VibeFileStorageService` 与 `VibeLibraryPathHelper`，避免在迁移服务内重复实现文件路径和命名规则。
