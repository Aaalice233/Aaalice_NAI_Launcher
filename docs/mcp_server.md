# 外部智能体接入（MCP 服务）

启动器可以在本机开一个 MCP 服务器，让 Claude Code、Codex CLI、Cursor、Claude Desktop 等外部智能体通过与内置智能代理同一套工具层操作应用。本文面向要接入或维护这条链路的人。

本文与 [MCP 调试](mcp_debugging.md) 方向相反：那篇把 Dart/Flutter 官方 MCP server 接给 Codex 用于调试本项目，本篇是启动器自身作为 MCP 服务器对外提供工具。

## 概述与平台范围

- 仅 Windows 与 macOS 提供。能力开关是 `PlatformCapabilities.supportsMcpServer`，取值等同 `isDesktop`；Android 不启动服务器，设置里也不渲染该面板。
- 默认关闭，必须由用户在设置中启用。启用后只监听 `127.0.0.1`，不接受局域网或外部连接。
- 外部客户端拥有独立的权限模式和独立的审计日志，与聊天代理的设置互不影响。
- 所有需要授权的调用都在启动器窗口内裁决；任何可能消耗 Anlas 的操作都要用户在应用内确认。

## 快速开始（四类客户端）

1. 打开“设置 → 集成 → MCP”，启用 MCP 服务器，确认状态为监听中。
2. 在“接入令牌”处复制令牌，或直接复制对应客户端的配置片段。
3. 按下面的片段配置客户端，重启客户端后确认工具列表出现 `nai-launcher`。

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

## 端点与协议

单端点 `http://127.0.0.1:<port>/mcp`，默认端口 `20624`（`McpServerDefaults.port`），可在设置中改为 `1024`–`65535`。传输为 Streamable HTTP，按 MCP `2025-11-25` 修订的语义实现，协议层使用 `package:dart_mcp` 0.5.2。

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

- `initialize` 会新建会话，响应头返回 `Mcp-Session-Id`，后续所有请求都要带上。收到 `404` 表示会话已失效，客户端需要重新 `initialize`。
- 通知和响应返回 `202`，不带响应体。
- 请求在 SSE 模式下以 `event: message` 逐条下发，等待期间每 15 秒写一条 `: keep-alive` 注释；目标响应写出后连接即关闭。
- 每条 SSE 流只承载该请求自己的响应，以及 `_meta.progressToken` 与之匹配的 `notifications/progress`；同一会话的并发请求互不串流。不提供 GET 流，其它服务端主动消息会被丢弃。
- `notifications/cancelled` 会中止对应的在途 `tools/call`；SSE 期间客户端断开连接同样中止该调用。
- `DELETE` 带会话头结束该会话并返回 `200`，未知会话返回 `404`。
- 会话空闲 30 分钟回收（每分钟扫描一次）；同时最多保留 16 个会话，超出时淘汰最久未活动的一个。

发现文件在服务器运行期间发布，停止或退出时删除：

| 平台 | 路径 |
| --- | --- |
| Windows | `%APPDATA%/nai-launcher/mcp-server.json` |
| macOS | `~/.nai-launcher/mcp-server.json` |

字段为 `schema_version`、`transport`、`endpoint`、`port`、`pid`、`started_at`、`token`、`protocol_versions`、`app_version`。`protocol_versions` 列出 `dart_mcp` 当前接受的全部版本（`2024-11-05` 至 `2025-11-25`）。

## 安全模型

- **令牌**：32 字节随机数，base64url 无填充编码，首次需要时生成并保存在系统安全存储（`flutter_secure_storage`，键 `mcp_server_token_v1`）。比较使用常量时间实现 `constantTimeEquals`，避免按字节比较泄露前缀。重新生成会重启监听并断开全部已连接客户端。
- **鉴权**：缺失或错误的 `Authorization` 返回 `401` 并带 `WWW-Authenticate: Bearer`。
- **Origin 门禁**：浏览器页面会带 `Origin`，非回环来源返回 `403`，挡住 DNS rebinding；非浏览器客户端不带该头，缺失视为放行。
- **Host 门禁**：带了 `Host` 就必须是回环主机名，否则 `403`。
- **绑定地址**：只绑定 `InternetAddress.loopbackIPv4`，同一端口被占用（通常是另一个启动器实例）时启动失败并在设置页报 `port_in_use`。
- **发现文件里的令牌**：文件写在当前用户的配置目录，非 Windows 平台写入后置为 `600`，并通过临时文件重命名原子替换。它与应用自身的账号数据同属一个用户级信任边界——能读到这个目录的进程本来就能读应用数据，所以把令牌放进去不会扩大暴露面，换来的是随包 stdio 代理零配置可用。
- **云同步**：`mcp_server_enabled`、`mcp_server_port`、`mcp_server_permission_mode`、`mcp_server_token_v1` 四个键全部排除在云备份之外，端口和令牌绑定本机，跨设备同步只会互相踢掉端口。约束由 `test/data/cloud_sync/cloud_sync_adapter_contract_test.dart` 钉住。

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

外部工具面复用聊天端同一份工具实现与权限目录，只换上不依赖聊天会话的替身依赖，注册顺序稳定，因此同一权限模式下 `tools/list` 逐次一致。

排除 9 个只对聊天有意义或外部客户端自带的工具：

| 工具 | 排除原因 |
| --- | --- |
| `ask_user_question` | 需要就地向用户追问，外部客户端有自己的提问通道 |
| `display_images` | 只负责往聊天气泡里贴图，外部调用没有可渲染的位置 |
| `read` | 外部客户端自带文件读取能力 |
| `read_skill`、`read_skill_resource`、`get_skill_diagnostics`、`reload_skills` | Skills 是内置代理的提示词机制，不构成对外能力 |
| `web_search`、`web_read` | 外部客户端自带联网检索 |

其余行为：

- 每个工具带 `annotations`，`readOnlyHint`、`destructiveHint`、`idempotentHint` 由权限目录的操作类型推导，`openWorldHint` 固定为 `false`（工具只作用于本机启动器状态）。
- `inspect_images` 返回 MCP 图像内容；只有 URL 没有字节的来源退化为文本，保留链接。
- 服务器 `instructions` 给出推荐流程：先调 `get_application_context` 取得当前页面、模型、Prompt 和账号状态；生成分两步，`prepare_generation` 校验并返回 `preparation_id`，`submit_generation` 执行该笔准备；图像以 `resource_ref` 句柄传递，不要重新编码图像字节。

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
| `print-config <client>` | 打印对应客户端的配置片段，`<client>` 取 `claude-code`、`codex`、`cursor`、`claude-desktop` |

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
- **客户端**：待处理授权提示（实际同意／拒绝在页面顶部的授权浮层完成）、已连接客户端列表（名称版本、接入时间、最近活动）、四类客户端的配置片段与复制按钮，以及查看本文的入口。配置片段预览中的令牌是掩码，只有复制动作写出真实令牌；该区块仅在服务器监听时显示。

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
