# NAI Launcher

<p align="center">
  简体中文 · <a href="README.zh-TW.md">繁體中文</a> · <a href="README.en-US.md">English</a>
</p>

<p align="center">
  <img src="assets/icons/Icon.png" alt="NAI Launcher 图标" width="112">
</p>

<p align="center">
  <strong>不只是生成图片，而是把整套 NovelAI 创作流程装进一个应用。</strong>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest"><img src="https://img.shields.io/github/v/release/Aaalice233/Aaalice_NAI_Launcher?display_name=tag&sort=semver" alt="最新版本"></a>
  <img src="https://img.shields.io/badge/Windows%20%7C%20macOS%20%7C%20Android-可用-6f7785" alt="支持平台">
  <img src="https://img.shields.io/badge/license-MIT-5b8c5a" alt="MIT License">
  <a href="https://discord.gg/R48n6GwXzD"><img src="https://img.shields.io/badge/Discord-加入社区-5865F2?logo=discord&logoColor=white" alt="Discord 社区"></a>
</p>

<p align="center">
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest">下载最新版</a> ·
  <a href="CHANGELOG.md">查看更新记录</a> ·
  <a href="https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues">反馈问题</a> ·
  <a href="https://discord.gg/R48n6GwXzD">加入 Discord</a>
</p>

> NAI Launcher 是社区开发的第三方客户端，并非 NovelAI 官方产品。使用在线功能前，请准备自己的 NovelAI 账号，并遵守相关服务条款、内容规则与当地法律。

NAI Launcher 面向经常使用 NovelAI 的图像创作者。生成、改图、Prompt、角色、参考图、图库、队列和智能代理都能在同一套工作流里衔接；Windows、macOS 与 Android 共享核心能力，不登录也能先使用本地工具。

## ✨ 一套完整的创作流程

| 你要做什么 | NAI Launcher 可以怎么帮你 |
| --- | --- |
| **开始创作** | 写 Prompt、选模型和参数，加入角色、Vibe、Precise Reference 或源图。 |
| **反复调整** | 图生图、局部重绘、扩图、变体、增强，随时从历史图片取回部分参数。 |
| **批量处理** | 把多组任务交给队列，暂停、继续、排序、重试，并查看真实进度与 Anlas 消耗。 |
| **沉淀素材** | 将作品放进本地图库，把标签、Vibe 和精准参考整理成可搜索、可分类的个人资源库。 |
| **寻找灵感** | 搜索多个在线画廊，查看原始 Prompt 与生成信息，再送回生成页继续创作。 |
| **跨工具与设备** | 连接 Krita、ComfyUI 和云备份，让桌面创作流程延续到 Android。 |

## 🚀 功能全览

### 🎨 NovelAI 生成与编辑

- 支持文生图、图生图、普通 Inpaint、Focused Inpaint、Outpaint、变体和增强。
- 支持 NovelAI V5 Curated / Full、V4.5、V4 与 V3 系列常用工作流；切换模型时，可用参数、默认值、Token 上限与参考功能会跟随模型能力变化。
- 可设置尺寸、采样器、Steps、CFG、Seed、噪声计划等生成参数，并在不符合 NovelAI 请求限制时给出可用尺寸建议。
- 生成前显示预计 Anlas 消耗；可能产生费用的关键操作会单独确认，完成后自动更新余额和统计。
- 内置生成历史与预览，可以复用 Prompt、Seed、模型和部分参数，不会覆盖仍在编辑的内容。

### ✍️ Prompt、固定词与角色

