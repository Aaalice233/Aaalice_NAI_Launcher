# 云同步全链路性能优化实施计划

## 目标

彻底优化 OneDrive、Google Drive、WebDAV/坚果云和 GitHub 的准备、上传、拉取、预览确认、应用和恢复流程，同时保持完整性、显式推送/拉取、凭据排除、条件提交、崩溃恢复和 manual-only 边界。

本计划基于当前分支代码、测试、Git 历史、`E:/Download/cloud_sync_performance_plan.md`、Microsoft Graph / Google Drive / GitHub / WebDAV 官方资料及四个专项子代理复审，不直接照搬 Grok 方案。

## 实施结果

- 共享流水线已切换为明文 SHA-256 内容寻址对象、strict manifest/HEAD、引用型 staging/base/recovery 和本地 verified blob store；旧 JSON/base64 object、加密、KEY、双写和兼容分支未保留。
- 上传先做一次远端 inventory，再按变化对象 `C` 传输；跨进程首次复用会实际读取并校验远端 SHA-256，同一进程仅在 provider revision 变化时复验；下载优先复用本机已验证 CAS，preview 确认复用持久 prepared intent，不重复下载对象。
- 对象传输统一经过对象数与字节双重背压；桌面默认 4 路/32 MiB，Android 默认 2 路/16 MiB，坚果云固定单路。
- OneDrive、Google Drive、WebDAV 和 GitHub 已分别完成目录/index、分页、immutable write、条件 HEAD、pinned tree/raw blob 及 provider 限流优化；Google Drive 与坚果云保持 `manualBackupOnly`。
- WebDAV 服务无法提供可跨服务证明安全的删除锁，因此已彻底移除远端自动 GC，而不是保留不可达的假安全维护代码；新 namespace 不会删除旧 namespace 数据。
- 本地 CAS 启动维护只删除超过 7 天且不被 base、operation、recovery、preview 引用的对象和临时文件；损坏引用按 `CloudFormatException` 失败，并且 recovery rollback 不会被损坏 target 阻断。
- benchmark 采用公式门槛而非机器耗时门槛。最近一次默认运行验证 `N=1000,C=0` 为 0 个 object upload / 3 个逻辑后端调用，`N=1000,C=1` 为 1 个 object upload / 4 个逻辑后端调用；100 MiB 场景峰值在途 payload 为 16 MiB。报告写入 `tool/.tmp/cloud-sync-benchmark/report.json`，不提交。
- 真实服务写探针仍只在用户提供隔离账号并显式授权后执行；日常验证由共享 contract、provider fake API、loopback HTTP、故障注入和 benchmark 覆盖，不会擅自写入用户云盘。

## 已确认的根因

1. `stage()` 会再次 `captureLocal()`，一次操作重复扫描业务数据。
2. staging、recovery、base、upload artifact 之间反复复制、解码、哈希、flush 和重读。
3. 对象 ID 使用 `<snapshotId>.<index>`，任何变化都会令全部对象成为“新对象”，上传复杂度只能是 `N`，无法降为变化数 `C`。
4. 下载严格串行，上传只有 WebDAV 开启四路并发；并发还没有统一字节预算。
5. OneDrive 每个对象重复解析目录、查询 metadata、创建 upload session。
6. Google Drive 每个对象重复 list、create、再次 list、下载回读。
7. GitHub 已使用 tree/commit/ref 原子提交，但仍逐路径 Contents 查询，未建立 pinned tree inventory。
8. WebDAV 保存连接执行写探针；manual-only 后端仍可能进入自动 GC。
9. merge/restore preview 确认时重新 capture、重新读取 HEAD、重新下载对象。
10. 上传完成后同步加载历史，额外阻塞主操作。
11. 没有统一的请求、IO、哈希、flush、并发、重试和对象复用指标。

## 对 Grok 方案的关键修订

