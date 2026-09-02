# 云备份全链路性能优化 Handoff

> **历史资料**：本文记录性能重构开始前的基线与外部评审问题，不描述当前实现。当前协议与实现约束以 `cloud_sync_performance_implementation_plan.md`、代码和回归测试为准。

## 目标

请帮助 Aaalice NAI Launcher 制定一套可直接实施的云备份性能优化方案。当前 OneDrive、Google Drive、WebDAV、GitHub 四种备份方式在以下阶段都可能明显偏慢：

1. 准备本地快照
2. 上传备份
3. 拉取备份
4. 应用到本地

希望充分利用各服务官方 API、标准协议、成熟 SDK 或成熟实现，不要闭门自造协议。优化不能通过减少备份数据、跳过完整性校验、静默关闭功能或牺牲崩溃恢复能力实现。

## 项目与技术背景

- Flutter / Dart 跨平台应用，支持 Windows、macOS、Android。
- 云同步核心位于 `lib/core/cloud_sync/`。
- 应用数据适配与落盘位于 `lib/data/cloud_sync/`。
- UI / Provider 位于 `lib/presentation/providers/cloud_sync/` 与 `lib/presentation/screens/cloud_sync/`。
- 当前协议：明文 immutable object + manifest + 小型 `HEAD.json` 指针。
- 每个对象都执行大小与 SHA-256 校验。
- 备份使用显式 allowlist，不包含 OAuth token、密码、API key、缓存、索引、日志、队列或设备专属状态。
- OneDrive 与 Google Drive 不使用加密、解密、恢复密钥或 `KEY.json`。
- 保存连接只验证并保存配置；上传、拉取、应用必须由用户显式触发。
- 功能尚未正式发布，不需要兼容此前未发布的加密快照格式。

## 当前支持的备份方式

### 1. OneDrive

- 使用 Microsoft Graph。
- 数据位于 `/special/approot` 对应的应用文件夹内，业务 namespace 为 `aaalice-sync`。
- 当前小对象也通过 `createUploadSession` 上传。
- 当前每个对象可能重复执行：对象 metadata 查询、目录确认、创建 upload session、上传。
- `ensureFolder()` 会反复确认 `approot`、namespace、`objects`、`snapshots` 等目录。
- 后端目前未启用通用层已有的对象并发上传能力。
- 连接能力检测目前会真实创建、写入、读取、冲突测试并删除探针文件，网络往返很多；用户操作时可能短暂看到“另一项云同步操作正在进行”。
- 粗略分析：有 `N` 个新 record 时，完整上传可能达到约 `8N + 14` 次网络往返；100 个 record 可超过 800 RTT。

官方资料：

- 小文件单请求上传（当前文档称最大 250 MB）：  
  https://learn.microsoft.com/en-us/graph/api/driveitem-put-content?view=graph-rest-1.0
- Upload session：  
  https://learn.microsoft.com/en-us/graph/api/driveitem-createuploadsession?view=graph-rest-1.0
- Graph JSON batching：  
  https://learn.microsoft.com/en-us/graph/json-batching
- Graph throttling：  
  https://learn.microsoft.com/en-us/graph/throttling

希望重点判断：

- 是否应让绝大多数小于 4 MiB 的 immutable object 改用单次 `PUT .../content`，只让真正的大对象使用 upload session。
- 如何在保留 `If-Match` / `If-None-Match`、同名冲突和响应丢失幂等语义的前提下使用单请求上传。
- 是否应缓存 `approot` 和目录 item ID，并用 in-flight Future 合并并发目录初始化。
- 适合的并发数、429 / `Retry-After` / 5xx 退避策略。
- 连接验证是否应改成只读轻量检查，CAS 能力改由实现契约与自动化测试保证，而不是每次连接都写探针。

### 2. Google Drive

- 使用 Drive API v3 的隐藏 `appDataFolder`。
- 当前新 immutable object 通常执行：按名称 list → create → 再 list → download 回读校验。
- HEAD 的创建或更新也会再次 list 与 download。
- 后端目前未启用通用层已有的对象并发上传能力。
- 粗略分析：有 `N` 个新 record 时，完整上传约 `4N + 10` RTT；100 个 record 可超过 400 RTT。
- 拉取通常是 manifest 的 list/download，加上每个 object 的 list/download，仍是大量串行 RTT。

官方资料：

- 上传类型与阈值（simple / multipart 适合不超过 5 MB；resumable 多一次 HTTP 请求）：  
  https://developers.google.com/workspace/drive/api/guides/manage-uploads
