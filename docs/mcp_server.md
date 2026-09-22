# 外部智能体接入（MCP 服务）

启动器可以在本机开一个 MCP 服务器，让 Claude Code、Codex CLI、Cursor、Cherry Studio、Pi、Claude Desktop 等外部智能体通过与内置智能代理同一套工具层操作应用。本文面向要接入或维护这条链路的人。

本文与 [MCP 调试](mcp_debugging.md) 方向相反：那篇把 Dart/Flutter 官方 MCP server 接给 Codex 用于调试本项目，本篇是启动器自身作为 MCP 服务器对外提供工具。

## 概述与平台范围

- 仅 Windows 与 macOS 提供。能力开关是 `PlatformCapabilities.supportsMcpServer`，取值等同 `isDesktop`；Android 不启动服务器，设置里也不渲染该面板。
- 默认关闭，必须由用户在设置中启用。启用后只监听 `127.0.0.1`，不接受局域网或外部连接。
- 外部客户端拥有独立的权限模式和独立的审计日志，与聊天代理的设置互不影响。
- 所有需要授权的调用都在启动器窗口内裁决；任何可能消耗 Anlas 的操作都要用户在应用内确认。

## 快速开始

1. 打开“设置 → 集成 → MCP”，启用 MCP 服务器，确认状态为监听中。
2. 在“接入令牌”处复制令牌，或直接复制对应客户端的配置片段。
3. 按下面的片段配置客户端，重启客户端后确认工具列表出现 `nai-launcher`。

客户端配置区最上方是推荐做法：复制那段提示词发给要接入的智能体，由它调用随包 CLI 取得配置并写入自己的配置文件。提示词不写客户端名（智能体自己知道宿主，名单由 `print-config` 不带参数时给出），也不含令牌——令牌由 CLI 在本机从发现文件读取，不会进入模型上下文。智能体无法执行命令时再用下列手工片段。

下列片段与 CLI `nai_launcher_mcp print-config <client>` 的输出一致：`<token>` 替换为实际令牌，端口按实际配置替换。

```bash
# Claude Code
claude mcp add --transport http nai-launcher http://127.0.0.1:20624/mcp --header "Authorization: Bearer <token>"
```

```bash
# Codex CLI：命令注册端点，令牌从环境变量读取
codex mcp add nai-launcher --url http://127.0.0.1:20624/mcp --bearer-token-env-var NAI_LAUNCHER_MCP_TOKEN
NAI_LAUNCHER_MCP_TOKEN=<token>
```

```json
// Cursor：~/.cursor/mcp.json
{
  "mcpServers": {
    "nai-launcher": {
      "url": "http://127.0.0.1:20624/mcp",
      "headers": {
        "Authorization": "Bearer <token>"
      }
    }
  }
}
```

```json
// Cherry Studio：MCP 服务器设置里“从 JSON 导入”，类型为 Streamable HTTP 而不是 SSE
// timeout 单位为秒，取值大于应用内审批超时，避免用户还没点确认就先判超时
{
  "mcpServers": {
    "nai-launcher": {
      "name": "NAI Launcher",
      "type": "streamableHttp",
      "baseUrl": "http://127.0.0.1:20624/mcp",
      "headers": {
        "Authorization": "Bearer <token>"
      },
      "timeout": 600
    }
  }
}
```

```json
// Pi：~/.pi/agent/mcp.json，需先安装 pi-mcp-adapter 包，Pi 本体不含 MCP
// auth 必须显式写 bearer：留空时 adapter 会把 401 的 WWW-Authenticate 当作 OAuth 提示转去走发现流程
// 不要写 protocolVersion：默认 legacy 对应 2026 前修订，与启动器实现的 2025-11-25 一致
{
  "mcpServers": {
    "nai-launcher": {
      "url": "http://127.0.0.1:20624/mcp",
      "auth": "bearer",
      "bearerToken": "<token>",
      "requestTimeoutMs": 600000
    }
  }
}
```