- “P0 不改数据模型即可按 C 上传”不成立；必须先改变对象身份和 GC。
- OneDrive simple `PUT /content` 官方只保证创建或替换，不保证 create-only/CAS；生产默认继续使用有明确冲突语义的 upload session，除非 Personal 与 Business 真实探针及后续官方契约同时支持。
- Google `version/headRevisionId` 不是强 CAS，Google Drive继续 `manualBackupOnly`。
- 返回的 size、MD5 或 eTag 不能冒充远端 SHA-256；协议 SHA-256 校验始终保留。
- sidecar 不能替代跨进程恢复后的首次实际内容校验。
- staging 使用 CAS 引用，不依赖跨平台硬链接。
- 保存连接只能做轻量只读验证；WebDAV 写/CAS 能力只能在独立显式探针或首次显式上传中判定。
- GitHub 已有 Git Database 原子提交，不重写为 Contents API；重点是 tree inventory、raw blob、inline tree batching和限流。
- 坚果云不使用全量 inventory、并发固定 1、保持 manual-only、禁止自动 GC。

## 协议与兼容边界

### 新协议

启用新的明文内容寻址 namespace，旧 namespace 保持原样且不被新 GC 扫描：

```text
<namespace-v3>/
├── HEAD.json
├── snapshots/<snapshotId>.json
└── objects/<sha256>
```

- object 内容为原始 payload bytes，不再使用 JSON/base64 包装；逻辑键统一为完整 SHA-256。当前 provider inventory 使用扁平 object 键，避免 Google Drive/OneDrive 为前缀目录额外创建和遍历文件夹。
- `objectId = sha256(payload bytes)`。
- manifest 保存 `recordId/kind/binary/deleted/objectId/size`，记录逻辑身份和对象内容身份。
- tombstone 不创建空对象。
- manifest 使用确定性编码；records 按逻辑 ID 排序。
- HEAD 是唯一可变入口；顺序固定为 objects → immutable manifest → conditional HEAD。
- 相同内容可被不同记录及不同 snapshot 安全复用。

### 旧数据处理

- 不恢复 KEY、加密、解密、recovery key、旧 codec 或双写分支。
- GitHub/WebDAV 已在 `v3.1.0` 发布，因此旧 namespace 不删除、不覆盖、不参与新 GC。
- 新实现不在主流水线长期维护两套协议；检测到旧 namespace 时仅提示用户显式创建新格式备份。
- OneDrive/Google Drive 当前分支尚未发布的中间布局不做迁移。

## 目标架构

### 1. Verified object store

本地建立内容寻址对象存储：

```text
cloud-sync/
├── objects/<prefix>/<sha256>
├── base/generations/<generation>/index.json
├── staging|recovery|base-recovery/<operationId>/generations/...
├── upload/<operationId>/...
└── previews/sync|restore/.../generations/...
```

规则：

- 来源流只读取一次，边写 `.part` 边累计 size/SHA-256，成功后原子 rename。
- operation/base/preview 只保存对象引用，不复制 payload。
- 同进程复用 verified handle；重启后从 descriptor 重建引用，并在实际读取时复核对象大小与 SHA-256。
- 本地 GC 标记 base、pending operation、preview 引用；只删除超过 grace period 的未引用对象。
- 不依赖 hardlink，不构造全量数据 `Uint8List`。

### 2. Prepared operation

prepared operation 持有：

- 记录 descriptor 与本地 CAS 引用；
- 持久化的 canonical manifest bytes/hash；
- 预期 HEAD revision 与 journal checkpoint；
- target、recovery、base-recovery 的 durable generation handle。

上传器、apply 和 recovery 统一消费该 handle；merge/restore preview 另存 durable descriptor，并在确认时复核本地完整快照与远端 HEAD，避免重新下载。

### 3. 流式传输和中央调度

单个协议对象硬限制为 4 MiB；来源进入本地 CAS 时单次读取并校验，远端传输按对象调度：

- Android：默认上传/下载 2 路，总在途 payload 不超过 16 MiB。
- Windows/macOS：默认 4 路，总在途 payload 不超过 32 MiB。
- GitHub mutation、坚果云使用更保守的 provider policy。
- 同时限制对象数和总字节数，不对全列表直接 `Future.wait`。
- pause/cancel 阻止新任务；在途 immutable 请求允许安全结束。
- manifest 和 HEAD 始终串行提交。