- API 性能建议（partial response、`fields`、PATCH、batch）：  
  https://developers.google.com/workspace/drive/api/guides/performance
- `appDataFolder`：  
  https://developers.google.com/workspace/drive/api/guides/appdata
- Batch requests：  
  https://developers.google.com/workspace/drive/api/guides/performance#batch-requests

希望重点判断：

- 小于 4 MiB 且带 metadata 的对象是否应统一使用单请求 multipart upload。
- create / update 响应是否已足够提供 file ID、version、md5Checksum 等信息，从而删除上传后的重复 list。
- 能否一次列出 appDataFolder 中本 namespace 的索引，供一次 operation 内复用，而不是每个对象单独 list。
- media upload/download 无法放入普通 batch 时，metadata batch、并发 media 请求与 fields 裁剪如何组合。
- 适合的上传/下载并发数与 429/403 rateLimitExceeded 退避策略。

### 3. WebDAV

- 适配普通 WebDAV；坚果云因 `PUT If-None-Match: *` 实测仍可能覆盖，必须保持 `manualBackupOnly`。
- 当前对象存在检查、PUT、回读验证、目录 PROPFIND/MKCOL 等操作会形成大量请求。
- 100 个对象推送在部分路径上可能超过 300 次请求；坚果云存在请求频率限制，连接探测加上传可能接近额度。
- 不同 WebDAV 服务对 ETag、条件 PUT、MOVE、LOCK、Depth 与弱 ETag 的支持差异很大。

官方标准：

- WebDAV RFC 4918：  
  https://datatracker.ietf.org/doc/html/rfc4918
- HTTP Conditional Requests / ETag：  
  https://datatracker.ietf.org/doc/html/rfc7232
- HTTP Semantics（现行）：  
  https://datatracker.ietf.org/doc/html/rfc9110
- `Prefer: return=minimal` for WebDAV：  
  https://datatracker.ietf.org/doc/html/rfc8144
- WebDAV Sync Collections（仅评估历史/清单增量用途）：  
  https://datatracker.ietf.org/doc/html/rfc6578

希望重点判断：

- 如何用 `Depth: 0/1`、精确 property 集合、strong ETag 与条件请求减少 PROPFIND 和回读。
- 是否适合使用临时资源 + MOVE 原子发布；不同服务不支持时如何安全降级。
- 如何按“变化对象数”而不是“快照总对象数”上传。
- 哪些能力应在首次连接后缓存，哪些必须每次操作重新验证。
- 坚果云 manual-only 模式下哪些自动维护、条件删除或历史清理必须禁用。

### 4. GitHub

- 使用 GitHub REST Git Database API，将对象、manifest、HEAD 表示为仓库文件。
- 需要检查当前是否对每个文件单独创建 blob，以及 tree/commit/ref 更新是否已经合并为一次原子提交。
- GitHub 有 primary / secondary rate limit，过高并发可能触发 abuse/secondary throttling。
- 需要同时优化上传请求数、tree 读取、未变化 blob 复用、拉取 raw/blob 内容以及历史清理。

官方资料：

- Git Database API 指南：  
  https://docs.github.com/en/rest/guides/using-the-rest-api-to-interact-with-your-git-database
- Git blobs：  
  https://docs.github.com/en/rest/git/blobs
- Git trees：  
  https://docs.github.com/en/rest/git/trees
- Git commits：  
  https://docs.github.com/en/rest/git/commits
- Git refs：  
  https://docs.github.com/en/rest/git/refs
- REST rate limits：  
  https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api

希望重点判断：

- 如何复用未变化 blob SHA，只为变化对象创建 blob，再一次创建 tree、commit、更新 ref。
- 多个 create-blob 是否适合有限并发，合理并发数是多少。
- 拉取时如何只读一次 recursive tree 建索引，并避免每个对象重复查路径。
- 是否有比当前自写 HTTP 层更成熟、稳定的 Dart/GitHub SDK 值得使用。

## 通用本地流水线困境

无论后端是哪一种，目前准备与应用阶段还存在本地重复工作：