```json
// Claude Desktop：claude_desktop_config.json，走随包 stdio 代理，不需要填令牌
// command 填代理的绝对路径，设置页的复制按钮会填入本机实际路径
{
  "mcpServers": {
    "nai-launcher": {
      "command": "C:\\Users\\<user>\\AppData\\Local\\Programs\\Aaalice NAI Launcher\\nai_launcher_mcp.exe"
    }
  }
}
```

注意事项：

- 地址统一写 `127.0.0.1`，不要写 `localhost`，避免客户端先解析到 IPv6 回环而连不上。
- 审批在启动器窗口内完成，一次调用可能挂起几分钟。把客户端的工具超时调高（Codex 的 `tool_timeout_sec`、Claude Code 的 `MCP_TOOL_TIMEOUT`），否则客户端会在用户点确认之前先判超时。
- 令牌长期有效，只有用户点“重新生成令牌”才更换；更换后所有客户端配置都要同步更新。
- Pi 片段把令牌明文写进 `mcp.json`，与 Cursor、Cherry Studio 一致。要避免明文可改用 adapter 的 `bearerTokenEnv`（从环境变量读）或 `bearerTokenStore`（存进系统凭据库，需另跑一次 adapter 命令写入）。

## 端点与协议

MCP 协议端点为 `http://127.0.0.1:<port>/mcp`，默认端口 `20624`（`McpServerDefaults.port`），可在设置中改为 `1024`–`65535`。传输为 Streamable HTTP，按 MCP `2025-11-25` 修订的语义实现，协议层使用 `package:dart_mcp` 0.5.2。同端口的 `/mcp/images/<随机凭证>.<扩展名>` 只提供已准备图片的短期 GET/HEAD 展示，不处理 MCP 消息。

请求约定：

| 项目 | 约定 |
| --- | --- |
| 方法 | `POST` 发送消息，`DELETE` 结束会话；其他方法返回 `405` 并带 `Allow: POST, DELETE` |
| 请求体 | 一次一条 JSON-RPC 消息；JSON-RPC 批量数组返回 `400` |
| `Content-Type` | 必须是 `application/json`，否则 `415` |
| `Accept` | 含 `text/event-stream` 时请求走 SSE，否则返回 `application/json` |
| `Authorization` | 每个请求都必须带 `Bearer <token>`，否则 `401` |
| `Mcp-Session-Id` | `initialize` 之外的请求都必须带；未知会话返回 `404` |
| `MCP-Protocol-Version` | 可选；带了就校验，无法识别的版本返回 `400` |
| 请求体上限 | 8 MiB，超出返回 `413` |

消息流转：

- `initialize` 会新建会话，响应头返回 `Mcp-Session-Id`，后续所有请求都要带上。会话失效后需要重新 `initialize`；随包 stdio 代理收到明确的 `404 / -32001 / Session not found` 时自动重新握手，只重试这笔尚未执行的请求一次。普通 404、超时、断流和其它结果未知的错误不会重放，避免重复计费。
- 通知和响应返回 `202`，不带响应体。
- 请求在 SSE 模式下以 `event: message` 逐条下发，等待期间每 15 秒写一条 `: keep-alive` 注释；目标响应写出后连接即关闭。
- 每条 SSE 流只承载该请求自己的响应，以及 `_meta.progressToken` 与之匹配的 `notifications/progress`；同一会话的并发请求互不串流。不提供 GET 流，其它服务端主动消息会被丢弃。
- `notifications/cancelled` 会中止对应的在途 `tools/call`；SSE 期间客户端断开连接同样中止该调用。
- `DELETE` 带会话头结束该会话并返回 `200`，未知会话返回 `404`。
- `tools/call` 结果的 `structuredContent` 由文本块里的 JSON 对象派生，与文本同源；纯文本结果（如 `interrogate_image` 返回的提示词）不带 `structuredContent`。应用内工具结果的 `details` 不对外暴露。
- 会话空闲 30 分钟回收（每分钟扫描一次）；同时最多保留 16 个会话，超出时淘汰最久未活动的一个。

发现文件在服务器运行期间发布，停止或退出时删除：

| 平台 | 路径 |
| --- | --- |
| Windows | `%APPDATA%/nai-launcher/mcp-server.json` |
| macOS | `~/.nai-launcher/mcp-server.json` |