- 正向 Prompt、负向 Prompt、正负面固定词和角色内容分区编辑，复杂工作流也能看清每一部分来自哪里。
- 多角色可以分别设置正负面 Prompt、参考图与画面位置，并根据当前模型处理角色数量和定位能力。
- 内置 Danbooru / e621 基础标签与别名，可离线显示补全、类型、热度和翻译；也可安装中文词库与相关标签数据包。
- 相关标签补全能继续寻找构图、服装、动作和画面元素；Danbooru 在线结果可补充较新的标签。
- 自定义标签词库、固定词和随机词库都支持分类、搜索、批量编辑与快速插入。
- 输入框右下角可切换文本／标签模式，直接编辑原文、调整权重、多选后长按标签拖动排序及撤销；简中与繁中界面在标签下显示同一份本地中文译文，其他语言只显示原文。文本模式选中完整标签时也可查看译文。
- 主提示词输入框底部可拖动调整高度，双击拖动条恢复自动增高；文本与标签模式共用高度。
- 标签可禁用后恢复，原文中的 `/*disabled:原片段*/` 会随提示词保存和云同步，但禁用内容不参与生成、有效预览和 Token 计数。这是 Launcher 编辑语法，旧版客户端及外部工具不保证识别；外部使用请在菜单选择「复制有效提示词」。
- 本地译文未命中的内容可以交给你配置的 AI 翻译服务。
- 提示词助手的反推、优化、翻译等任务支持统一设置响应等待超时，可选 1、2、5、10、15 或 30 分钟，默认 5 分钟。
- 提示词助手的提供商可独立保存自动或手动并发模式，默认自动从 5 个请求开始调整；独立标签批次并行翻译。各任务可选择模型支持的思考等级，配置统一位于「设置 → 集成 → 提示词助手」，保存在本机。

### 🧬 Vibe、精准参考与图像编辑

- Vibe Transfer 支持图片、预编码 Vibe 与 Bundle，能够调整信息提取和参考强度，并按模型复用已有编码。
- Precise Reference 可用于角色或风格参考，支持多选、批量修改类型，以及带图片的配置包导入导出。
- Vibe 与 Precise Reference 都有独立资源库，可分类、搜索、预览、批量管理，并直接送到当前生成任务。
- 重绘编辑器提供画笔、蒙版、Focused Inpaint 区域和画布扩展；也可以先让智能代理准备蒙版或扩图草稿，再由你检查后提交。
- 支持从 NovelAI 图片元数据读取模型、尺寸、采样器、Steps、CFG、Seed、角色词等内容，并选择性恢复。

### 🗂️ 本地图库与作品整理

- 扫描你指定的目录，按文件夹、相簿、收藏、Prompt 和生成信息查找作品；不会因为启动应用就盲目扫描所有图片。
- 图片详情会整理正负面 Prompt、固定词、角色词与完整生成参数，可以整组复制，也可以只取需要的部分。
- 支持批量分类、收藏、移动与删除，并提供图片对比、幻灯片、水印、打码副本和多种查看方式。
- 在“设置 → 安全与分享”中可独立开启“复制/拖拽时添加水印”，使用已保存的默认水印方案生成输出副本，不修改原图。添加水印不会清除元数据；如需清除，请同时开启保护模式及“复制/拖拽时移除全部元数据”，处理顺序为先清除、再加水印。
- 桌面端提供右键、悬浮预览和拖拽，触屏端提供对应菜单；核心操作不会因为换到手机就消失。
- 本地图片可以直接发送到生成页、智能代理或 Krita，省去重复保存和选择文件。

### 🔎 在线画廊与灵感收集

- 聚合 Danbooru、Safebooru、Gelbooru、AI TAG 与法典图鉴（NovelAI QuickTagCloud）。
- 根据来源提供搜索、热门、随机、排行榜、日期、内容分级、黑名单与输出过滤，不把不支持的筛选硬套到所有站点。
- 支持本地收藏；登录 Danbooru 或配置 Gelbooru API 后，还可以使用对应的账号能力。
- 可查看多图作品、原始 Prompt 和结构化生成信息，整组下载，或把可识别的参数送回生成页。
- 法典图鉴支持公开法典、分类、版本、多图与纯文本词条、贡献者信息和最近浏览。

### 🤖 智能代理

