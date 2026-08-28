# NAI Launcher

<p align="center">
  简体中文 | <a href="README.en-US.md">English</a>
</p>

<p align="center">
  <img src="assets/icons/Icon.png" alt="NAI Launcher Logo" width="120">
</p>

<p align="center">
  <strong>面向 NovelAI 图像生成的第三方跨平台客户端</strong>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest"><img src="https://img.shields.io/github/v/release/Aaalice233/Aaalice_NAI_Launcher?display_name=tag&sort=semver" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Android-lightgrey" alt="Platforms">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <a href="https://discord.gg/R48n6GwXzD"><img src="https://img.shields.io/badge/Discord-加入服务器-5865F2?logo=discord&logoColor=white" alt="Discord"></a>
</p>

NAI Launcher 是一个使用 Flutter 构建的 NovelAI 第三方跨平台客户端。它把图像生成、图生图、局部重绘、Vibe / Precise Reference、本地图库、在线图库、生成队列、Krita 联动和统计工具整合在同一个应用里，适合日常生成、批量出图和长期管理本地作品。

> 本项目不是 NovelAI 官方产品。使用前请确保你拥有自己的 NovelAI 账号，并遵守 NovelAI 的服务条款。

## ✨ 功能概览

| 能力 | 说明 |
| --- | --- |
| 🎨 图像生成 | 支持 NovelAI Diffusion V1/V2/V3/V4/V4.5/V5、Furry 系列、常用采样器、尺寸预设、多角色参数和 Anlas 估算。 |
| 🖼️ 图生图与编辑 | 支持图生图、局部重绘、Focused Inpaint、Outpaint、虚拟画布扩图、硬边蒙版和点击式区域填充。 |
| 🌈 参考与风格 | 支持 Vibe Transfer、Precise Reference、多图参考、Vibe 整包导入导出、PNG 元数据嵌入导出。 |
| ✍️ Prompt 工具 | 内置完整离线 Danbooru/e621 合并标签与别名；本地 Danbooru 共现关系以可选数据包提供，默认进入主页后后台下载。支持 `Ctrl/⌘+Shift+Space` 查询光标前标签的相关词、固定来源标签后连续选词、Danbooru 在线相关标签补充、可选中文词库与 AI 缺失汉化，以及 NAI/SD 权重语法辅助、Token 统计、提示词框内搜索和固定词。 |
| 🤖 智能代理 | 在生成页侧栏中使用已配置的第三方模型进行多轮对话，可查看和调整 Prompt、角色及生成参数，检索标签和生成历史，并按权限模式执行生成或读取图片等操作。可选联网工具支持 SearXNG、匿名 Exa MCP 或 Exa API 搜索，并按需读取单个公开网页；会话以 JSONL 保存在本机。 |
| 🎲 随机词库 | 内置完整还原的 NovelAI 官网随机词库，并按当前模型使用 Legacy Anime、Furry V3 或 Character Prompts；自定义模式使用完整离线标签 catalog，混合模式同时结合两种来源。可调整 catalog 分类、词组、权重、排除与依赖规则，预览结果并导入导出自定义预设。 |
| 📚 本地图库 | 支持递归扫描、SQLite 全文搜索、分类/收藏/集合、元数据解析、批量操作和大图预览。 |
| 🌐 在线图库 | 支持 Danbooru / Safebooru / Gelbooru / AI TAG / 法典图鉴搜索、真实排行榜、多图详情、元数据复用和批量下载。 |
| 📦 生成队列 | 支持任务排序、批量生成、暂停/继续、失败策略、进度统计和队列导入导出。 |
| ☁️ 同步与备份 | 可通过自有 WebDAV 或 GitHub 存储在 Windows、macOS 与 Android 之间一键同步所选数据，支持完整性校验快照、历史恢复、逐项冲突处理及旧加密备份兼容；后端能力不足时仅提供手动云备份。 |
| 🔌 外部联动 | 桌面端支持 Krita 与 ComfyUI 本地工作流；同时提供系统代理、图片复制、原生分享、文件导入导出和文件定位等平台能力。 |
| 🌏 界面语言 | 支持简体中文、繁體中文、English 和日本語；繁体中文输入可继续检索可选的简中标签汉化词库。 |

### 在线画廊来源