### 4. 预览与应用

- merge/restore preview 生成 durable prepared handle。
- 确认前复核 remote HEAD、scope/account 和 adapter revision；未变化则零重新下载。
- apply 前完成完整 graph 校验、adapter preflight、target/recovery READY 和 journal 落盘。
- apply 后 base 仅原子替换引用 manifest，不再复制 payload。
- 崩溃恢复按 journal 恢复 recovery，再重放 target。

## 分阶段任务

### Phase 0：基准、安全边界和测试基础设施

1. 建立脱敏 request/IO/hash/flush/concurrency 指标和 fake clock/sleeper/jitter。
2. 建立四后端共享 contract suite、故障注入存储和请求记录器。
3. 修复 maintenance policy：manual-only、未知 capability、坚果云禁止自动 GC。
4. 保存 OneDrive/WebDAV 连接改为只读轻量检查；不创建业务目录、probe、object、manifest 或 HEAD。
5. 移除上传成功后的 eager history 加载，历史改为进入页面或手动刷新时加载。

完成标准：现状请求预算可重复测量；保存连接零业务写入；manual-only 自动维护调用数为 0。

### Phase 1：Verified store 与单次准备

1. 实现流式 CAS put/open/verify、原子 `.part` 提交和安全本地 GC。
2. staging、recovery、base 改为引用型 descriptor。
3. `captureLocal()` 每次操作最多执行一次；删除 `stage()` 内第二次 capture。
4. 去除逐 chunk `flush: true`，只在 durable checkpoint 执行必要 flush。
5. response-lost 重试复用同一 prepared bytes，不重新 capture/编码。

完成标准：每个新 payload 来源读取与 SHA-256 各一次；staging/saveBase payload 复制为 0；故障后没有伪 READY 半成品。

### Phase 2：内容寻址协议与安全 GC

1. 定义 strict manifest/head v2 和新的 namespace。
2. payload 直接作为 object，移除 `CloudObjectCodec` 与 record JSON/base64 transport。
3. object ID 改为 SHA-256；base 持久化 record→object 映射。
4. `N=1000,C=1` 时仅准备/上传一个变化 object。
5. WebDAV 远端自动 GC 因缺少可跨服务证明安全的删除锁而移除；新 namespace 不触碰旧数据。
6. GitHub namespace 删除随单一原子 tree commit 发布，不逐项暴露半删除状态。

完成标准：共享对象不会被误删；旧 namespace 不受影响；HEAD 永不指向不完整 snapshot。

### Phase 3：流式 API、并发、重试和背压

1. `BackendHttp` 统一限制响应体、记录请求指标，并按请求幂等性分类重试。
2. 引入 object worker queue 与加权 byte semaphore。
3. 统一 429/403 rate limit、Retry-After、指数退避和 full jitter。
4. response-lost、409/412、5xx 按请求幂等性分类，禁止盲目重放 mutable commit。
5. 下载从串行改为有界并发，校验失败时不进入 apply。

完成标准：内存随并发预算而非总数据量增长；取消后不启动新对象；HEAD/manifest 保持串行。

### Phase 4：OneDrive 与 Google Drive

OneDrive：

- approot、namespace、objects、snapshots item ID 使用 singleflight 缓存；404 只失效重建一次。
- 去掉逐对象目录确认和预 metadata GET。
- immutable object/manifest 使用 conflictBehavior=fail 的 upload session；冲突或模糊响应才读回核验。
- HEAD 保留精确 `If-Match` 条件提交。
- snapshots/objects 各建立一次 operation-scoped 分页 index。
- simple PUT 仅保留独立 Personal/Business contract probe，不默认启用。

Google Drive：