- 在桌面侧栏或移动端抽屉中对话，让代理查询标签、整理 Prompt、查看生成历史、操作资源库并准备生成任务。
- 图片、Vibe 和 Precise Reference 可以直接作为上下文加入会话；代理也能准备重绘蒙版、扩展画布与重绘草稿。
- “准备任务”和“真正生成”严格分开：准备阶段核实费用；完全访问模式下，已核实为零 Anlas 的生成直接执行，删除与付费操作仍需确认。
- 默认角色调查流程会结合联网身份核实、标准标签检索和画廊特征；联网关闭或证据不足时会说明限制。
- 系统提示词可直接用自然语言补充要求或替换内置正文，无需占位符。工作目录、联网状态、Skills 和应用执行规则自动补充，并可预览最终内容；自定义不会绕过应用权限确认。
- 支持逐题回答的结构化提问：每题三个可行方向、一个“推荐”标记和一个自定义入口，最后统一检查并提交。默认两分钟未提交会自动采用全部推荐选项；提问时显示 Toast、入口问号和 Android 系统通知。
- 支持 OpenAI 兼容接口、Google Gemini 原生接口、第三方 Gemini 兼容中转与 OpenRouter；可获取模型列表，并按模型能力启用思考等级和工具调用。
- 模型服务、API Key、可用地区和费用由你选择的提供方负责；联网搜索等额外工具默认关闭。

### 📋 队列、历史与统计

- 生成任务可以批量加入队列，支持暂停、继续、调整顺序、取消和重试失败任务。
- 运行中可以查看单项状态、整体进度和失败原因，不需要守着每一次请求。
- 统计页面按时间、尺寸、采样器、模型与 Anlas 消耗回顾创作记录，帮助了解自己的常用设置。

### 🧩 Krita 与 ComfyUI

- **Krita Bridge**：把 Krita 画布送到 Launcher 生成或重绘，并将结果送回 Krita。
- **ComfyUI**：连接本地服务器，执行常规超分或 SeedVR2 工作流；服务器模型与自定义节点仍由你的 ComfyUI 环境负责。
- **DLSSNR 图像增强（Windows）**：在“设置 → 集成 → DLSSNR”按需安装公开运行库并检测 NVIDIA GPU；支持生成后自动增强（默认关闭）、图片卡片手动增强与拖动分割线对比；共用对比组件支持“跟随鼠标”开关，便于放大后比较局部，开关偏好在本机保存。SR 放大倍率默认 2 倍，可手动输入；SR 放大后执行单次 NR，再完成增强与颜色混合。图生图“放大”也提供 DLSS SR 入口，最终结果不混入 NR，但当前运行库仍会计算一次 NR。提供 7 套内置风格预设，默认使用“质感光影”，另有“保色增强”“浓郁”等风格可选；可另存、重命名和删除自定义预设；当前选择和调整自动保存。参数附带说明和数值输入。图像在本机处理，手动保存创建新文件，不覆盖原图。
- 从图库、预览和编辑流程都能进入这些工具，不必每次手动导出再重新选文件。

### ☁️ 同步与备份

- 支持 OneDrive、GitHub 与 WebDAV；Google Drive 因授权审核尚未通过，暂时禁用新增连接入口。连接账号不会自动上传、下载或覆盖内容。
- 推送、拉取和恢复都由你主动开始，并可预览差异与处理冲突。
- 可分别选择设置、Prompt 与词库、词库预览图、在线画廊设置与收藏、本地相簿、智能代理 Prompt 与 Skill，以及可选的 Vibe、Precise Reference。
- 本地图库原图、远程图库原图、账号凭据、缓存和日志不会进入备份。
- 备份使用便于查看和迁移的明文数据，不需要额外恢复密钥；请自行确认目标空间的访问权限。

## 🖼️ 界面预览

### 🖥️ 桌面端

<table>
  <tr>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-generation-desktop.png" alt="生成工作台与智能代理" width="100%"><br>
      <sub>生成工作台：Prompt、参数、预览与智能代理同屏协作</sub>
    </td>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-local-gallery-desktop.png" alt="本地图库" width="100%"><br>
      <sub>本地图库：搜索、相簿、文件夹与批量整理</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-online-gallery-desktop.png" alt="在线画廊" width="100%"><br>
      <sub>在线画廊：多个来源、筛选与瀑布流浏览</sub>
    </td>
    <td width="50%" align="center">
      <img src="docs/screenshots/overview-statistics-desktop.png" alt="统计仪表盘" width="100%"><br>
      <sub>统计仪表盘：作品、参数与 Anlas 使用情况</sub>
    </td>
  </tr>
</table>

## 💻 支持平台