- **Danbooru / Safebooru**：支持标签、日期搜索，以及指定日期的日榜、周榜和月榜；Danbooru 可登录并管理收藏，Safebooru 使用 `safebooru.donmai.us` 匿名只读访问。
- **Gelbooru**：支持公开搜索；配置 API 凭据后可加速搜索并浏览只读网站收藏，不提供伪造的本地排行榜。
- **AI TAG**：支持作品/作者/标题/标签/模型综合搜索和原样 Prompt 语法搜索（如 `::artist:`），时间范围由来源实时配置；支持实时月榜、历史月榜和旧月份归档。多图详情可切换、预取和逐图复用 NAI / Stable Diffusion / ComfyUI 元数据，并支持下载当前图片或作品全部图片。AI TAG 无需账号且仅提供只读访问。
- **法典图鉴（NovelAI QuickTagCloud）**：按法典、分类、更新批次、图片状态和完整文本字段浏览固定公开法典，支持多图与纯文本词条、贡献者署名、正负及多角色 Prompt 复制/生成/排队、本地收藏和最近浏览。内容分级复用画廊已有的分级选单，提供全年龄、可疑（成人）与限制级（R18G / 重口）三级筛选。法典版本 JSON 经大小与 SHA-256 校验后缓存，图片仅使用普通运行时网络缓存；所有内容始终从上游读取，不随安装包分发或镜像。

## 🖥️ 界面预览

<p align="center">
  <img src="assets/images/1.png" alt="图像生成界面" width="80%">
  <br>
  <em>图像生成主界面</em>
</p>

<p align="center">
  <img src="assets/images/2.png" alt="本地画廊" width="80%">
  <br>
  <em>本地画廊与瀑布流浏览</em>
</p>

<p align="center">
  <img src="assets/images/4.png" alt="图片详情" width="80%">
  <br>
  <em>图片详情、元数据和参数复用</em>
</p>

<p align="center">
  <img src="assets/images/5.png" alt="Danbooru 在线画廊" width="80%">
  <br>
  <em>Danbooru 在线画廊</em>
</p>

<p align="center">
  <img src="assets/images/7.png" alt="统计仪表盘" width="80%">
  <br>
  <em>统计仪表盘</em>
</p>

## 🧩 平台支持

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| Windows | 可用 | 主要开发和发布平台，支持系统托盘、窗口状态保存、视频播放、剪贴板和文件定位。 |
| macOS | 最小适配 | 支持构建、启动、登录、本地数据库、视频播放、Keychain、系统代理、图片复制和文件定位；系统托盘后续再补。 |
| Android | 可用 | 支持 Android 7.0+ 手机、横屏、平板和大屏自适应；完整提供生成、画廊、词库、队列与设置，并接入系统文件选择、导出、相册保存、分享和 APK 更新。 |
| Linux | 未发布 | 部分桌面代码已有分支，但当前不提供正式包。 |

## 📦 下载与安装

前往 [Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases) 下载最新版本。应用会在登录前后持续提示可用更新，并完整渲染 Release“更新内容”中的 GitHub Flavored Markdown（标题、列表、表格、引用、代码、链接与图片），不重复显示平台下载与文件校验区段。

| 平台 | 下载文件 | 使用方式 |
| --- | --- | --- |
| Windows | `NAI_Launcher_Windows_<version>_Setup.exe` | 安装版，推荐普通用户，安装到当前用户目录；支持应用内断点下载、校验、自动安装并重启。手动运行安装包时也会检测并关闭托盘中的旧版本。 |
| Windows | `NAI_Launcher_Windows_<version>_Portable.zip` | 便携版，解压后运行 `nai_launcher.exe`；应用内更新会暂存新版、保留用户文件、原子切换目录，失败时自动回滚并重启旧版。 |
| macOS | `NAI_Launcher_macOS_<version>_Portable.zip` | 便携版，解压后打开 `Aaalice NAI Launcher.app`。未公证版本如被拦截，可在系统设置的隐私与安全中允许打开。 |
| Android | `NAI_Launcher_Android_<version>.apk` | 适用于 Android 7.0 及以上版本。下载后由系统确认安装；首次安装可能需要允许浏览器或文件管理器“安装未知应用”，后续可在应用内下载、校验并交给系统确认更新。 |

首次登录可以使用 NovelAI 账号密码或 API Token。账号数据仅保存在本地设备，支持的平台使用系统安全存储保存敏感信息。