字段为 `schema_version`、`transport`、`endpoint`、`port`、`pid`、`started_at`、`token`、`protocol_versions`、`app_version`。`protocol_versions` 列出 `dart_mcp` 当前接受的全部版本（`2024-11-05` 至 `2025-11-25`）。

## 安全模型

- **令牌**：32 字节随机数，base64url 无填充编码，首次需要时生成并保存在系统安全存储（`flutter_secure_storage`，键 `mcp_server_token_v1`）。比较使用常量时间实现 `constantTimeEquals`，避免按字节比较泄露前缀。重新生成会重启监听并断开全部已连接客户端。
- **鉴权**：MCP `/mcp` 请求缺失或错误的 `Authorization` 返回 `401` 并带 `WWW-Authenticate: Bearer`。图片展示使用独立的 32 字节随机逐图凭证，不需要浏览器为 `<img>` 添加 Bearer，也不能用图片凭证调用 MCP。图片地址中不包含主令牌、用户提示词或原图路径。
- **Origin 门禁**：浏览器页面会带 `Origin`，非回环来源返回 `403`，挡住 DNS rebinding；非浏览器客户端不带该头，缺失视为放行。
- **Host 门禁**：带了 `Host` 就必须是回环主机名，否则 `403`。
- **绑定地址**：只绑定 `InternetAddress.loopbackIPv4`，同一端口被占用（通常是另一个启动器实例）时启动失败并在设置页报 `port_in_use`。
- **发现文件里的令牌**：文件写在当前用户的配置目录，非 Windows 平台写入后置为 `600`，并通过临时文件重命名原子替换。它与应用自身的账号数据同属一个用户级信任边界——能读到这个目录的进程本来就能读应用数据，所以把令牌放进去不会扩大暴露面，换来的是随包 stdio 代理零配置可用。
- **云同步**：`mcp_server_enabled`、`mcp_server_port`、`mcp_server_permission_mode`、`mcp_server_token_v1` 四个键全部排除在云备份之外，端口和令牌绑定本机，跨设备同步只会互相踢掉端口。约束由 `test/data/cloud_sync/cloud_sync_adapter_contract_test.dart` 钉住。
- **图片展示边界**：HTTP 图片缓存在内存中，最多 64 张、128 MiB，超出时淘汰最旧项；单图超过预算时仍返回原生 `ImageContent`，但不生成 HTTP 地址。地址最长有效 1 小时，停止服务、换发主令牌及缓存淘汰会使其提前失效；收紧隐私要求后拒绝并移除未净化地址。只接受当前 `127.0.0.1:<port>` Host、回环连接与缺失/回环 Origin；图片接口单独允许 Electron 的 `Origin: null`，MCP 协议端点不放宽。GET/HEAD 之外拒绝，不支持目录遍历、查询参数鉴权、SVG 或 HTML。响应设置 `no-store`、`nosniff` 与 `no-referrer`，不写磁盘或参与云备份。

## 权限与审批

外部客户端使用独立的权限模式，默认“敏感操作前询问”：

| 模式 | 外部调用的效果 |
| --- | --- |
| 安全 | `tools/list` 只包含只读工具，写操作不进入工具面 |
| 敏感操作前询问 | 只读直接执行；写操作逐次在启动器内请求确认 |
| 完全访问 | 所有工具直接执行；只有计费操作仍需确认 |

无论哪种模式：

- 删除、清空、取消类工具与其他写操作同等处理，只通过 `destructiveHint` 提示客户端。
- Anlas 估算为正数或无法估算时始终需要确认；估算为负数直接拒绝；精确为零才按普通规则执行。
- 授权请求以浮层卡片出现在任意页面顶部居中，不占用页面布局，侧边面板打开时仍可操作；启用提示音时同时播放提示音；5 分钟未处理自动拒绝。
- 被拒绝、超时或取消的调用返回带 `isError` 的工具结果，不会静默成功。