- `uploadLocal()` 已执行一次 `captureLocal()`，`stage()` 为 recovery 又执行一次完整 `captureLocal()`。
- 同一 snapshot 可能重复 decode。
- staging、fingerprint、run、apply、saveBase 会重复读取并 SHA-256 校验相同 payload。
- 资源按 chunk 读取并频繁 `flush: true` 写盘，移动设备上成本明显。
- 当前 object ID 绑定 `snapshotId + record index`；任何一条记录变化都会生成全新的 snapshotId，导致未变化 record 也不能跨快照复用，上传量按总对象数 `N` 而不是变化数 `C` 增长。
- snapshot uploader 按 record 串行准备 artifact；即使网络后端支持并发，准备阶段仍可能成为瓶颈。
- 拉取后 object 下载、decode、materialize、stage、apply、saveBase 之间存在重复磁盘 IO 和哈希。
- merge / restore 的预览目前只保留展示摘要，用户确认后可能再次完整 capture 或重新下载同一个 immutable snapshot。
- 子代理按当前读写路径粗算：大资源首次推送的本地磁盘 IO 可能达到有效数据量约 21.7 倍；100 MiB 资源可能触发约 2.17 GiB 本地读写。该估算需要 benchmark 复核，但足以说明并发网络请求不是唯一瓶颈。
- 目前进度阶段粒度较粗，用户只看到“准备中 / 上传中 / 拉取中 / 应用中”，难以判断慢在 CPU、磁盘、网络还是重试。

关键文件：

- `lib/core/cloud_sync/coordinator.dart`
- `lib/core/cloud_sync/sync_operation_runner.dart`
- `lib/core/cloud_sync/snapshot_uploader.dart`
- `lib/core/cloud_sync/snapshot_transfer.dart`
- `lib/data/cloud_sync/app_cloud_sync_data_source.dart`
- `lib/data/cloud_sync/cloud_sync_operation_storage.dart`

希望重点判断：

- 能否引入一次 operation 内复用的 `PreparedSnapshot` / verified artifact graph，使 capture、stage、fingerprint、upload、apply、saveBase 共享同一份已验证结果。
- 如何只读取/哈希每个 payload 一次，同时继续支持崩溃恢复、断点续传、response-lost 幂等与原子 apply。
- 如何识别未变化 record/object，直接复用上一 manifest 中的 immutable object，上传复杂度从总对象数 `N` 降为变化数 `C`。
- 是否应并行编码、哈希、上传和下载；Windows/macOS/Android 分别应怎样设置 CPU、磁盘与网络并发上限。
- 大资源是否应流式处理，避免整块进入内存；当前单 object 上限为 4 MiB。
- 如何设计 benchmark 与 telemetry，量化各阶段耗时、字节数、对象数、请求数、重试数、并发度和缓存命中率。

## 不可破坏的约束

1. 不减少、不截断备份数据。
2. 不备份任何凭据、token、密码、API key、缓存、索引、日志或设备专属状态。
3. 保留 SHA-256、大小校验、manifest/HEAD 身份校验和损坏显式失败。
4. 保留取消、崩溃恢复、断点续传、response-lost 幂等和 staging rollback。
5. 不用吞异常、模拟成功或静默降级掩盖问题。
6. 保存连接不触发上传、拉取或应用。
7. OneDrive / Google Drive 保持明文简单备份，不引入密钥流程。
8. 坚果云必须保持 `manualBackupOnly`，不得宣称强 CAS 或自动双向同步。
9. UI 功能和四种后端能力必须完整保留。
10. 优先复用官方 API、标准协议和成熟实现；若继续自写 HTTP，需要说明官方 SDK 不适用的具体原因。

## 希望 Grok 输出

请按以下结构给出建议：

1. **现状诊断校正**：上述判断哪些正确、哪些错误或缺少关键条件。
2. **各后端最优请求模型**：分别列出准备、上传、拉取、应用的理想请求/IO 序列。
3. **成熟方案调研**：官方 SDK、Dart package、同步库或已验证架构中有哪些可直接复用。
4. **统一架构**：通用层与后端特化层如何分工，避免四套重复逻辑。
5. **分阶段实施计划**：P0/P1/P2，每步说明收益、风险、依赖和回滚方式。
6. **量化目标**：以 1、10、100、1000 个 record 以及 1 MB、100 MB、1 GB 数据量给出请求数、预计内存、磁盘 IO 和并发目标。
7. **正确性证明**：每项优化应增加哪些 contract test、故障注入测试、benchmark 和真实服务验收。
8. **安全边界**：明确哪些优化不能做，以及原因。

请尽量引用官方文档中的具体 endpoint、header、限制和推荐值，并区分“官方明确保证”“经验建议”“需要真实服务验证”。
