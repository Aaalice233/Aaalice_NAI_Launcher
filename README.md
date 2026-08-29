# NAI Launcher

<p align="center">
  简体中文 · <a href="README.en-US.md">English</a>
</p>

<p align="center">
  <img src="assets/icons/Icon.png" alt="NAI Launcher 图标" width="112">
</p>

<p align="center">
  <strong>面向 NovelAI 的第三方跨平台客户端，集中处理生成、编辑、图库、标签与队列。</strong>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest"><img src="https://img.shields.io/github/v/release/Aaalice233/Aaalice_NAI_Launcher?display_name=tag&sort=semver" alt="最新版本"></a>
  <img src="https://img.shields.io/badge/Windows%20%7C%20macOS%20%7C%20Android-可用-6f7785" alt="支持平台">
  <img src="https://img.shields.io/badge/license-MIT-5b8c5a" alt="MIT License">
  <a href="https://discord.gg/R48n6GwXzD"><img src="https://img.shields.io/badge/Discord-加入社区-5865F2?logo=discord&logoColor=white" alt="Discord 社区"></a>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest">下载最新版</a> ·
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues">反馈问题</a> ·
  <a href="https://discord.gg/R48n6GwXzD">加入 Discord</a>
</p>

> **当前版本仍处于 beta 阶段。** 功能持续完善中，升级前请先备份重要数据。
>
> NAI Launcher 是 NovelAI 的第三方客户端，并非 NovelAI 官方产品。使用在线功能前，请确保你拥有自己的 NovelAI 账号，并遵守相关服务条款与当地法律。

![生成工作台](docs/screenshots/generation-desktop.png)

## 它能做什么？

NAI Launcher 面向长期使用 NovelAI 的创作者：生成图片、反复调整提示词、保存灵感、查找参考、管理作品，都在同一个工作流里完成。

### 🎨 创作

- **文生图与图像编辑**：文生图、图生图、Inpaint、Focused Inpaint、Outpaint，以及放大/增强。
- **参考与角色**：Vibe Transfer、Precise Reference、多角色提示词、参考图和独立负面提示词。
- **Prompt 工作台**：标签自动补全、权重语法、Token 统计、固定词、随机词库和提示词导入导出。

### 🗂️ 整理

- **本地图库**：扫描本地作品，搜索 Prompt 与元数据，分类、收藏、创建集合，并支持批量操作。
- **生成队列**：批量提交、暂停/继续、排序、失败处理和进度查看。
- **图片详情**：查看生成参数、正负提示词和角色词；需要时将内容安全地复制回生成页或词库。
- **统计面板**：按尺寸、采样器、时间与 Anlas 消耗回顾自己的创作习惯。

### 🌐 探索

- **在线画廊**：在 Danbooru、Safebooru、Gelbooru、AI TAG 和法典图鉴（NovelAI QuickTagCloud）之间切换搜索。
- **来源筛选**：搜索、收藏、日期/排行榜、内容分级、黑名单与输出过滤，随来源能力提供。
- **词库与参考资源**：管理自己的标签、固定词、Vibe 和 Precise Reference 资源。

### 🤝 协作与连接

- **智能代理**：在生成页侧栏或移动端抽屉中对话，让它协助检索标签、整理 Prompt、查看历史并准备生成；所有可能消耗 Anlas 的操作都会单独确认。
- **桌面联动**：连接 Krita Bridge 与本地 ComfyUI 工作流，把生成和编辑接到已有创作工具中。
- **同步与备份**：通过 GitHub 或 WebDAV 手动推送、拉取已选择的数据；凭据和 NovelAI Token 不会进入备份。

## 界面预览

以下截图来自当前版本，按「生成 → 整理 → 探索 → 连接 → 移动端」排列。

### 生成与编辑

<p align="center">
  <img src="docs/screenshots/generation-desktop.png" alt="桌面端生成工作台" width="100%">
  <br>
  <em>生成工作台：Prompt、角色、参数与历史结果同屏协作</em>
</p>

<table>
  <tr>
    <td width="33%"><img src="docs/screenshots/generation-panel.png" alt="角色与图生图面板" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/generation-params.png" alt="生成参数面板" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/generation-batch.png" alt="批量生成过程" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/generation-results.png" alt="批量生成结果" width="100%"></td>
    <td><img src="docs/screenshots/image-details-desktop.png" alt="图片详情与生成参数" width="100%"></td>
    <td><img src="docs/screenshots/image-copy-dialog.png" alt="提示词分类复制" width="100%"></td>
  </tr>
