# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

主要用户是长期使用 NovelAI 的创作者。他们会持续迭代 Prompt、角色和生成参数，进行批量生成与图像编辑，并需要在同一工作流中整理作品、复用素材、查找参考和回顾创作数据。

桌面端面向长时间创作、批量处理以及 Krita / ComfyUI 联动；Android 面向手机、横屏、平板和大屏上的连续创作、浏览与资源管理。

## Product Purpose

NAI Launcher 是面向 NovelAI 的第三方跨平台客户端。它将图像生成与编辑、Prompt 编写、标签与参考资源、本地及在线画廊、生成队列、统计、智能代理和外部创作工具连接到一个连续工作流中。

产品成功意味着创作者能够减少工具与页面之间的重复搬运，在不放弃本地数据控制和各平台操作效率的前提下，完成从灵感检索、Prompt 准备、生成与编辑到作品整理和再次复用的完整过程。

## Positioning

NAI Launcher 的核心定位是**本地优先的一体化 NovelAI 创作工作台**。它不是单一的 NovelAI API 前端，而是以可复用的 Prompt、标签、参考资源、生成历史和本地作品为共同上下文，把生成、编辑、整理、探索、Agent 协作以及 Krita / ComfyUI 工作流连接起来。

## Operating Context

- 用户使用自己的 NovelAI 账号，通过账号密码或 Persistent API Token 登录；未登录时仍可使用本地图库、词库、资源库和设置。
- 典型流程是准备 Prompt、角色、参数和参考图，提交生成或队列任务，查看结果并继续进行图生图、Inpaint、放大、Director Tools、收藏、保存或素材复用。
- 用户可扫描本地作品，按 Prompt、元数据、日期、收藏、分类和集合进行检索与批量管理。
- 用户可在 Danbooru、Safebooru、Gelbooru、AI TAG 和 NovelAI QuickTagCloud 等来源中寻找参考，并使用内容分级、黑名单和输出过滤。
- 用户可维护标签、固定词、随机词库、Vibe 和 Precise Reference 等可复用资源。
- 智能代理可协助检索标签、整理 Prompt、查看历史和准备生成，但不能绕过业务服务或用户确认。
- 桌面端可连接 Krita Bridge 与本地 ComfyUI；同步与备份通过用户配置的 Google Drive、OneDrive、GitHub 或 WebDAV 存储完成，数据传输由用户显式触发。

## Capabilities and Constraints

- 支持文生图、图生图、Inpaint、Focused Inpaint、Outpaint、放大与增强、Vibe Transfer、Precise Reference、多角色提示词和独立负面提示词。
- Prompt 工作台支持标签自动补全、权重语法、Token 统计、固定词、随机词库以及 Prompt 导入导出。
- 本地图库、在线画廊、生成队列、统计、标签库、Vibe 库和 Precise Reference 库构成长期维护的核心能力。
- Windows 是主要开发与发布平台，提供安装版与便携版；macOS 提供便携版并持续完善；Android 当前为 beta；Linux 暂无正式发行包。
- 桌面端与 Android 必须保持业务能力、字段语义、状态和操作结果一致；平台差异集中在导航容器、输入方式和平台 capability/service 层。
- 本地图库按需扫描，不能仅因应用启动就扫描全部文件。基础标签库随应用提供并可离线使用。
- 生成、Vibe 编码、Inpaint、Director Tools、云端放大和队列启动等任何可能消耗 Anlas 的操作，都必须单独取得用户确认并显示预计消耗。
- NovelAI Token、WebDAV 密码、GitHub Token、API key 和其他凭据使用设备安全存储，不得进入备份或同步数据。
- 同步与备份只处理用户明确选择的数据范围；缓存、索引、队列状态和设备专属配置不作为可同步产品数据。
- 在线画廊内容与可用性受第三方来源的授权、限流、内容规则和当地法律约束；产品不得把第三方内容授权扩大解释为可重新分发或镜像。
- 项目不在自有服务器托管用户账号或作品。发布包提供校验信息供用户验证完整性。
- 用户界面提供简体中文、繁体中文、English 和日本語。

## Brand Commitments

- 用户可见产品名称为 **NAI Launcher**；仓库和平台工程使用 **Aaalice NAI Launcher** 标识。
- 产品必须明确声明自己是 NovelAI 的第三方客户端，而非 NovelAI 官方产品。
- 产品图标位于 `assets/icons/Icon.png`，各平台图标从 `assets/icons/` 及对应平台工程维护。
- 面向用户的表达保持直接、清楚、可操作，不夸大功能、授权、隐私或平台支持状态。
- 项目基于 MIT License 开源；第三方数据、代码和资源继续遵守 `THIRD_PARTY_NOTICES.md` 及各自许可证。

## Evidence on Hand

- 三语用户说明与公开承诺：`README.md`、`README.zh-TW.md`、`README.en-US.md`。
- 产品界面素材：`docs/screenshots/`；只以实际文件和截图内容说明对应场景，截图不保证代表当前代码或全部平台。
- 产品与平台图标：`assets/icons/`、`windows/runner/resources/app_icon.ico`、`macos/Runner/Assets.xcassets/AppIcon.appiconset/`。
- 功能与页面边界：`lib/presentation/router/app_routes.dart`、`lib/presentation/router/app_router_config.dart`、`lib/presentation/screens/`。
- 平台适配依据：`lib/core/platform/platform_capabilities.dart`、`lib/presentation/router/desktop_shell.dart`、`lib/presentation/router/mobile_shell.dart`。
- 本地化源文案：`lib/l10n/app_en.arb`、`lib/l10n/app_zh.arb`、`lib/l10n/app_zh_Hant.arb`、`lib/l10n/app_ja.arb`。
- 产品图标、真实界面截图和开源仓库可作为当前证据；仓库没有可供引用的客户名单、商业客户案例、媒体报道、独立基准或用户评价，未来界面与文案不得虚构这些内容。

## Product Principles

1. **连续创作优先**：减少 Prompt、参数、参考图、作品和外部工具之间的重复搬运，让用户始终保留当前创作上下文。
2. **本地数据优先**：本地作品、Prompt、资源和会话默认由用户设备持有；联网、同步和第三方服务保持明确且可控。
3. **成本必须可见**：所有可能消耗 Anlas 或第三方模型费用的操作在执行前说明结果与成本，并取得明确确认。
4. **跨端能力等价**：桌面与 Android 共享业务事实和完整能力，同时采用符合指针、键盘或触屏习惯的原生入口。
5. **来源与边界透明**：清楚标明第三方客户端身份、内容来源、授权范围、平台状态和数据接收方，不用模糊承诺替代事实。

## Accessibility & Inclusion

- 共享功能必须同时支持桌面指针与键盘操作，以及不依赖 hover、右键或外接键盘的移动端触控操作。
- 自定义控件需要可理解的语义、焦点顺序、禁用状态以及 Enter / Space 等键盘行为；重要状态不能只依赖颜色表达。
- Android 触控目标优先达到 48×48 logical pixels，最低不小于 44×44；桌面点击目标通常不小于 40×40。
- 布局需支持 SafeArea、系统返回、软键盘、横竖屏、文本缩放和不同窗口宽度，并保持输入、选择、滚动位置和任务状态。
- 文本与背景至少满足 WCAG AA 对比度目标；简体中文、繁体中文、English 和日本語文案长度变化不得造成关键内容裁切或功能缺失。