- operation 开始一次分页建立 appDataFolder index，写成功后原地更新。
- create/update 直接解析响应字段，不再正常路径二次 list。
- 使用 provider checksum 作为上传确认辅助；协议 SHA-256仍用于对象身份和读取验证。
- duplicate/字段缺失/校验异常才回读。
- 保持 manual-only，不把 version/headRevisionId 宣称为 CAS。

完成标准：请求数从逐对象多次查询降为 index 分页 + C 次对象写 + manifest/HEAD 常数开销。

### Phase 5：WebDAV/坚果云与 GitHub

WebDAV：

- collection ensure singleflight；PROPFIND 使用精确属性，不再 `allprop`。
- 标准强 CAS 服务按 C 个 hash 条件 PUT；412 时仅核验碰撞对象。
- 坚果云固定 manual-only、并发 1、GET→PUT→GET/hash、禁用 GC/自动合并/历史恢复。
- 未显式验证强 ETag/CAS 的通用 WebDAV 保守降级。

GitHub：

- 一次固定 ref/commit/tree，建立 pinned operation inventory。
- 所有读取固定 commit SHA；raw Git Blob 下载，不使用过期 download URL。
- 未变化 hash 复用 blob SHA。
- 变化对象使用 Git Blob API 创建 blob，随后统一写入一次 tree/commit/ref 发布；不使用逐路径 Contents API。
- 一次 commit、一次 `force=false` ref update；expected revision 同时校验 branch commit。
- 遵守 primary/secondary rate limits 和完整 Retry-After。

完成标准：GitHub 不再逐路径 Contents GET；标准 WebDAV 为 `C+常数`；坚果云不超额并发或自动维护。

### Phase 6：preview、apply、进度和本地化

1. merge/restore preview 确认复用 prepared handle。
2. 确认时重新捕获本地完整快照并复核远端 HEAD；任一变化都明确判定 preview stale。
3. apply 采用“完整预检→资源预写→短事务提交→引用型 saveBase”。
4. 进度细分 scanning/hashing/reusing/uploading/committing/downloading/verifying/applying/saving/retry waiting。
5. UI 主区域保持简洁，只显示阶段、字节、对象与复用量；详细指标放可展开详情。
6. 同步中/繁中/英/日文案；core 错误改为稳定 code，由 UI 本地化。
7. 修正 README 中已过时的端到端加密/恢复密钥描述及 OAuth/性能文档。

完成标准：preview→confirm 额外远端对象下载为 0；大数字和窄屏无 overflow；英文/日文界面不出现硬编码中文。

### Phase 7：验证、benchmark 与真实服务验收

确定性测试：

- N=`1/10/100/1000`，C=`0/1/10/N`。
- payload open/hash/write/flush 次数。
- 1 MiB/100 MiB/1 GiB descriptor 场景内存预算。
- 429、Google 403 rate limit、Retry-After、5xx、response-lost、409/412、截断响应、part 残留、apply 中断和 rollback 路径。
- save 连接零业务写；manual-only 零自动维护。
- 共享对象 GC、损坏/截断 inventory 零删除。
- token、密码、API key、完整 URL query 和业务内容不进入日志、CAS 或 manifest。

Benchmark：

- 新增 `tool/cloud_sync/cloud_sync_benchmark.dart` 和有总时限的 PowerShell 入口。
- 输出到 `tool/.tmp/cloud-sync-benchmark/`，不提交产物。
- CI 只断言请求/IO/内存公式，不用绝对毫秒门槛。

真实服务：

- 专用隔离 namespace/测试仓库；用户显式授权后执行写入。
- OneDrive Personal/Business、Google personal/Workspace、GitHub private repo、标准 WebDAV、坚果云。
- 验证请求预算、分页、duplicate、stale HEAD、条件写、response fields 和抽样 SHA-256。
- 不通过故意轰击真实 API 测试 rate limit。

#### 真实服务验收状态矩阵

下表只记录实际授权与执行证据；fake、loopback 和 contract test 不能冒充真实服务结果。当前会话没有收到任何隔离账号、仓库、服务地址或写授权，因此所有真实服务验收均未执行。