</table>

### 画廊与资源库

<table>
  <tr>
    <td width="33%"><img src="docs/screenshots/online-favorites.png" alt="在线画廊收藏与搜索" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/online-detail.png" alt="在线画廊图片详情" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/codex-detail.png" alt="法典图鉴详情" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/blacklist-settings.png" alt="在线画廊黑名单设置" width="100%"></td>
    <td><img src="docs/screenshots/vibe-library.png" alt="Vibe 资源库" width="100%"></td>
    <td><img src="docs/screenshots/precise-reference.png" alt="Precise Reference 资源库" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/random-library.png" alt="随机词库配置" width="100%"></td>
    <td><img src="docs/screenshots/tag-library.png" alt="角色与画师词库" width="100%"></td>
    <td><img src="docs/screenshots/stats.png" alt="统计仪表盘" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/queue.png" alt="生成队列管理" width="100%"></td>
    <td></td>
    <td></td>
  </tr>
</table>

### 智能代理与设置

<table>
  <tr>
    <td width="33%"><img src="docs/screenshots/agent.png" alt="智能代理对话与生成协作" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/agent-confirm.png" alt="智能代理生成确认" width="100%"></td>
    <td width="33%"><img src="docs/screenshots/agent-result.png" alt="智能代理生成结果" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/agent-search.png" alt="智能代理查询词库" width="100%"></td>
    <td><img src="docs/screenshots/generation-settings.png" alt="生成设置" width="100%"></td>
    <td><img src="docs/screenshots/agent-settings.png" alt="智能代理设置" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/data-settings.png" alt="数据与存储设置" width="100%"></td>
    <td><img src="docs/screenshots/backup-settings.png" alt="备份与恢复设置" width="100%"></td>
    <td><img src="docs/screenshots/security-settings.png" alt="安全与分享设置" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/integrations-settings.png" alt="集成设置" width="100%"></td>
    <td><img src="docs/screenshots/autocomplete.png" alt="标签自动补全" width="100%"></td>
    <td><img src="docs/screenshots/tag-search.png" alt="标签搜索与词库候选" width="100%"></td>
  </tr>
</table>

### Android

<table>
  <tr>
    <td width="25%"><img src="docs/screenshots/mobile-generation-progress.png" alt="Android 生成中" width="100%"></td>
    <td width="25%"><img src="docs/screenshots/generation-mobile.png" alt="Android 生成完成" width="100%"></td>
    <td width="25%"><img src="docs/screenshots/mobile-viewer.png" alt="Android 图片查看器" width="100%"></td>
    <td width="25%"><img src="docs/screenshots/mobile-image-menu.png" alt="Android 图片操作菜单" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/mobile-generation-settings.png" alt="Android 生成设置" width="100%"></td>
    <td><img src="docs/screenshots/mobile-agent.png" alt="Android 智能代理对话" width="100%"></td>
    <td><img src="docs/screenshots/mobile-agent-result.png" alt="Android 智能代理生成流程" width="100%"></td>
    <td><img src="docs/screenshots/mobile-gallery.png" alt="Android 本地画廊" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/mobile-library.png" alt="Android 词库页面" width="100%"></td>
    <td><img src="docs/screenshots/mobile-more.png" alt="Android 更多菜单" width="100%"></td>
    <td><img src="docs/screenshots/mobile-settings.png" alt="Android 设置页面" width="100%"></td>
    <td><img src="docs/screenshots/mobile-extensions.png" alt="Android 扩展页面" width="100%"></td>
  </tr>
  <tr>
    <td><img src="docs/screenshots/mobile-image-menu-alt.png" alt="Android 图片菜单" width="100%"></td>
    <td><img src="docs/screenshots/mobile-tag-library.png" alt="Android 标签库" width="100%"></td>
    <td></td>
    <td></td>
  </tr>
</table>

## 平台支持