| 平台 | 当前状态 | 说明 |
| --- | --- | --- |
| **Windows** | 主要开发与发布平台 | 提供安装版和便携版，适合长时间创作、批量任务以及 Krita / ComfyUI 联动。 |
| **macOS** | 可用，持续完善中 | 提供便携版；若系统阻止打开未公证应用，请按 macOS 安全提示手动允许。 |
| **Android** | Beta | 支持手机、横屏、平板和大屏；生成、图库、词库、队列、代理与设置均有触屏入口。 |
| **Linux** | 暂无正式发行包 | 当前不提供正式下载包。 |

## ⚡ 下载与开始使用

### 1. 下载对应平台的安装包

前往 [GitHub Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/latest)：

| 平台 | 文件 | 用法 |
| --- | --- | --- |
| Windows | `NAI_Launcher_Windows_<version>_Setup.exe` | 推荐给大多数用户的安装版。 |
| Windows | `NAI_Launcher_Windows_<version>_Portable.zip` | 解压后直接运行的便携版。 |
| macOS | `NAI_Launcher_macOS_<version>_Portable.zip` | 解压后打开 `Aaalice NAI Launcher.app`。 |
| Android | `NAI_Launcher_Android_<version>.apk` | 侧载 APK；首次安装可能需要允许当前应用安装未知来源软件。 |

每个 Release 都会提供 `checksums.txt`。如果下载后无法解压或安装，可以先核对文件校验值。

### 2. 登录 NovelAI

可以使用 NovelAI 账号密码或 **Persistent API Token** 登录。如果网页安全验证导致密码登录失败，建议改用 Persistent API Token。Token 只保存在当前设备的安全存储中。

### 3. 设置常用资源

- 在“设置”中选择本地作品目录，进入本地图库后开始扫描。
- 在“设置 → 数据源与缓存”中管理中文词库、相关标签数据包和在线缓存。
- 需要 Krita 联动时，先启用 Krita Bridge，再按照 [Krita 插件说明](krita_plugin/README.md) 安装插件。
- 需要 ComfyUI 时，在“设置 → ComfyUI”中填写本地地址并选择工作流。
- 需要跨设备使用时，在云同步页面连接一个备份目标，并认真确认要同步的内容。

## 🔒 数据与隐私

NAI Launcher 不在项目自有服务器上托管你的账号或作品。只有在你主动使用对应功能时，数据才会发送给相关服务：

| 使用的功能 | 数据会发送到哪里 |
| --- | --- |
| 生成、图生图、重绘、Vibe 编码 | NovelAI；包括本次请求所需的 Prompt、参数和源图或参考图。 |
| 在线画廊搜索与下载 | 你选择的第三方图库；可用性、限流和内容规则由各站点决定。 |
| AI 翻译或智能代理 | 你配置的模型服务；对话、附加图片和完成任务所需的工具结果可能产生服务费用。 |
| 同步与备份 | 你选择的 Google Drive、OneDrive、GitHub 或 WebDAV；只上传明确勾选的内容。 |

- NovelAI Token、OAuth access/refresh token、WebDAV 密码和 GitHub Token 使用设备安全存储，不会写入备份。
- 本地 Prompt、图库索引、标签、资源库和代理会话默认保存在本机。
- 云备份以明文保存所选数据；本地图库的图像本体不上传，相簿、分类和成员引用可作为轻量数据同步。
- 在线画廊可能包含第三方内容；分级筛选不能替代用户判断。
- WebDAV 的安全性取决于你配置的服务器与传输方式，请保留重要数据的本地副本。

## 🆘 支持与反馈

- 如遇异常，请通过“设置 → 关于 → 导出诊断日志”保存排查信息，并在反馈时一并提供。
- [提交 Issue](https://github.com/Aaalice233/Aaalice_NAI_Launcher/issues)：报告可以复现的问题或提出功能建议。
- [加入 Discord](https://discord.gg/R48n6GwXzD)：交流使用经验、获取社区帮助。
- [查看 Releases](https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases)：下载版本、校验文件并阅读更新内容。

## 🙏 致谢

感谢 [NovelAI](https://novelai.net/)、[法典图鉴](https://novelai.quicktagcloud.com/)、[AgIzT/NovelAI-Tag](https://github.com/AgIzT/NovelAI-Tag)、[Flutter](https://flutter.dev/)、[Riverpod](https://riverpod.dev/) 以及所有贡献者和测试用户。

## 📄 许可证

本项目基于 [MIT License](LICENSE) 开源。