| target_id | 服务/账号类型 | authorization_status | execution_status | executed_at_utc | isolated_target | live_evidence | blocker | fake_contract_coverage | live_only_gaps |
|---|---|---|---|---|---|---|---|---|---|
| `onedrive_personal` | OneDrive Personal | `not_provided` | `not_run` | — | — | 无——不得推断 | 未提供隔离账号及显式写授权 | `onedrive_cloud_sync_backend_test.dart`、shared backend contract | 真实 `approot`、upload session、分页和冲突响应 |
| `onedrive_business` | OneDrive Business | `not_provided` | `not_run` | — | — | 无——不得推断 | 未提供 Business tenant 隔离账号及显式写授权 | 同上；fake 不区分 Personal/Business | tenant 策略及响应字段差异 |
| `google_personal` | Google personal | `not_provided` | `not_run` | — | — | 无——不得推断 | 未提供隔离账号及显式写授权 | `google_drive_cloud_sync_backend_test.dart`、shared backend contract | 真实 `appDataFolder`、duplicate、配额和响应字段 |
| `google_workspace` | Google Workspace | `not_provided` | `not_run` | — | — | 无——不得推断 | 未提供 Workspace 隔离账号及显式写授权 | 同上；fake 不覆盖 Workspace 策略 | Workspace 管理策略和配额差异 |
| `github_private` | GitHub private repo | `not_provided` | `not_run` | — | — | 无——不得推断 | 未提供专用 private repo/token 及显式写授权 | `github_cloud_sync_backend_test.dart`、`github_fake_api.dart`、shared backend contract | private repo 权限、真实 tree/commit/ref 与 secondary limit |
| `webdav_standard` | 标准 WebDAV | `not_provided` | `not_run` | — | — | 无——不得推断 | 未指定真实服务产品/版本和隔离目录 | `webdav_cloud_sync_backend_test.dart`、`webdav_security_test.dart`、shared backend contract | 具体服务的 strong ETag、条件 PUT、PROPFIND/MOVE 差异 |
| `jianguoyun` | 坚果云 WebDAV | `not_provided` | `not_run` | — | — | 无——不得推断 | 未提供隔离账号及显式写授权 | WebDAV manual-only/no-ETag、单并发与安全边界测试 | 真实覆盖语义和限频；既有 manual-only 结论不算本轮执行证据 |

## 性能验收指标

| 场景 | 目标 |
|---|---|
| `N=1000,C=0` push | object 上传 0；只允许 index/manifest/HEAD 常数开销 |
| `N=1000,C=1` push | 新 object 上传 1；其余 999 个引用复用 |
| 首次 prepare | 每个 payload 来源读取和 SHA-256 各最多一次 |
| stage/saveBase | payload 复制 0 |
| pull | 每个缺失 object 下载写 CAS 一次，apply 读取一次 |
| preview→confirm | 额外远端 object 下载 0 |
| Android | 默认 in-flight payload ≤16 MiB |
| Desktop | 默认 in-flight payload ≤32 MiB |
| GitHub | 无逐对象 Contents GET；一次 commit/ref 发布 |
| WebDAV manual-only | 自动 GC/合并/历史恢复请求 0 |

若 adapter 没有可靠 revision，首次准备仍允许读取来源以判断变化；不得通过 mtime/size 猜测内容未变。指标不承诺无法证明的“未变化对象零源读取”。

## 已实现与实测结果