| 平台 | 当前状态 | 适合谁 |
| --- | --- | --- |
| **Windows** | 主要开发与发布平台 | 适合长时间创作、批量生成、Krita / ComfyUI 联动。提供安装版和便携版。 |
| **macOS** | 可用，仍在持续完善 | 提供便携版；首次使用未公证应用时，按 macOS 的安全提示允许打开。 |
| **Android** | beta | 支持手机、横屏、平板和大屏；生成、画廊、词库、队列与设置均提供移动端入口。 |
| **Linux** | 暂无正式发行包 | 暂不作为正式下载目标。 |

## 下载与首次使用

### 1. 下载

从 [GitHub Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest) 下载对应平台的文件。每个 Release 同时提供 `checksums.txt`，遇到下载损坏或安装异常时可先核对校验值。

| 平台 | 文件 | 说明 |
| --- | --- | --- |
| Windows | `NAI_Launcher_Windows_<version>_Setup.exe` | 安装版，适合大多数用户。 |
| Windows | `NAI_Launcher_Windows_<version>_Portable.zip` | 便携版，解压后直接运行，不改变安装目录。 |
| macOS | `NAI_Launcher_macOS_<version>_Portable.zip` | 解压后打开 `Aaalice NAI Launcher.app`。 |
| Android | `NAI_Launcher_Android_<version>.apk` | APK 侧载安装；首次安装可能需要允许文件管理器或浏览器安装未知应用。 |

### 2. 登录 NovelAI

首次启动可以使用 NovelAI 账号密码或 **Persistent API Token** 登录。若网页安全验证导致密码登录失败，建议改用 Persistent API Token。未登录也可以先使用本地图库、词库、资源库和设置；生成、Vibe 编码、云端超分等在线操作需要登录。

### 3. 配置自己的工作流

- **本地图库**：在设置中选择作品目录，再进入图库开始扫描；图库按需处理，不会因为只启动应用就扫描全部文件。
- **标签补全**：基础标签库随应用提供，可离线使用。相关标签推荐、中文标签词库和 AI 翻译属于可选数据源，在“设置 → 数据源与缓存”中管理。
- **Krita**：先在 Launcher 设置中启用 Krita Bridge，再按 [`krita_plugin/README.md`](krita_plugin/README.md) 安装插件。
- **ComfyUI**：在“设置 → 集成”中配置本地 ComfyUI 地址和工作流；具体模型与节点仍由 ComfyUI 环境负责。

## 数据与隐私

NAI Launcher 不把账号系统和作品托管在本项目服务器上。不同功能会把数据发送给不同的服务：

| 你正在使用的功能 | 数据接收方 |
| --- | --- |
| 生成、图生图、编辑、Vibe 编码 | NovelAI；包括对应的 Prompt、参数和参考图/源图。 |
| 在线画廊搜索与下载 | 你选择的第三方图库；各站点的可用性、限流和内容规则由站点决定。 |
| AI 翻译或智能代理 | 你配置的模型服务；对话、附加图片和完成任务所需的工具结果可能产生服务费用。 |
| 同步与备份 | 你配置的 GitHub 或 WebDAV 存储；只上传你明确选择的数据范围。 |

- NovelAI Token、WebDAV 密码和 GitHub Token 使用设备的安全存储保存，不会写入备份。
- 本地 Prompt、图库索引、标签和代理会话默认保存在本机；代理的联网工具默认关闭。
- 在线图库包含第三方内容，分级筛选不能替代用户判断；请遵守来源站点规则、当地法律和 NovelAI 服务条款。
- WebDAV 的数据安全取决于你配置的服务和传输方式；同步前请确认服务器可信，并保留重要数据的本地备份。

## 支持与反馈

- [提交 Issue](https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues)：报告可复现的问题或提出功能建议。
- [加入 Discord](https://discord.gg/R48n6GwXzD)：交流使用经验、获取社区帮助。
- [查看 Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases)：下载版本、校验文件与更新内容。
- 欢迎提交 Pull Request；界面改动请附截图或录屏，方便复现和讨论。

## 致谢

感谢 [NovelAI](https://novelai.net/)、[法典图鉴](https://novelai.quicktagcloud.com/)、[AgIzT/NovelAI-Tag](https://github.com/AgIzT/NovelAI-Tag)、[Flutter](https://flutter.dev/)、[Riverpod](https://riverpod.dev/) 以及所有贡献者和测试用户。

## 许可证

本项目基于 [MIT License](LICENSE) 开源。
