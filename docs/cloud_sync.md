# 云备份协议与验证

本文维护当前代码的结构与不变量，OAuth 注册见 [cloud_drive_oauth.md](cloud_drive_oauth.md)。用户操作与数据选择边界见 [AGENTS.md](../AGENTS.md#云同步兼容性)。本文不记录历史迁移任务、某次机器的性能结果或真实服务通过状态。

## 代码入口

| 职责 | 入口 |
|---|---|
| 协议模型与限制 | [models.dart](../lib/core/cloud_sync/models.dart) |
| 同步协调、上传与下载 | [coordinator.dart](../lib/core/cloud_sync/coordinator.dart)、[snapshot_uploader.dart](../lib/core/cloud_sync/snapshot_uploader.dart)、[snapshot_transfer.dart](../lib/core/cloud_sync/snapshot_transfer.dart) |
| 小对象打包与上传产物 | [snapshot_object_packer.dart](../lib/core/cloud_sync/snapshot_object_packer.dart)、[snapshot_upload_plan.dart](../lib/core/cloud_sync/snapshot_upload_plan.dart) |
| 有界调度 | [bounded_transfer_scheduler.dart](../lib/core/cloud_sync/bounded_transfer_scheduler.dart) |
| 后端契约与四种实现 | [backend/](../lib/core/cloud_sync/backend/) |
| 本地准备与持久化 | [app_cloud_sync_data_source.dart](../lib/data/cloud_sync/app_cloud_sync_data_source.dart)、[verified_blob_store.dart](../lib/data/cloud_sync/verified_blob_store.dart) |
| 内容类型与适配器 | [content_selection.dart](../lib/core/cloud_sync/content_selection.dart)、[app_cloud_sync_adapters.dart](../lib/data/cloud_sync/app_cloud_sync_adapters.dart) |
| 业务入口与界面 | [providers/cloud_sync/](../lib/presentation/providers/cloud_sync/)、[screens/cloud_sync/](../lib/presentation/screens/cloud_sync/) |
| 回归测试 | [test/core/cloud_sync/](../test/core/cloud_sync/)、[test/data/cloud_sync/](../test/data/cloud_sync/) |

## 协议与数据身份

远端 namespace 内使用 `HEAD.json`、`snapshots/<snapshotId>.json` 和 `objects/<sha256>`。对象保存明文 payload，内容 SHA-256 是对象身份；manifest 保存记录身份与对象引用，HEAD 是可变的快照入口。

当前写入 schema 3，继续读取 schema 2 的 HEAD 和 manifest，namespace 不变。schema 3 的 `packs` 将一个传输对象映射到按顺序拼接的记录 payload SHA-256 列表；每个成员的长度仍来自原始记录引用。小于等于 64 KiB 的文本/元数据对象按约 1 MiB 分包，单个二进制资源和大记录继续独立传输。打包只减少网络对象数，不改变记录 ID、删除标记、内容 SHA-256 或逐条合并语义，也不增加总备份大小上限。

- 下载先校验完整对象，再按声明长度拆分并逐个校验成员；重复引用、未知成员、错误长度或哈希不匹配必须报错。
- 未完成上传复用已经持久化的 manifest 与分包顺序；schema 2 未完成上传继续提交 schema 2 HEAD，不在恢复过程中切换格式。
- 历史对象与快照不会因升级自动删除、迁移或重写。新版可拉取和恢复旧备份；旧客户端不支持 schema 3 新备份，跨设备使用新备份前需更新客户端。

- 发布顺序为不可变 objects → immutable manifest → HEAD。条件提交冲突必须显式处理，不能令 HEAD 指向不完整快照。
- manifest/HEAD 按当前模型严格解析；损坏、缺失或不匹配的对象必须在应用前报错。
- 不同记录和快照可以复用相同内容；tombstone 不需要创建空 payload 对象。
- 单对象上限与传输并发是内存/协议约束，不是备份总量上限。大数据应按协议分块，不能静默跳过用户选择的内容。
- 格式或 namespace 变化须评估已有发布数据；不得未经授权删除旧 namespace，也不得恢复未发布的加密、KEY 或双写分支。

## 本地准备、预览与恢复

本地使用 verified blob store 与持久化 descriptor 保存对象引用。准备、上传、预览、应用与恢复应复用已校验的产物，避免重复复制完整 payload。

- 来源写入先经过临时文件、大小与 SHA-256 校验，再发布可引用对象；半成品不能标为 READY。
- 进程内可复用已验证句柄；跨进程重建引用后在实际读取时验证内容。文件大小、mtime、provider eTag 或 MD5 不能代替协议 SHA-256。
- 预览确认前复核本地状态与远端 HEAD；变化时报告预览过期，不能用旧结果覆盖新数据。
- 应用前完成 preflight、恢复数据与 journal 的持久化；中断后按实际 journal 恢复，不能把异常吞掉后继续宣布成功。
- 本地对象回收必须尊重 base、operation、recovery 和 preview 引用。引用损坏须报错，不能把无法解析的对象当作未引用对象删除。

## 传输与后端能力

当前调度默认 Android 2 路/16 MiB 在途 payload，桌面 4 路/32 MiB；更保守的后端限制仍需遵守。暂停/取消阻止新任务，manifest/HEAD 的提交顺序保持串行。

| 后端 | 维护约束 |
|---|---|
| OneDrive | 已有目录先只读解析，缺失时按明确的 fail 冲突语义创建并处理并发创建；复用分页 inventory；HEAD 保持条件更新，模糊响应读回校验 |
| Google Drive | 授权审核未通过，新增连接入口暂时禁用；保留已保存连接、备份读取和后端实现。保持 `manualBackupOnly`，不把 version/headRevisionId 当作强 CAS |
| GitHub | 读取固定 commit/tree；对象通过 Git Database API 组织，tree/commit/ref 一次发布，禁止逐文件 Contents API 替代原子提交 |
| WebDAV | 根据实际 ETag/条件写能力决定模式；能力不足保持手动备份；坚果云单并发，不自动合并或恢复历史 |
| WebDAV 远端维护 | 不执行自动 GC；缺少可证明安全的删除协调时不能猜测共享对象已无引用 |

重试须区分不可变对象与可变提交；429、Retry-After、响应丢失、409/412 等保留原始错误与上下文。不能盲目重放 HEAD 提交。

保存连接仅保存并验证配置，不自动上传、下载、恢复或续跑待处理操作。OAuth/账户凭据和设备专属状态不进备份；本地图库图像字节不参与云备份。

启动时立即开始恢复已保存连接，账号信息先于网络校验显示，首次恢复期间不显示重复登录入口；无已保存连接时不得重建正在编辑的设置表单。已连接时的前台刷新保留 Dashboard，首次恢复只读取一次 HEAD，成功后清除先前失败状态。自动上传、自动拉取仍未启用。

手动操作遇到已开始的前台连接检查时，等待该检查结束后继续，不把后台检查误报为重复同步；等待期间拒绝重复手动提交，检查失败保留原始错误。取消或断开连接后不得启动尚在等待的备份。

## 验证方式

日常修改优先运行受影响测试；下面的目录用于限定云同步范围：

~~~powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1 -Path "lib/core/cloud_sync,lib/data/cloud_sync,lib/presentation/providers/cloud_sync,lib/presentation/screens/cloud_sync"
~~~

协议、并发、恢复或性能变化时使用有总时限的基准入口：

~~~powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run_cloud_sync_benchmark.ps1
~~~

该脚本默认包含 production 1 GiB round trip、补充 N/C 场景、provider contract 和进程内存采样，最多 600 秒。报告默认写入 `tool/.tmp/cloud-sync-benchmark/report.json`，不提交；不要为纯文档修改默认执行该基准。

判断结果时区分：

- **逻辑指标**：对象复用、source open/hash 次数、网络/磁盘字节、请求数、在途预算。
- **进程指标**：实际 WorkingSet/RSS、峰值及采样范围；不能用调度器预留字节替代。
- **测试后端**：fake provider 和 loopback 证明其断言覆盖的协议行为，不证明公网服务的延迟、配额或账号兼容性。
- **真实服务**：按用户已明确授权的范围在隔离目标验证，记录账号类型、服务版本、场景、请求与结果；历史文档中的授权描述或通过结论不构成本次执行证据。

本地化变化后重新生成 ARB 输出并运行相关本地化测试；UI 自动化按 [运行验收技能](../.agents/skills/aaalice-runtime-verify/SKILL.md) 执行。所有检查仅报告本次实际结果。