执行链路上，只读工具并发执行，非只读工具串行化，保证同一时刻至多一个待授权的写操作。每次调用在查表、参数校验、权限裁决和结果四个阶段写审计记录，落在应用支持目录的 `agent/mcp-audit-v1.jsonl`，与聊天端的 `agent/audit-v1.jsonl` 分开存放，两份都会被“设置 → 关于 → 导出诊断日志”打包。

## 工具面与排除项

普通生图的最短链路是 `prepare_generation → submit_generation`，无需默认先读取应用上下文。提示词、尺寸、数量、种子、角色等参数全部内联在 `prepare_generation` 里，只对本次请求生效，不改动生成页面，也不需要先把它们写进页面。准备响应只包含 ID、精确费用、关键参数和 `next_action`；状态为 `prepared` 时尚未生成，直接按 `next_action` 提交，不查询进度或历史图。完整参数可通过 `inspect_generation_preparation` 或 `include_parameters: true` 获取。需要一个由调用方掌握的持久文件时，在准备阶段传 `save_path`，提交后启动器把每张成品写到该路径。

`generate_image` / `queue_image_task` 保留为兼容入口：不带 `preparation_id` 时只准备，费用为零也不会自动执行；带 ID 时提交已有快照，不必重传 `prompt`。`auto_start` 只表示队列提交入队后是否启动，不代表已经生成。应用内费用审批保持不变。

只在任务需要现有参数时读取 `get_generation_settings` / `get_prompt_state`；`set_positive_prompt`、`update_generation_settings`、角色与源图工具是替用户改动生成页面，不是生图步骤，外部工具面在这些描述末尾统一注明；`get_application_context` 用于导航、画廊和队列状态，默认仅返回草稿摘要，`include_draft_details: true` 才包含完整草稿参数。MCP 文本与 `structuredContent` 继续保留同源兼容表示，不把协议载荷字节数直接当作模型 token 计费数。

外部工具面复用聊天端同一份工具实现与权限目录，只换上不依赖聊天会话的替身依赖，注册顺序稳定，因此同一权限模式下 `tools/list` 逐次一致。

排除 8 个只对聊天有意义或外部客户端自带的工具：

| 工具 | 排除原因 |
| --- | --- |
| `ask_user_question` | 需要就地向用户追问，外部客户端有自己的提问通道 |
| `read` | 外部客户端自带文件读取能力 |
| `read_skill`、`read_skill_resource`、`get_skill_diagnostics`、`reload_skills` | Skills 是内置代理的提示词机制，不构成对外能力 |
| `web_search`、`web_read` | 外部客户端自带联网检索 |

其余行为：