### 补全、智能代理与隐私

- 完整的基础 Danbooru/e621 标签与别名 catalog 随应用提供，只在本机查询，不需要联网。
- 本地相关标签共现数据由项目从固定版本的 [newtextdoc1111/danbooru-tag-csv](https://huggingface.co/datasets/newtextdoc1111/danbooru-tag-csv) 构建，并作为独立的可选数据包发布。相关标签功能开启时，应用默认在进入主页后后台下载约 30.3 MiB，安装后约占用 78.7 MiB；下载不会阻塞启动或基础补全。
- 数据包未就绪、下载失败或被关闭时，相关标签弹层仍可显示 Danbooru 在线结果。可在“设置 → 数据源与缓存”暂停、重试、修复或删除数据包，也可以关闭自动下载；删除时可同时选择停止以后自动下载。
- 简体中文汉化词库为可选组件。繁体中文界面与繁体标签输入同样可以使用该词库，查询时会在本地转换后匹配，不会上传输入内容。应用仅在用户确认后从 [ffdkj/ComfyUI_Danbooru_Tag_Assistant](https://github.com/ffdkj/ComfyUI_Danbooru_Tag_Assistant) 上游直接下载，项目不再分发该数据库。
- Danbooru 在线补充默认开启，只发送光标所在的当前英文 token，不发送完整提示词；可在“设置 → 数据源与缓存”关闭并单独清除缓存。
- AI 缺失汉化默认关闭。开启后会复用 Prompt Assistant 的 `Translate` 路由，向用户选择的模型服务发送最多 8 个待翻译标签，可能产生 API 费用；AI 翻译缓存可单独清除。
- 智能代理会把对话文本、用户附加的图片和完成当前任务所需的工具结果发送给用户选择的模型服务，可能产生对应服务的 API 费用，并受该服务的隐私政策约束。会话记录以 JSONL 保存在本机应用数据目录；文件读取默认限制在图片导出目录，只有用户主动选择“完全访问”后才允许读取该目录之外的文件。
- 智能代理的联网工具默认关闭，可通过聊天输入栏的地球图标控制。搜索会把查询词及所选时间、域名过滤发送到用户配置的 SearXNG，或发送到 Exa；自动模式优先使用已配置的 SearXNG，失败或未配置时使用不携带 API Key 的匿名 Exa MCP。只有用户明确选择 Exa API 模式时才会读取系统安全存储中的 Exa API Key 并发送给 Exa API。
- `web_read` 只在模型按需调用时直接读取单个公开 HTTP(S) 页面，并在本机提取可读正文；启用应用代理时请求和域名解析由该代理处理。提取后的网页正文会作为工具结果发送给用户选择的模型服务，不会自动读取全部搜索结果。
- “同步与备份”只会上传用户明确选择的数据范围，WebDAV 密码和 GitHub Token 仅保存在系统安全存储中且不会进入备份或在界面中回显。新配置不再叠加应用层加密密码或恢复密钥；内容保密性依赖 HTTPS 与服务商自身的存储安全，服务商可能读取上传内容。快照仍会执行大小、SHA-256、版本和并发更新校验。旧版加密 namespace 保持兼容，仅在本机安全密钥丢失时需要一次性输入旧密码或恢复密钥。

## 💬 支持与贡献

- 遇到问题或有功能建议，请提交 [GitHub Issue](https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues)。
- 交流使用经验、获取社区帮助可加入 [Discord](https://discord.gg/R48n6GwXzD)。
- 欢迎提交 Pull Request；请说明变更目标、验证方式，界面改动尽量附上截图或录屏。
- 每个版本的完整变化请查看 [CHANGELOG.md](CHANGELOG.md) 或 [Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases)。

## 🙏 致谢

- [NovelAI](https://novelai.net/) 提供图像生成服务。
- [所长法典站（法典图鉴）](https://novelai.quicktagcloud.com/) 及其 [AgIzT/NovelAI-Tag](https://github.com/AgIzT/NovelAI-Tag) 项目提供法典图鉴内容与服务。
- [Flutter](https://flutter.dev/) 提供跨平台 UI 能力。
- [Riverpod](https://riverpod.dev/) 提供状态管理能力。
- 感谢所有贡献者和测试用户。

## 📄 许可证

本项目基于 MIT License 开源，详见 [LICENSE](LICENSE)。