- 生产路径已统一为明文 `manifest/object/HEAD` 协议；本地准备使用内容寻址 blob 与 generation descriptor，push、pull、preview、apply 和 crash recovery 共用同一组校验过的产物，不保留未发布加密格式、旧 uploader 或双写路径。
- 上传先批量发现缺失 object，再以按字节和任务数双重限流的调度器传输；首次复用远端对象必须读取并校验 SHA-256，随后以 provider revision 缓存避免同一进程重复下载，revision 变化立即复验。CAS capture 的已验证摘要通过 backend contract 传给四个 provider，正常上传不再重复执行 SHA-256；provider 内部的 payload/远端内容 SHA-256 也纳入 telemetry（连接 namespace 等常量摘要不计为 payload pass）。OneDrive 使用固定 namespace 的单次 children inventory，Google Drive 使用 operation-scoped 分页 protocol inventory（同一操作最多一次完整索引）并直接复用含 size、MD5 和 revision 的 create/update 响应，GitHub 以 Git Database API 的单次 tree/commit/ref 发布，WebDAV 根据真实条件写探测严格降级。
- 实时 UI 展示准备、扫描、哈希、上传/下载、校验、应用、提交和保存阶段与对象/字节进度；操作完成后展示脱敏 request、网络字节、本地 I/O、hash、flush 和阶段耗时。
- `scripts/run_cloud_sync_benchmark.ps1` 默认且强制执行 1 GiB production round trip：真实经过 `AppCloudSyncDataSource`、`VerifiedBlobStore`、`SyncCoordinator`/`ResumableSnapshotUploader`、磁盘远端、`CloudSnapshotTransfer`、materialize、stage、apply 与 saveBase，并重建 data source 回读持久 base。一次性 source 第二次打开会直接失败；报告门禁要求 source 只打开一次，capture 和 materialize 的 SHA-256 pass 数分别等于实际新 payload 数，上传、下载和应用字节均至少 1 GiB。旧 synthetic N/C 和调度器场景只作为补充 contract 并合并到主报告，不再作为生产路径或哈希证明。
- 脚本先 AOT 编译 benchmark，再由父 PowerShell 每 10 ms 采样实际客户端进程 `WorkingSet64`，记录 baseline、peak 和 delta；逻辑 in-flight 16/32 MiB 门槛与真实进程峰值分开报告，禁止用调度器预留量冒充进程内存。512 MiB delta 是发现意外整文件缓冲的回归门禁，不等同于调度器 payload 预算。
- 四个 production provider class 通过 fake Dio adapter 执行协议与 base64/JSON contract，`BackendHttp` 另经真实 loopback socket 测试；脚本记录包含 test runner 开销的整个 contract suite 进程树峰值，不能归因于单个 provider。测试覆盖分页、重复项、限流/重试、条件写、immutable 校验、GitHub 单 commit 发布、WebDAV manual-only、恢复与垃圾回收边界，但不表述为公网 provider HTTP、延迟、单 provider 内存或真实服务验收。报告写入 `tool/.tmp/cloud-sync-benchmark/report.json`，普通单测只写独立 synthetic 文件，不会覆盖 production 报告；临时产物不提交。

## 最终验证命令

开发中优先：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1 -Path "lib/core/cloud_sync,lib/data/cloud_sync,lib/presentation/providers/cloud_sync,lib/presentation/screens/cloud_sync" -Include "test/core/cloud_sync,test/data/cloud_sync,test/presentation/providers/cloud_sync_application_service_test.dart,test/presentation/screens/cloud_sync" -TimeoutSeconds 120
```

本地化变更后：

```powershell
flutter gen-l10n
flutter test test/l10n/i18n_regression_test.dart
```

Benchmark（默认包含 production 1 GiB 全链路、N/C 矩阵、四 provider contract 和 OS 进程峰值采样，总时限固定不超过 600 秒）：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run_cloud_sync_benchmark.ps1
```

最终：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_flutter_sources.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run_flutter_tests.ps1
flutter analyze
```

纯 Dart 重构不默认构建全平台；仅依赖、插件、原生 OAuth 配置变化时构建对应平台。

## 完成定义

- 所有阶段实现完成，不保留旧加密、旧 uploader、双写或永久 feature flag。
- 四后端共享同一内容选择、manifest/object、安全和恢复协议，只在 capability 层采用 provider 特化。
- 准备、上传、拉取、preview、apply 和 recovery 均达到上述定量门槛。
- 针对性测试、全量测试、analyze 和 diff 检查通过；环境或真实凭据导致无法执行的项目明确记录。
- 文档、本地化、错误语义和 UI 进度同步完成。