- 每个工具带 `annotations`，`readOnlyHint`、`destructiveHint`、`idempotentHint` 由权限目录的操作类型推导，`openWorldHint` 固定为 `false`（工具只作用于本机启动器状态）。
- `generate_image` / `submit_generation` 完成生成后直接返回原分辨率 MCP `ImageContent` 和适合当前客户端的顶层 `display_markdown`，其中按顺序汇总全部图片，可直接嵌入最终回复，无需遍历 `images[]` 或再调用 `display_images`。相同 Markdown 另附为独立文本块，避免客户端只转发图片或摘要 JSON 时丢掉显示信息；逐图字段仍保留。`display_images` 只用于用户要求的历史图或失效／缺失／加载失败的展示引用；`inspect_images` 用于尚未返回的图片分析。外部图片响应不使用内置聊天的 256px JPEG 缩略图。
- `get_recent_images` 只返回资源列表。外部图片响应不返回图库相对路径、原始绝对路径或 `details.files`，唯一例外是生成结果的 `saved_path`：调用方不传 `save_path` 时它直接指向图库原图，并以 `saved_path_source: gallery_original` 标明。需要再次显示时使用 `display_images`，不要为展示调用 `save_generated_image` 另存图库副本。`resource_ref` 保留为应用拥有的稳定身份，不由客户端拼成文件路径。
- `ImageContent` 已返回不等于用户已看到图片，客户端可能将它放在折叠的工具详情内。已完成的生成结果及 `display_images` 默认 `include_display_url: true`，返回 `display_url`、`display_url_expires_at` 与 `display_url_markdown`；Cherry Studio 等会过滤本地路径的客户端应把 HTTP Markdown 直接嵌入正文，不放入代码块或改成普通链接。地址只能在启动器所在机器使用，失效时重新取图，不重新生成。
- Codex 桌面版的生成结果和 `display_images` 默认附带安全显示缓存文件，`display_markdown` 自动选取 `display_file_markdown`，可用 `include_display_file: false` 关闭。除终端链接客户端外的其它客户端默认只使用 HTTP 展示引用；两个明确格式字段仍可单独使用。客户端所需格式缺失时不把另一种格式冒充为可用的 `display_markdown`，而是保留原生图片与 `resource_ref` 并提示只重取展示引用。响应使用 `display_status: requires_client_rendering` 与 `image_content_count`，不以 `displayed_count` 暗示展示已完成。生成已经完成时，可选展示缓存写入或 URL 发布失败不丢弃已净化的原生图片，也不会重新生成。
- Claude Desktop 可以直接呈现工具结果中的原生图片；HTTP Markdown 属于另一条展示路径，可能显示需要点击的占位块。仍保留图片 Markdown 与 `display_link_markdown` 作为兼容引用，不能把链接跳转成功当作正文已显示，也不能从客户端名称推断全部展示能力。
- 终端里的 Claude Code（`claude-code`）画不出图片，其 `display_images` 默认同时准备两种展示引用，显式传入 `include_display_file: false` 或 `include_display_url: false` 仍然生效，`display_markdown` 改为可点击的 `display_link_markdown`，优先指向 HTTP 地址，缺失时指向显示缓存路径。已有 `saved_path` 时改为两条链接：先是不会过期的 `file://` 持久文件，再是临时 HTTP 预览。
- 显示缓存只写入已准备好的传出图像字节，与 `ImageContent` 完全一致；使用内容哈希中性命名，重复请求复用文件，不暴露图库原路径。缓存位于系统临时目录的 `nai_launcher_mcp_display`，每个服务实例首次写入时清理超过 7 天的自有缓存；不写入项目工作区、不导入图库、不参与云备份。
- 开启“保护模式”及“复制/拖拽时移除全部元数据”时，外部生成、检查和展示返回净化后的原分辨率图片，移除 PNG 文本块、EXIF 与 NAI 隐写水印；同时省略这些图片响应中的种子与引用展示/来源提示。HTTP 展示和本地显示缓存复用同一净化结果，不修改图库原图，也不对 MCP 图片自动叠加复制/拖拽水印。该开关不影响 `saved_path`：它指向的图库原图保持原样，路径只供本机打开。
- MCP 的 `save_generated_image` 和 `copy_generated_image_to_clipboard` 同样遵守上述元数据设置，在实际写文件/剪贴板之前完成净化，并在结果中报告 `metadata_stripped`。净化输出为 PNG，另存目标应使用 `.png`；格式不匹配、目标已存在或不在授权范围时仍拒绝，不静默改名或覆盖。净化失败不创建输出，也不回退原始字节。这是外部 MCP 的导出边界，不改变图库自动保存、内置聊天显式保存原图或 Krita 的既有流程；仅为展示图片时仍应优先用 `display_images`。
- `save_path` 只支持 `operation: generate`，扩展名必须是 `.png`，一次提交产出多张时文件名必须含 `{index}`、`{seed}` 或 `{id}`（图片 ID）。准备阶段即校验作用域与目标不存在，审批卡显示该目标；提交后逐张返回 `saved_path`，写盘失败返回 `save_error`，图片照常返回，既不影响生成结果也不重新生成。Codex 与 Claude Code 桌面版的 `display_markdown` 优先指向该文件；`get_recent_images` 不回显它。
- 调用方不传 `save_path` 时不写任何副本：图库自动保存开着就把 `saved_path` 指向图库原图并返回 `saved_path_source: gallery_original`，与“去除元数据”开关无关；自动保存关闭时给 `original_unavailable`，只剩会过期的 HTTP 预览，需要持久文件就传 `save_path`。审批卡只在真的写盘时显示目标。`saved_path_source` 取 `caller` 或 `gallery_original`，调用方显式传的路径始终是 `caller`；`update_generation_preparation` 传 `save_path: ""` 表示回到引用图库原图，不是清空目标。
- 净化或原图读取失败时返回错误，不回退到原始字节或缩略图；已完成生成不会因此自动重跑或再次扣费。开关在每次返回图片时读取，不复用旧的未净化输出。
- 最终是否展示、预览尺寸以及模型输入缩放由 MCP 客户端决定；`inspect_images` 不承诺外部客户端一定对用户隐藏图片。标准 `ImageContent` 直接承载图像，不要求客户端额外实现 Resource URI 读取。
- 服务器 `instructions` 只保留两阶段生成、按需读取和审批边界的简短指引，避免客户端将大段公共说明重复附到每个工具。客户端特定的展示方法随图片结果下发；图像后续操作使用 `resource_ref`，不重新编码或传回图像字节。

## CLI 参考

`nai_launcher_mcp` 随桌面端一起分发，用于把只会 stdio 的客户端接到 Streamable HTTP 端点：

| 平台 | 位置 |
| --- | --- |
| Windows | 与 `nai_launcher.exe` 同目录的 `nai_launcher_mcp.exe` |
| macOS | `Aaalice NAI Launcher.app/Contents/MacOS/nai_launcher_mcp` |

子命令（不带子命令时等同 `proxy`）：

| 子命令 | 作用 |
| --- | --- |
| `proxy` | 逐行读取 stdin 上的 JSON-RPC，一条一个 POST，服务器消息逐行写回 stdout |
| `status` | 打印 `endpoint`、`pid`、`started_at`、`app_version`、`protocol_versions`、`token: hidden (N characters)`、`discovery_file` 与 `reachable: yes` / `reachable: no` |
| `print-config <client>` | 打印对应客户端的配置片段，`<client>` 取 `claude-code`、`codex`、`cursor`、`cherry-studio`、`pi`、`claude-desktop` |

全局选项：`--endpoint <url>`、`--token <token>`、`--token-env <NAME>`、`--discovery-file <path>`、`--verbose`。端点与令牌按“显式选项 > 环境变量 > 发现文件”解析；两者都能从选项或环境得到时不再读发现文件。

退出码：

| 码 | 含义 |
| --- | --- |
| `0` | 正常结束 |
| `2` | 启动器未运行或 MCP 服务器未启用（发现文件不存在）；会话中途连接被拒同样返回此码，让客户端丢弃代理进程，避免更新时可执行文件被占用 |
| `3` | 发现文件存在但无法解析或 schema 版本不支持 |
| `64` | 命令行用法错误 |

构建用 `scripts/build_mcp_cli.ps1`。它走 `dart build cli` 再把产物拷到发布目录：应用的依赖图声明了 native build hooks，`dart compile exe` 会直接拒绝这类包。Windows 打包脚本会校验产物中存在 `nai_launcher_mcp.exe`，安装器在覆盖安装前也会结束残留的代理进程。

## 设置页说明

入口是“设置 → 集成 → MCP”，面板分三组：

- **连接与可用性**：启用开关、状态行（已关闭／启动中／监听中／错误，端口占用时给出改端口提示）、端点地址（可选中并复制）、端口输入（`1024`–`65535`，提交后生效）、发现文件路径、接入令牌（默认掩码，可显示、复制、重新生成）。
- **权限**：三档权限模式单选，说明文案与聊天代理一致，并固定提示任何可能消耗 Anlas 的操作都会在启动器内单独确认。
- **客户端**：待处理授权提示（实际同意／拒绝在页面顶部的授权浮层完成）、已连接客户端列表（名称版本、接入时间、最近活动）、置顶且默认展开的推荐提示词、六类客户端的配置片段与复制按钮，以及查看本文的入口。配置片段预览中的令牌是掩码，只有复制动作写出真实令牌；该区块仅在服务器监听时显示。

端口和令牌的改动会重启服务器并断开全部已连接的客户端，客户端需要重新 `initialize`。权限模式的改动不重启服务器：新会话立即按新模式构建工具面，已连接会话的 `tools/list` 保持连接时的快照，调用已退出工具面的工具会返回错误结果。

## 前向兼容与升级路线

MCP `2026-07-28` 修订移除了 `initialize` 握手和 `Mcp-Session-Id`，改为无状态、逐请求携带 `_meta`，并用 MRTR 取代服务端发起的请求。启动器当前实现 `2025-11-25`，原因有两条：唯一已发布的 Dart SDK `dart_mcp` 0.5.2 只做到这一版；现有客户端也仍在走旧握手。

设计上已经为切换留好边界：工具状态不放在会话里，跨调用的上下文一律用显式句柄表达（例如 `preparation_id`、`resource_ref`），会话只承载传输层的消息配对。因此升级是一次传输层替换——把 `mcp_streamable_http_transport.dart` 与 `mcp_session_registry.dart` 换成 `dart_mcp` 0.6.0 的 `handleStreamableHttpRequest`——工具、权限和界面不需要改动。

## 验证方法

1. 在设置中启用服务器，确认状态为监听中，并确认发现文件已生成。
2. 运行 `nai_launcher_mcp status`，确认 `endpoint`、`pid` 与 `reachable: yes`；该命令只做 TCP 连接探测，不会发送令牌。
3. 用 `claude mcp add --transport http ...` 注册后，在 Claude Code 中执行 `/mcp`，确认 `nai-launcher` 已连接且工具列表非空。
4. 把 `initialize`、`notifications/initialized`、`tools/list` 三行 JSON-RPC 依次喂给 `nai_launcher_mcp`（默认即 `proxy`），确认 stdout 逐行返回对应响应。
5. 在设置中关闭服务器，确认发现文件消失、已连接客户端断开。
6. 自动化回归位于 `test/core/mcp/` 与 `test/presentation/mcp/`，覆盖鉴权、Origin/Host 门禁、体积上限、会话生命周期、取消与断连中止、工具面排除项、审批超时与 CLI 退出码。

## 相关文件

| 职责 | 文件 |
| --- | --- |
| 常量与默认值 | `lib/core/mcp/mcp_server_constants.dart` |
| 监听、发现文件与会话清扫 | `lib/core/mcp/mcp_server_host.dart` |
| Streamable HTTP 传输 | `lib/core/mcp/mcp_streamable_http_transport.dart` |
| 会话注册表 | `lib/core/mcp/mcp_session_registry.dart` |
| 协议端点与 `instructions` | `lib/core/mcp/mcp_launcher_server.dart` |
| 鉴权、Origin 与令牌生成 | `lib/core/mcp/mcp_bearer_authenticator.dart`、`lib/core/mcp/mcp_origin_policy.dart`、`lib/core/mcp/mcp_token_generator.dart` |
| 发现文件读写 | `lib/core/mcp/mcp_discovery_file.dart`、`lib/core/platform/launcher_discovery_directory.dart` |
| 工具与结果转换 | `lib/core/mcp/mcp_tool_adapter.dart`、`lib/core/mcp/mcp_tool_executor.dart` |
| CLI 与 stdio 代理 | `bin/nai_launcher_mcp.dart`、`lib/core/mcp/cli/`、`lib/core/mcp/mcp_cli_path.dart` |
| 外部工具面与排除项 | `lib/presentation/mcp/services/mcp_external_tool_registry_factory.dart` |
| 执行链、权限与审计 | `lib/presentation/mcp/services/mcp_tool_call_pipeline.dart`、`lib/presentation/mcp/services/mcp_approval_coordinator.dart` |
| 授权横幅 | `lib/presentation/mcp/widgets/mcp_approval_banner.dart` |
| 生命周期与设置 | `lib/presentation/mcp/providers/mcp_server_notifier.dart` |
| 设置面板 | `lib/presentation/screens/settings/sections/mcp_server_settings_section.dart`、`lib/presentation/screens/settings/sections/mcp_server/`、`lib/presentation/screens/settings/sections/integrations_settings_section.dart` |
| CLI 构建 | `scripts/build_mcp_cli.ps1` |
