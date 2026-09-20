# iOS v3 移栽计划（v1.8.1 → v4.2.1）

> ultracode 工作流产出：5 条调研 + 4 条审计（每条带对抗式复核）+ 汇总，14 agent / 235 万 token / 952 次工具调用。
> 上游 v1.8.1..v4.2.1 = 693 提交 / 2578 文件 / +568596 −174623；我方 ios-v2 相对 v1.8.1 = 173 文件，其中 108 个上游也改过。

## 策略

证据支持「从 v4.2.1 起新分支」，不支持「把 173 文件 diff 搬过去」。理由是三条已亲自核对的硬事实：(1) E:/DEV/nai/reference/upstream_v421/lib/presentation/router/app_shell.dart:283-302 的壳选择是纯宽度判定（safeUsableWidth → WindowSizeClass.fromWidth → isExpandedOrWider ? DesktopShell : MobileShell），全链路零 Platform 判断；(2) lib/presentation/adaptive/ 五个文件全目录 grep `Platform.` 零命中，InteractionPolicy 按实际 PointerDeviceKind 推导；(3) lib/core/platform/platform_capabilities.dart 的 17 个能力位把 iOS 正确归入 isMobile，上游 lib/ 内 `Platform.is*` 只剩 main.dart。也就是说上一轮我们花七条车道从零做的「移动端适配」，上游在 v3.0.0→v4.2.1 用 adaptive 层 + 能力矩阵系统性做掉了，而且对 iOS 是免费的。四条审计交叉核对后，我们 173 文件里约 55-60% 判为 superseded/obsolete，其中 6 个我们改过的文件上游已删除（folder_tabs.dart、vibe_library_screen_layout.dart、post_detail_dialog.dart、ai_tag_detail_dialog.dart、app_router.dart、prompt_input.dart 的大部分），按行号重放不可能。

因此 ios-v3 的做法是：在 E:/DEV/nai/nai_launcher 从 tag v4.2.1 新建分支，只加三类东西 —— ①上游完全没有的 iOS 平台工程与 CI（上游无 ios/ 目录、无 iOS workflow，这部分 100% 是我们的）；②上游写死成 `isAndroid` 而 iOS 落进坏分支的能力缺口（FileExportService 在 iOS 必抛 ArgumentError、supportsDocumentFileExport/supportsManagedFileImports、云盘 OAuth 枚举漏 iOS、tagger 目录指向「文件」App 不可见的 Application Support）；③用户的偏好定制。不做 rebase、不做 cherry-pick、不做三方合并——上游 693 提交 2578 文件，任何自动合并都会在 108 个重叠文件上产生无法审查的冲突面。

但有一条重要修正：不能把「上游做了移动端」简化成「上游的移动端就是我们要的移动端」。四条审计的对抗复核共改判 22 条，改判模式高度一致——审计只核对了「上游有同名实现」，没核对默认值、拦截行为、入口数量和槽位分配。最典型的是生成页抽屉槽位：上游 mobile_generation_chrome.dart:239-240 是「左=参数面板 / 右=历史」，我们是「左=快捷工具（固定词+角色开关）/ 右=参数」，这是同一个 Scaffold 的同一组 slot，照搬上游 = 用户点名的左侧边栏静默消失且参数面板左右翻转。所以 ios-v3 的工作量不在「搬代码」，在「在上游的新结构上把 30 条偏好重新落位」，每条都要先确认上游的锚点在哪、默认值是什么、会不会被上游的新行为覆盖。

## 用户已拍板的决策（2026-09-20）

| # | 问题 | 决定 | 对计划的影响 |
| --- | --- | --- | --- |
| 1 | 底栏与「更多」形态 | **跟上游**：5 Tab（生成/图库/探索/词库/更多）+ 底部弹出面板 | L1 navshell 相关改动基本全丢（`nav_links.dart` 253 行、`mobile_bottom_nav_bar.dart`、`more_screen.dart`、`app_branch.dart` 的 4-Tab 映射）。**但两条必保要挂回上游结构**：① 一键深浅主题切换 `toggleQuickTheme` 挂到 `mobile_more_panel` 的 `_MobileMoreDestination`；② 底栏重按当前 Tab 回根路由，在上游 `mobile_shell.dart:186-200` 的 `_onNavigate` 补 `initialLocation: index == currentIndex` |
| 2 | 本地图库分组 | **迁到上游相簿**，但**先修迁移** | 我们的集合筛选抽屉整套丢弃（`collection_filter_drawer.dart` 326 行 + `gallery_filter_service.dart` 的 collectionId/collectionFileNames 数据层）。**前置硬约束**：`gallery_album_import_coordinator.dart:150-167` 的迁移读绝对路径，iOS 重装后 `getImageIdByPath` 与 `File.exists` 双双失败、只打一行日志就 skip。必须先加 basename/相对路径回退匹配，并核实 `gallery_image_repository` 的 `images.file_path` 存的是绝对还是相对路径（若为绝对，重装后相簿会全空）。此项列为 L6 的第一步，且必须进 L15 真机覆盖安装验证 |
| 3 | ComfyUI 移动端 | **跟上游**，手机上禁用 | 丢弃我们的有意偏离（`supportsComfyUiIntegration => isDesktop` 原样采用，`comfyui_settings_section.dart` 的局域网 helperText 一并丢）。**注意**：`NSLocalNetworkUsageDescription` 仍必须保留——3D 模型编辑器走 127.0.0.1 本地 HttpServer，与 ComfyUI 无关 |
| 4 | 明文 HTTP | **加 `NSAllowsArbitraryLoads`**，全部放行 | 内网穿透 / 公网域名反代 / 自定义 API base URL 的 http:// 地址都能连。与 Android 的 `usesCleartextTraffic="true"` 对齐。未签名自用分发无审核风险 |

### 未询问、按默认推进的假设（如有异议随时改）

- **Share Extension 不做**。需独立 target + 独立 bundle ID + App Group，而 App Group 在免费 Apple ID 的 free provisioning 下不可用，自签工具多数会剥掉 `PlugIns/`。改做零签名代价的 `CFBundleDocumentTypes(public.image)` + 已有的 `LSSupportsOpeningDocumentsInPlace`，app 会出现在「文件」App 和图片的「用其他 App 打开」列表里；顺带用 `UTExportedTypeDeclarations` 声明 `.naiv4vibe`/`.naiv4vibebundle`，修掉「Vibe 文件在 iOS 选不到」那条旧账
- **Google Drive / OneDrive 云同步在 iOS 不做**。落到 `unsupported`（不崩，显示未配置）。GitHub/WebDAV 在 iOS 完整可用。只需确认这两个 provider 入口是隐藏而非留死按钮
- **画廊窄屏列宽保留我们的 110**（390pt 手机 3 列），不跟上游的 160（2 列）
- **`assetProtectionMode` 默认值不动**（保持上游的 false）。我们的顶栏 clean 按钮绕过它，日常复制不受影响
- **CI 保留 2 个删 4 个**：留 `android-build`（验证我们改的 lib/ 没破坏移动端的唯一手段）和 `windows-portable`（均纯手动、零成本）；删 `online-gallery-live-contract`（cron 烧分钟）、`release`（监听 push v* 会与 ios-v* 撞车且跑 windows+macos）、`pull-request-validation`（三个 windows-2022 分片最贵）、`cooccurrence-data-pack`（`contents: write` 会往 fork 发 Release）
- **把我们 20 个文件里的 65 行 `Platform.is*` 翻译成 `PlatformCapabilities`**。与上游纪律一致，后续移栽冲突面小得多，上游新增的一批 widget test 能用 `debugOverride` 覆盖
- **暂留私有仓库 `f1luct/nai-launcher-ios`**。f1luct 对上游是 `push: false` 且无待接受邀请，上游 `ios` 分支是落后 996 提交的空占位。fork 已建：`f1luct/Aaalice_NAI_Launcher`。有 5 条是上游同样存在的缺陷、适合回馈（角色定位画布编号错位、词库卡片 `onSend` 死回调、取色器只有 onPan 没有 onTapDown、`image_preview.dart:838` 的 `onSendToKrita` 漏门控、`agent_question_notification_service.show()` 不检查 `_supported`）

## 进度日志

### 批次 1（commit `f401edb7`）— L0 + L1 平台工程与流水线

`ios-v3` 从 v4.2.1（`eede51e0`）开出。ios/ 28 文件整入，逐字节比对 27 个与 ios-v2 一致，
唯一改动的 `Info.plist` 是按用户 4 条决策做的增量。workflow 删 4 留 2 加 1。

踩坑记录：
- **`git archive` 会触发 LFS smudge**。v4.2.1 起 `tag_catalog.db` 是 133 字节指针，而我们从没用
  `--no-verify` 以外的方式推过 LFS 对象，私有仓库上不存在该对象 → 404。
  同步到 Mac 必须用 `git -c filter.lfs.smudge= -c filter.lfs.process= -c filter.lfs.required=false archive`，
  真实 db 在 Mac 上按 `manifest.json` 的 release URL 直接 curl（带 size + sha256 校验）。
- **推送被 GitHub 连续掐断十几次**，看着像网络问题，实际是**历史里有 merge 提交**：
  `git rev-list A..B` 返回的提交**不一定是 A 的后代**，按它分段推会被判 non-fast-forward
  （而错误信息在连接断掉时看不见，表现为"推了但没进展"）。
  正解是 `git rev-list --reverse --ancestry-path $REMOTE..$BRANCH` 取检查点，每轮推 30 个，14 轮推完。
- **`gal` 会连带改写受版本控制的 Windows 插件注册表**（`windows/flutter/generated_plugin_registrant.cc`
  与 `generated_plugins.cmake`）。不提交的话 `android-build.yml` 的 `git diff --exit-code` 必红。
  副作用：本 fork 的 Windows 构建从此要编译 gal 的 C++20/WinRT 插件（未验证，本机无 VS 工具链）。
  想去掉的话，可用约 40 行 Swift 的 `PHPhotoLibrary` method channel 替掉 gal，依赖与 Windows 污染一起消失。

### 批次 2（commit `ce296862`）— 8 条车道并行

L2 能力矩阵与导出链路 / L4 生成页左抽屉 / L6 画廊相簿迁移与左抽屉 / L7 移动端默认值 /
L8 提示词 raw 直填 / L10 触屏可达性 / L11 剪贴板与图片导入 / L14 3D 编辑器触屏。
73 文件 +3981/−339，`flutter analyze` 干净。

集成阶段由主控修掉的两条（8 个车道 agent 都没发现，靠交叉自检 agent 抓出来）：
- **`MobileWorkflowPanelReveal` 建了注册点但全仓无任何 `register()` 调用方**。
  `request()` 在无注册者时是空操作，所以**编译通过、运行不报错、手机上点「放大 / 增强」屏幕毫无反应**
  ——必保定制 #24 等于没做。已接到 `MobileGenerationController` 的构造与 `dispose`
  （存成字段供 `identical` 比对）。这类跨车道断链是本方法论的固有风险，交叉自检不能省。
- **导入来源面板被 L4 与 L11 各实现一份**，L11 那份生产零引用（只有它自己的测试在用）。
  已删 L4 的私有版本，统一走 L11 的公开 API `showMobileImageMetadataImportSheet`。

**l10n 合并模式**（下次沿用）：8 个 agent 并发改同一份 arb 必然互相覆盖，所以各车道把新 key 写进
`lib/l10n/fragments/<lane>.json`（四语 + description），主控统一合并后跑 `gen-l10n` 并删除该目录。
注意必须**四份** arb 一起写——`app_zh_Hant.arb` 也在 `i18n_regression_test` 的 parity 断言里
（计划表原先漏了它）。

### 工作流的实质变化：本机不能再跑测试

`nai_png_codec` 的 native assets 会在**每次 `flutter test` 调用**时构建，而 `native_toolchain_c`
在 Windows 上找 `vswhere.exe` 失败——本机没有 VS C++ 工具链且无管理员权限。
上一轮 2381 个测试全是本机跑的，现在 **analyze 仍可本机跑，test 必须上 Mac**（clang 17）。

### Mac 构建自检结果（2026-09-20）

| 项 | 结果 |
| --- | --- |
| `flutter build ios --release --no-codesign` | **EXIT=0** |
| `Runner.app` | 172 MB |
| **`nai_png_codec.framework`** | **存在**，174,080 字节，arm64 |
| install name | `@rpath/nai_png_codec.framework/nai_png_codec` |
| 签名 | `adhoc`（`--no-codesign` 下的预期形态） |
| framework MinimumOSVersion | 13.0（flutter_tools 硬编码，低于工程的 16.0，无害） |
| `onnxruntime` | 符号**静态链进主二进制**（`otool -L` 无动态引用，`nm -u` 19 个 ORT 符号） |
| Xcode / Flutter | 16.4 / 3.44.2 |

**硬风险 #1（native assets 在 iOS 上的构建链路）已证伪，不再是风险。**
`hook/build.dart` 无平台分支、源码已 vendored 在 `src/vendor/`（不联网），Flutter 工具链
自动把 `libnai_png_codec.dylib` 包成 framework 并 ad-hoc 签名。
**硬风险 #10（onnxruntime_v2 的 iOS 支持）同时证伪**——本地反推与魔棒抠图不会丢。

## 上游新功能（按主题）

### 自适应呈现层与移动端骨架（v3.0.0-v4.0.0 的地基，iOS 白捡）
- lib/presentation/adaptive/ 五件套：WindowSizeClass 按安全可用宽度分 compact/medium/expanded/wide（600/840/1180）；InteractionPolicy 按本会话观察到的输入设备决定触屏/指针形态，且「观察到触屏后即使后来接鼠标也保留 48pt 触摸目标」；AdaptivePresenter 统一 showForm/showPicker/showPanel；ContentSizedAdaptiveForm 按内容收缩
- PlatformCapabilities 能力矩阵：17 个开关集中一处，把平台判断赶出功能屏幕
- MobileShell + 底部 NavigationBar（5 Tab）+ 「更多」底部面板；键盘弹出或全屏编辑时底栏整体撤掉（mobile_shell_overlay_provider，24 行换 64-84pt 竖直空间）
- 生成页移动端重构：专用工作区 + 全屏提示词编辑器 + 角色管理 sheet + 纵向手势 + 软键盘/返回处理
- 4.0.2 的一整批大字号/短屏幕/键盘弹出弹窗溢出批量修复（16 个对话框），4.2.1 的生成按钮与额度栏自适应
- 移动端 imageCache 收紧到 120 张/64MB（main.dart:595 已含 iOS）

**iOS**：全部开箱可用，是本次最大收益。唯一冲突点：iPhone 恒走 MobileShell、iPad 横屏（≥840pt）走 DesktopShell，与我们旧的 800 断点（responsive.dart，不扣 safe padding）在 800-840 区间给相反答案 —— 删掉 responsive.dart 全面改用 adaptiveWindow。底栏 Tab 数与「更多」形态需用户拍板。

### 智能代理 Agent（v3.0.0 引入，四个版本持续加厚）
- 全局多轮对话代理，可查看调整 Prompt/角色/生成参数/参考图/词库/队列/画廊；会话历史、资源引用、工具审批、Skills、自定义系统提示词、多模型思考参数
- 联网工具（SearXNG / 匿名 Exa MCP / Exa API），默认关闭，所有 Anlas 消耗单独确认
- 图片操作补全：收藏、词库缩略图、图生图、局部重绘、增强、超分、变化图、Director Tools；自动创建重绘蒙版与扩展画布
- Gemini 3.8 Flash 兼容、可搜索模型选择器、自定义上下文窗口、斜杠命令、会话压缩、阅读字号与密度设置
- v4.2.0 逐题回答的问题表单（默认等两分钟，到期采用推荐项）
- v4.2.1 代码块快捷复制、诊断日志含脱敏权限审计线索

**iOS**：UI 与网络层全部可用，SafeArea 处理对刘海/Home Indicator 直接适用。两处缺失：①切后台后 Agent 轮次会被系统挂起（Android 有 GenerationForegroundService，iOS 无对等）；②问题表单的「系统通知返回」硬编码 Platform.isAndroid，iOS 上切走后没有提醒、两分钟后静默采用推荐项。另外 agent_question_notification_service.dart 的 show() 没检查 _supported，iOS 上会先弹「已通知你」再弹「通知不可用」两条打架的 toast。

### 提示词系统（v3.1.0-v4.2.1 改动最密集的区域）
- 文本↔标签模式切换：标签模式可看本地中文译文、编辑标签、拖拽排序、框选多选，保留权重分组与嵌套强调；各编辑区独立记住模式与手动高度
- 提示词单个/批量启用、禁用、删除与成组调权；禁用内容保留在编辑器但不计入有效提示词，配套「复制有效提示词」
- 提示词工作台本地快速汉化预览（本地词典优先，未命中才交给 AI）
- 助手统一为编辑区内展开工具栏，按服务商配置并发、分任务思考等级、统一响应超时（默认 5 分钟）
- 随机词库完整还原 NovelAI 官网数据（v4.0.0 移除混合模式，破坏性变更）
- 角色独立负面提示词语法、多角色面板独立折叠记忆、NovelAI 多角色粘贴导入、WebP 元数据读取、artist: 前缀补全
- 固定词侧栏按分类折叠/仅看启用/常驻行内操作；固定词与元数据统一走支持嵌套权重的解析
- 中日文 IME 预编辑下划线标识；手机自动补全候选框与软键盘位置一致性修复

**iOS**：绝大部分可用，中日文 IME 那条对 iOS 价值极高。两点要实测：标签模式的框选（marquee）在触屏上与滚动手势的仲裁；上游补全弹层的键盘避让（autocomplete_wrapper.dart:536-539）是我们实现的严格超集，直接采用。「复制有效提示词」这个新概念要确认不与我们的复制偏好打架。

### 资料库统一工作区与图库（v3.2.0-v4.2.1）
- Vibe 库 / 精准参考库 / 词库 / 本地图库合并为共享的 GalleryCollectionWorkspace：统一搜索排序、视图切换、分类侧栏、悬浮预览、卡片操作
- 本地画廊可嵌套逻辑相簿：子相簿、拖拽或批量加入、重命名、调层级；只管引用不动原文件，成员按相对图库根目录记录并有 pendingPaths 自动补绑
- 相簿树与分类树三槽拖放排序 +「移到上一级」触屏入口；v4.2.1 加侧栏排序（原有顺序/名称/数量）与拖动调宽按设备记忆
- 统一卡片多选交互：桌面 Ctrl/Cmd/Shift/Ctrl+A/Esc，触屏长按多选 + 卡片常驻 more 菜单
- 批量标签编辑、详情页重构（分类展示+缩略图栏）、一键复制全部 TAG 并按类别精确选择
- 高级筛选/收藏筛选组合失效的修复；悬浮预览改显示实际像素尺寸

**iOS**：触屏路径上游明确实现了（usesTouchActionMenu → 卡片上常驻 more 按钮），长按仍是进多选，与我们「长按弹 sheet」的方案互斥，采上游。但「常驻侧栏」只在 ≥840pt 出现，iPhone 上分类入口走 AdaptivePresenter 底部面板——这正是用户左侧边栏偏好的冲突点。另：旧集合→相簿的一次性迁移读的是绝对路径，iOS 重装后会整体丢成员，见 blockers。

### 分享、导出与元数据（用户偏好的核心战场）
- Discord 社区分享：浏览器成员验证、多频道、附言、提示词类别编辑、发送偏好记忆、任务进度与仅重试失败目标；默认移除元数据
- ZIP 导出元数据选项：可仅对压缩包副本移除 PNG 文本/EXIF/NovelAI 隐写元数据，后台流式、逐图进度
- 安全复制正面提示词（按主体/角色/质量词/固定词选择范围，默认排除固定词与自动质量词）
- v4.2.1 新增「复制/拖拽时添加水印」开关，默认关闭，与保护模式正交（加水印不清元数据）
- PNG 清除元数据时保留 16 位精度与 APNG 帧/时序/循环；EXIF 方向修复；临时文件释放时机改善
- v4.2.1 Android 接收从 Discord 等应用分享的单图或图片直链

**iOS**：Discord 分享经核实不是 Android 独占（relay 轮询 + url_launcher，零平台门控），iOS 可用。但全部清除元数据的链路底层都是 packages/nai_png_codec 这个 C 包，native assets 在 iOS 上打不通就全断——包括用户最在意的「复制不带元数据」。接收外部分享 iOS 完全缺失（app_shell.dart:252-256 的三元里 iOS 什么都不挂），需 Share Extension，见 openQuestions。落地导出 iOS 无 SAF，FileExportService 目前在 iOS 必抛异常。

### 云同步与备份（v3.0.0 起，v4.x 大改）
- GitHub / WebDAV 手动推送拉取，完整性校验快照、历史与恢复、逐项冲突处理；凭据与 NovelAI Token 不进备份
- v4.0.0 新增 Google Drive / OneDrive
- 细粒度内容选择：设置、提示词与词库、词库预览图、在线画廊设置与收藏、本地相簿、Agent 提示词与 Skill，Vibe 与精准参考默认关闭
- 内容寻址精简备份：复用未变化内容、并行分块、分阶段进度；v4.1.0 合并传输小对象
- 统一为明文快照（移除恢复密钥/KEY 文件），补充登录过期/权限/配额/限流/冲突的明确提示
- GitHub 空仓库初始化与快照清单/HEAD 提交修复

**iOS**：GitHub 与 WebDAV 在 iOS 完整可用（纯 HTTP + flutter_secure_storage 走 Keychain），是 iOS 上唯一能用的两条。Google Drive/OneDrive 在 iOS 是 blocked：cloud_drive_oauth_config.dart 的枚举只有 {android,macos,windows,unsupported}，detectPlatform() 没有 iOS 分支，diagnose() 直接返回不支持；不会崩，但永远显示未配置。代价是 GoogleSignIn 9 + AppAuth 两套 SDK 白链进包体。注意兼容警告：新版能读旧备份，旧版读不了新格式。

### 图像编辑与后处理（v3.1.0-v4.2.1）
- 跨平台水印工作室：文字+Logo、艺术字体、颜色描边阴影透明度位置，按横/竖/方图分别记忆方案；全端统一水印入口
- 图片打码编辑器（马赛克/模糊/纯色遮挡），区域移动缩放、画笔、反选、撤销重做，导出默认移除元数据
- 生成结果原图对比模式：图生图/局部重绘/云端超分/本地超分，拖动分隔线、同步缩放；v4.2.0 加「跟随鼠标」与放大后拖动检查/原尺寸/适应窗口
- Windows DLSSNR 本地增强（7 套预设、生成后自动增强、分阶段状态提示、另存加入历史）
- 局部重绘透明像素、画笔圆环跟随、外扩画布手柄误落笔等修复

**iOS**：水印与打码的 UI 纯 Dart 可用，但保存落地都调 AndroidMediaStoreService（watermark_editor_screen.dart:400、mosaic_editor_screen.dart:621），iOS 走不到，要接我们的 gal；渲染链路依赖 nai_png_codec。水印需打包 6 个字体。DLSSNR 整块走 supportsDlssEnhancement => isWindows，7 处调用点全部门控，iOS 不会留死按钮、不会崩——任务里担心的死条目经核实不存在。对比模式的「跟随鼠标」在 iOS 无指针，需确认是否按 precisePointerAvailable 门控。

### 在线画廊与探索（v1.9.0-v4.2.1 持续加厚）
- 法典图鉴 NovelAI QuickTagCloud：分类与版本浏览、多图与纯文本词条、贡献者署名、内容分级、本地收藏、最近浏览、Prompt 复制/生成/加队列
- 跨来源本地收藏 + 统一黑名单（本地/Danbooru 云端来源选择）+ 最多六 Tag 组合搜索
- 浏览会话持久化（来源/模式/搜索筛选/分页与滚动位置），v3.1.0 改为只恢复条件不恢复过期页码
- 结构化展示 AI TAG 生成信息并可选择性替换提示词、固定词与生成参数
- 性能重做：可见优先加载、限制预取重试、真实取消、无阻塞占位卡、预计算瀑布流、滚动速度感知分页、按真实响应边界定位分页

**iOS**：全部可用，性能优化对 iOS 内存受限环境是净收益。我们最后一个提交 a419b20a 修的 AI TAG 详情窄屏问题，落点文件（ai_tag_detail_dialog.dart / post_detail_dialog.dart）上游已删除并合并进 gallery_detail_dialog* 家族 13 个新文件；上游新结构用有界高度（mediaHeight + Expanded）解决了同类 bug，我们的补丁可丢，但标签 chip 的触屏长按菜单上游仍没有，要重新打到 gallery_detail_tag_section.dart。

### 本地推理与反推
- 本地反推支持导入包含模型与标签文件的 ZIP 压缩包，兼容 CL Tagger v2 与 external-data 布局，含中断恢复与清理流程
- onnxruntime → onnxruntime_v2 1.23.2+2（Android 16KB pages、模拟器 ABI；iOS/macOS 自动启用 CoreML EP）
- 新增 getManagedTaggerDirectory() = applicationSupport/models/onnx_taggers
- 魔棒 SAM 首次下载有了明确提示与进度条（约 133 MiB，EfficientViT-SAM L0）

**iOS**：onnxruntime_v2 有完整 iOS 实现（ffiPlugin: true、onnxruntime-objc 1.23.0 精确锁定、DynamicLibrary.process()），API 与旧包同源，本地反推和魔棒抠图不会丢，但要在 Mac 上重生成 Podfile.lock 并复测包体。目录策略正面冲突：上游的 Application Support 在 iOS「文件」App 里不可见，会顶掉我们的 Documents/tagger_models，用户手动放的模型将扫不到——必须合并而非二选一。SAM 下载仍无蜂窝网络确认。

### 性能、主题与本地化
- 启动流程延后非关键预加载并限制后台并发；本地画廊按需扫描、按显示尺寸动态解码、内存缓存上限、旧缩略图安全迁移
- 减少生成准备/流式预览/图生图放大的重复复制与解码；长提示词编辑与翻译减少重复处理；延后加载非当前主题字体
- 全局低对比度分层色面、无边框卡片、紧凑页面标题；主题容器色阶与次要文字对比度修复；图片查看区域统一中性深色背景
- 完整繁体中文界面（OpenCC 资产已在 pubspec，iOS 打包生效）
- 生成模型/智能体/服务商品牌图标随应用提供（assets/icons/ai_brands/）

**iOS**：全部白捡，且对 iOS 的内存上限（64MB imageCache）和冷启动收益明显。注意我们旧的 pubspec assets 清单已过期（上游删了 assets/images/ 与 assets/data/wordlists/，新增 icons/ai_brands/ 与 data/opencc/），必须整段采用上游的，不要套旧清单。

### Windows/Android 独占（iOS 已被能力矩阵正确隐藏，不会留死按钮）
- Windows 自绘标题栏、系统托盘、窗口状态恢复、字体枚举、DLSSNR
- Android 前台服务后台生成保护、APK 应用内安装、SAF 文件导出、MediaStore 相册发布、接收 ACTION_SEND 分享、Agent 提问系统通知、大资产流式落盘通道
- Release 统一从不可变 tag 构建、APK 强制正式签名与包名/版本/证书校验
- CI：android-build.yml、pull-request-validation.yml、测试分片、flutter_driver + integration_test

**iOS**：这一整类在 iOS 上被 supportsDesktopWindowControls / supportsSystemTray / supportsDlssEnhancement / supportsInAppPackageInstall 等能力位正确关掉，不会崩也不会留死按钮——这是上游能力矩阵设计的直接好处。但其中四项 Android 系统集成在 iOS 侧是真空，需要逐个决策：SAF 导出→走 share_plus；MediaStore→我们的 gal 显式动作；前台服务→beginBackgroundTask + 可恢复；APK 安装→保持 iOS 更新门控关闭。

## 并行车道（按文件独占划分）

| 车道 | 范围 | 依赖 | 工作量 | 风险 |
| --- | --- | --- | --- | --- |
| **L0 bootstrap（依赖与构建地基）** | 从 tag v4.2.1 建 ios-v3 分支；原样复制 packages/nai_png_codec/（含 src/vendor 490K，不联网不走 LFS）；pubspec.yaml 整段采用上游 assets/dependencies 清单后只插回 gal ^2.3.0 与那行中文注释（绝不整条丢弃旧 pubspec hunk——同一 diff 里 assets/images 那行该丢、gal 那行必留）；.gitattributes 以上游 6 行为底，只追加我们的 ios/Podfile.lock 与 ios/Podfile 两行 eol=lf。这条车道跑通前其他车道不能开工。 | — | M | high |
| **L1 ios-platform-ci（iOS 工程与流水线）** | 整入我们 28 文件的 ios/ 工程（pbxproj 已是 Flutter 3.35+ 新模板、objectVersion 54、SPM 本地包引用、IPHONEOS_DEPLOYMENT_TARGET 16.0，与上游 CI 固定的 3.44.2 同代，不需要改结构）；Mac 上 flutter pub get + pod install 重生成 Podfile.lock（onnxruntime→onnxruntime_v2 换代，9 个 pod 全变）；Info.plist 保留 ATS/NSAllowsLocalNetworking/相册/UIFileSharingEnabled/方向白名单，新增 CFBundleDocumentTypes(public.image) + UTExportedTypeDeclarations(.naiv4vibe/.naiv4vibebundle)；ios-release.yml 把自写的 LFS/raw 兜底换成 pwsh ./scripts/prepare_bundled_database.ps1，补 PUB_HOSTED_URL 与 verify_flutter_sources.ps1 / verify_bundled_databases.dart 两步；workflow 取舍：删 online-gallery-live-contract（有 cron）、release（push v* 撞车）、pull-request-validation（windows-2022 三分片最贵）、cooccurrence-data-pack（contents: write），保留 android-build 与 windows-portable（纯手动零成本）。 | L0 bootstrap（依赖与构建地基） | L | high |
| **L2 capabilities-io（能力矩阵 iOS 补全与导出链路）** | 在 platform_capabilities.dart 上：supportsSystemGalleryExport 保持 isAndroid 并在该行上方留中文注释钉死原因（这是「保存不自动进相册」的唯一支点，10 个 AndroidMediaStoreService 调用点全靠它守）；新增独立能力位 supportsExplicitPhotoLibraryExport => isIOS（只被手动入口消费，绝不接 publishToSystemGallery）；supportsDocumentFileExport / supportsManagedFileImports 改成含 iOS 并补实现；新增 supportsAutomaticUpdateCheck => !isIOS 供 L3 消费。给 FileExportService 加第三条 iOS 分支（写 getTemporaryDirectory 临时文件 + Share.shareXFiles），pickExportDirectory 在 iOS 返回 null 由调用方降级；NativeShareService 的 sharePositionOrigin 改必填或内部兜底（iPad popover 无锚点会失败，mosaic/watermark 两个调用点没传）。收编全仓裸 FilePicker.saveFile 调用点（generation_image_batch_actions.dart:113 那处还在 try 块外，iOS 是未捕获异常）。 | L0 bootstrap（依赖与构建地基） | L | high |
| **L3 update-gating（iOS 关闭应用内更新）** | 四处门控在 v4.2.1 上全部要重做，且位置变了：(1) app_bootstrap.dart 的 _AutomaticUpdateCheckState 已改成带 WidgetsBindingObserver 的周期检查，守卫必须下沉到 _schedule() 开头而不是 initState，否则切后台再回前台会绕过；(2) update_notice_banner.dart 全文无平台判断；(3) update_check_dialog.dart 只有 requiresExternalInstallerFlow（=isAndroid）六处，零 iOS 分支，门控条件要写成「iOS 才禁用」而不是「非 Windows 就禁用」（上游新增了 Android APK 应用内安装）；(4) about_settings_section.dart:108-124 仍渲染检查更新 ListTile。另外 github_api_service.dart:380-382 的兜底 `assets.where(type != unknown).firstOrNull` 原样保留，会把桌面包推给 iPhone——改成 normalizedPlatform=='unknown' 时 return null，注意保留上游新增的 android-apk 分支。顺带补 update_check_dialog.dart:569 的 tableColumnWidth: IntrinsicColumnWidth()（上游仍只设 tableScrollbarThumbVisibility，表格无法横向滚动）。 | L2 capabilities-io（能力矩阵 iOS 补全与导出链路） | M | medium |
| **L4 gen-left-drawer（生成页左侧边栏 —— 用户点名）** | 本次最高优先级的结构性冲突。上游 mobile_generation_chrome.dart:239-240 是 drawer=参数面板 / endDrawer=历史；我们是 drawer=GenerationQuickToolsDrawer（534 行新建文件，固定词/角色两个 Tab 的开关列表）/ endDrawer=宽 300 的紧凑参数面板。建议方案 (a)：保我们的左右分工，把上游的 HistoryPanel 从 endDrawer 降级成 AppBar history 按钮弹 AdaptivePresenter.showPanel（同步改 mobile_generation_controller.dart:151 的 openHistoryDrawer），在 _buildAppBar 的 leading 补回 Icons.style_outlined 调用新增的 openQuickToolsDrawer，保留「先 unfocus 再开抽屉」。quick_tools_drawer.dart 搬过去时把角色列表部分改成复用上游 MobileCharacterManagerSheet 的内容避免重复维护；其中手动 setMaximized(false) 的补丁可以丢（上游 character_position_canvas_provider.dart:74-91 的 open({forceExitMaximizedPrompt}) 已覆盖），但 scaffold.closeDrawer() 必须保留。同时在底栏 queue-actions Row 里补回 ×N 批量计数的 DraggableNumberInput（上游底栏无 nSamples），AppBar 补回一击可达的「导入图片解析参数」入口（调用 L11 提供的取图层）。顺带把 mobile_shell_overlay_provider 的全屏编辑撤底栏机制吃下来。 | L0 bootstrap（依赖与构建地基） | L | high |
| **L5 image-detail-prefs（复制不带元数据 + 保存到相册 —— 用户点名）** | 上游 detail_top_bar.dart（456 行，已重写并带 compact/veryCompact 溢出菜单）只有单个 onCopyImage，行为由 effectiveStripMetadataForCopyAndDrag = protectionMode && stripMetadataForCopyAndDrag 决定，而 protectionMode 默认 false —— 即上游默认复制是带元数据的。要做：给 image_detail_viewer 的 _copyImageToClipboard 加回 {bool? stripMetadataOverride}，顶栏常驻一个 onCopyImageClean 硬传 true，「复制（含元数据）」降级进溢出菜单；确保 clean 路径不带 copyDragWatermarkProvider 的 transform（v4.2.1 新增的水印开关与元数据开关正交，默认 false，不能合并）。相册部分：保留 gal 的 _saveToPhotoAlbum 作为显式动作接到新增的 supportsExplicitPhotoLibraryExport，绝不接 image_generation_provider.dart:136-145 的 publishToSystemGallery 自动回调。另外重做两条上游没有的：元数据异步兜底解析（getMetadataAsync/getPlaceholderProvider 提升为 ImageDetailData 接口成员），以及把 DetailTopBar 的按钮显隐接上兜底结果（上游 detail_top_bar.dart:55 仍只读 currentImage.metadata 这个 DB 快照，iOS 覆盖安装后「复用参数」按钮会消失）；detail_image_page 的低清占位图一并带回。溢出菜单本体用上游的，只补 onSaveToAlbum / onCopyImageClean / onShowInfo 三个回调。「一键 NAI 放大」改调上游 novelAiUpscaleTaskProvider，不自己维护一份。 | L2 capabilities-io（能力矩阵 iOS 补全与导出链路） | L | high |
| **L6 library-drawers（画廊/词库/Vibe 的左侧抽屉与集合筛选）** | 上游全仓只剩生成页一对 drawer，本地画廊/词库/Vibe 的分类面板都改成了 AdaptivePresenter.showPanel 底部面板。用户偏好是左抽屉：把 local_gallery_screen_controller.showCategoryPanelSheet 的窄屏分支换成左 Drawer 承载同一个 controller.buildCategoryPanel(...)，Scaffold 上设 drawerEnableOpenDragGesture: false（防与图片横滑冲突），词库页与 Vibe 库同理（只换呈现容器，不重建分类树）。集合筛选（CollectionFilterDrawer + gallery_filter_service 的 collectionId/collectionFileNames）经复核是我们新增的功能而非上游删掉的旧代码——上游 ImageCollection/CollectionRepository/collection_provider/CollectionSelectDialog 全都还在，只是另加了独立的 albumId 维度，从未提供按合集筛选。所以这套要保，但要先决策是否与上游相簿语义重复（用户会同时看到两套分组）。若决定迁到相簿，必须先修 gallery_album_import_coordinator.dart:150-167 的迁移路径（读绝对路径，iOS 重装后 getImageIdByPath 与 File.exists 双双失败，成员会被整体丢弃只打一行日志）。窄屏列宽 110（390pt 给 3 列）vs 上游 160（给 2 列）是信息密度偏好差异，需用户拍板。 | L0 bootstrap（依赖与构建地基） | L | high |
| **L7 mobile-defaults（移动端默认值与壳层小改）** | 三个默认值上游全部仍是 true，改动极小无冲突：local_storage_service.dart:377-384 的 getShowRandomPromptTools 改 !(isIOS//isAndroid)（注意上游 mobile_layout.dart:86 仍在 watch randomPromptToolsVisibilityProvider，所以这条是「移动端隐藏抽卡开关」唯一支点，必须保留）；notification_settings_provider 的 _defaultSoundEnabled；proxy_settings_provider 的 _defaultProxyEnabled，配套 startup_initialization_provider 的 _configureSystemProxy 从 `!isDesktop return` 放宽到 `!isDesktop && !isMobile return`（用 PlatformCapabilities 写法，移动端只注入 manual 模式，auto 在 iOS 拿不到地址），并隐藏 network_settings_section 的 auto 模式段。theme_provider 加回 toggleQuickTheme（深/浅两套快切），入口挂到上游 mobile_more_panel（上游 more 面板条目表里没有任何主题项）。mobile_shell._onNavigate 补回 initialLocation: 重按当前 Tab 回分支根（上游 goBranch 无此参数，从深层子页无法一键回根）。account 添加入口：上游已登录时 AccountDetailTile 不渲染登录按钮、AccountProfileBottomSheet 全文无 auth_addAccount，移动端没有任何添加第二账号的路径，需在 more 面板或 sheet 里补一条。app_toast 采用上游的顶部 overlay 栈，但保留我们三项交互决定：IgnorePointer 不拦截点击、top 让开 kToolbarHeight+12（上游紧贴状态栏 12pt，会压住生成页 AppBar 的 tune/agent/history 三个按钮并吞掉点击）、时长 2.2s（上游 3s）。 | L0 bootstrap（依赖与构建地基） | M | medium |
| **L8 prompt-pipeline（raw 直填、不清角色与提示词性能）** | raw 旁路的锚点从已删的 prompt_input.dart 移到 prompt_input_coordinator.dart：PendingPromptState 加 @Default(false) bool raw 并在 set() 透传（跑 build_runner），coordinator:45 与 :69 的 _normalize(x) 改成 consumed.raw ? x : _normalize(x)，generation_prompt_transfer_service.replaceMainPrompt 加 bool raw 参数条件化两处 _normalize，AI TAG 发送路径传 raw: true。注意只旁路 mainPrompt/negative 两条，不要影响上游新增的 SendTargetType.smartDecompose(PipeParser) 分支——上游已有结构化竖线解析，我们旧的 _characterPromptsOf 重解析 hack 可以丢。「发送不清空角色」的落点从「删 clearAllCharacters」变成给 online_gallery_detail_launcher.dart:496-498 的 characterPromptNotifier.replaceAll(_codexCharacters(...)) 加空值守卫（解析结果为空时不动角色面板），处理好由此产生的 unused 警告。另外三条上游零改动的纯增量：prompt_token_counter_provider 的 400ms 防抖、t5_prompt_token_encoder 的实例级 LRU(512)、generation_params_notifier 的 Future.microtask → SchedulerPhase + addPostFrameCallback（上游 :142-158 仍是 microtask）。unified_prompt_input 的 _syncFromExternalController 组词守卫（iOS 中文输入法兜底，上游 :535-556 无 composing 判断）优先级最高。 | L0 bootstrap（依赖与构建地基） | M | medium |
| **L9 onnx-storage（tagger 目录与 iOS 存储设置）** | 上游新增 getManagedTaggerDirectory() = applicationSupport/models/onnx_taggers，在 iOS 上「文件」App 不可见；而入口 _configureLocalOnnxTagger 的分支条件是 supportsManagedFileImports(=isAndroid)，iOS 会落到 FilePicker.getDirectoryPath 存一个跨启动失效的 security-scoped 路径——界面显示「已配置」但扫不到模型。做法是合并而非二选一：保留我们的 resolveTaggerDirectory()（iOS → Documents/tagger_models 并自动创建），让 scanTaggerModels()（上游已改 async）扫描路径至少包含它，同时把上游新增的 importTaggerSelections()（含 ZIP 解包、中断恢复、清理）接到 iOS 并把 target 指向 Documents/tagger_models。storage_settings_section.dart 里：图片保存路径/Vibe 库路径/Hive 目录三行改用上游的 supportsCustomStorageDirectories 门控（等价、可丢我们的实现），但 iOS 的 tagger 目录只读展示 + shareddocuments:// 跳「文件」App 入口必须保留（上游 supportsOpenFolder => isDesktop，iOS 没有任何打开目录的路径）；配置本地导出/导入两个 ListTile 也落在这个文件。local_onnx_tagger_service 的两处定制要保：移动端 intra-op 线程放开到 min(4,CPU)（上游 :154 写死 1）与 opset patch 为 no-op 时短路避免整份复制 GB 级模型（上游 :373-379 无条件写文件），注意 onnxruntime_v2 的 setIntraOpNumThreads API 需复核。 | L0 bootstrap（依赖与构建地基）, L2 capabilities-io（能力矩阵 iOS 补全与导出链路） | M | medium |
| **L10 touch-reachability（上游至今未修的触屏可达性）** | 逐条复核后确认在 v4.2.1 上仍 100% 复现的：(1) 标签黑名单/输出过滤只有右键——tag_chip.dart:94 只有 onSecondaryTapUp，全文无 onLongPress，调用方 gallery_detail_tag_section.dart:68-77 同样，tooltip 文案仍写「右键可加入黑名单」；挂点从已删的 ai_tag/post_detail_dialog 改到 gallery_detail_tag_section.dart 与 gallery_detail_info_panel.dart:558，按 interactionPolicy.shouldExposeTouchAlternatives 切文案，含 HapticFeedback。(2) 取色器触屏点选——color_picker.dart:195/280 两个 GestureDetector 只有 onPanStart/onPanUpdate，纯点击不触发；补 onTapDown（裁剪那半边上游已用 hasBoundedHeight→Expanded 修掉，我们删 height:150 的改动可丢）。(3) 词库卡片 onSend 死回调——entry_card.dart:28/51 声明、build 从不引用，调用方 tag_library_page_screen.dart:643 照传，这是全平台 bug，接进上游的 _buildTouchActions 菜单。(4) 角色定位画布编号错位——上游 :736 只把禁用角色变暗仍渲染，:620/:716 用原始下标编号，而位置按 enabled 下标算（character_prompt.dart:355-357），改最小面把 index 换成 enabled 列表下标。(5) outpaint_edge_drag_overlay.dart:26 的 edgeHitSlop=48 未按缩放/触屏收缩。(6) 角色面板行图标按钮 inline_character_row.dart:536 仍是 comfortable?40:23，低于 44pt（卡片头部上游已修到 44）。(7) history_panel 与 gallery_grid 在移动端要跳过桌面拖放包装（上游只按 canDrag/selectionState 门控，长按进多选会被拖拽吞掉），条件用 supportsExternalFileDrop。(8) image_preview.dart:838 的 onSendToKrita 上游漏了门控，iOS 预览菜单仍会出现「发送到 Krita」，补 supportsKritaBridge；放大/增强后自动展开参数面板的 _revealWorkflowPanelOnMobile 上游完全没有，重做但槽位要按 L4 的最终分工调。 | L0 bootstrap（依赖与构建地基） | L | medium |
| **L11 clipboard-import（剪贴板读图与移动端导入）** | clipboard_image.dart 的 readImageBytesFromClipboard()（PNG/JPEG/WEBP/BMP 依次尝试）是纯增量，上游该文件只有写没有读，直接搬。上游的 MobileImageMetadataImporter 只有 FilePicker 一条来源且限定 png/webp，且走 GlobalDropActionCoordinator 全量套用参数；我们要的是：采上游的 importer 作为取图层（它的 imageBytesPicker/imageProcessor 都是可注入的，正是为这种替换留的），但 picker 接上剪贴板来源、processor 换成我们的 MetadataImportDialog 勾选流程 + MetadataImportCoordinator。FilePicker 的 type 在 iOS 上改 FileType.any + 自校验扩展名（上游 FileType.custom+allowedExtensions 在 iOS 需要注册 UTI，全仓 20+ 处中招，Vibe 的 .naiv4vibe 会被置灰——这条与 L1 的 UTExportedTypeDeclarations 配套）。四个面板的移动端粘贴入口按上游新结构重放，img2img 的落点在 img2img_source_section.dart。 | L0 bootstrap（依赖与构建地基） | M | medium |
| **L12 settings-reverse（集成设置、反推与固定词同步）** | ComfyUI：上游 platform_capabilities.dart 的 supportsComfyUiIntegration => isDesktop + integrations_settings_section.dart:86-90 把分段禁用并挂「仅桌面端可用」tooltip，与我们的明确决定相反（手机连同网段 PC 是合理场景，Info.plist 已为此加了 NSLocalNetworkUsageDescription）——要保留就必须在消费点覆写并重新落我们的局域网 helperText。Krita 门控改用上游的 supportsKritaBridge（等价且更干净，含「注入测试 provider 时仍订阅」这个细节），丢我们的 _hidesKritaBridge。反推链路：ReversePromptProcessingStage 加 optimize/custom、State 加 5 个字段与 3 个 setter、面板加自定义指令输入框与两个输出块、tagger 下拉 iOS hint（上游 reverse_prompt_provider.dart 与 v1.8.1 零 diff，provider 可整体 copy-ours；panel 只有 ~165 行 churn 按 hunk 重放），反推面板的剪贴板粘贴入口用 L11 的函数。固定词与词库双向同步兜底：syncFromTagLibrary 加 previousContent 参数按「内容一致」收养未关联的固定词并补写 sourceEntryId（上游 :756-758 仍只按 sourceEntryId 匹配），注意与上游新增的 resolveFixedTagImport/fixedTagResolution 不冲突。send_to_home_dialog 的编辑入口与 collection_select_dialog 的「新建」按钮（上游 actions 区只有取消）一并补。nai_image_enhancement_api_service 改用 imageGenerationDioClientProvider（上游 :342 仍是通用 dioClient，通用 client 的 Http2Adapter 在 api.novelai.net 上连接异常——这是移动端直连才暴露的问题，桌面走系统代理看不到），1024 分辨率预检那半边丢弃（上游已整体删除）。 | L0 bootstrap（依赖与构建地基）, L11 clipboard-import（剪贴板读图与移动端导入） | L | medium |
| **L13 l10n-merge（三语文案汇总）** | arb 与生成物是上一轮最容易互相覆盖的共享文件，本轮由单条车道独占：各功能车道把自己新增的 key 写进 lib/l10n/fragments/<lane>.json（新建目录，车道各自独占），本车道在功能车道收工后一次性合并进 app_en/zh/ja.arb 并跑 flutter gen-l10n 重出生成物，绝不手工移栽生成文件。已核对的取舍：撤销上一轮对 nav_gallery 的删除（上游 mobile_shell.dart:114 正在用它）；character_limitReached 上游已有不用重加；settings_pathFixedIosHint 被上游 settings_androidManagedStorage 覆盖（iOS 上文案不准，可自加一条）；必须保留的有 image_copyCleanImage / image_copyWithMetadata / image_saveToAlbum / image_savedToAlbum / image_saveToAlbumFailed / detail_saveToGallery / settings_releasePage(+Subtitle) / settings_comfyUiLanHint / settings_localOnnxTaggerFolderIosHint / settings_exportConfig(+Import) / generation_pasteImageFromClipboard / generation_clipboardNoImage / reversePrompt_needCustomInstruction / reversePrompt_localTaggerModelHintIos / 两条 *TooltipTouch / more_switchTheme。注意上游 i18n 回归测试强制「模板里不能有未被代码引用的 key」，合并必须在功能代码落地之后。 | L3 update-gating（iOS 关闭应用内更新）, L4 gen-left-drawer（生成页左侧边栏 —— 用户点名）, L5 image-detail-prefs（复制不带元数据 + 保存到相册 —— 用户点名）, L6 library-drawers（画廊/词库/Vibe 的左侧抽屉与集合筛选）, L7 mobile-defaults（移动端默认值与壳层小改）, L9 onnx-storage（tagger 目录与 iOS 存储设置）, L10 touch-reachability（上游至今未修的触屏可达性）, L12 settings-reverse（集成设置、反推与固定词同步） | S | medium |
| **L14 model3d-touch（3D 编辑器触屏，可选）** | assets/model3d_editor/editor.js:303-304 与 v1.8.1 逐字未变（marker 半径 max(bbox*0.008, 0.006)，手机上点不中），全文 grep isTouch/coarse/maxTouchPoints 零命中；:138 与 :426 的 keydown 仍是唯一的相机操作路径（WASDQE），触屏无法平移相机。做法：按 pointer 类型放大 marker 半径或加独立的更大不可见拾取球，补双指平移手势。flutter_inappwebview 版本 v1.8.1→v4.2.1 零变化（6.1.5/1.1.2），local_asset_server.dart 仍是 127.0.0.1 loopback，现有 Info.plist 的 NSAllowsLocalNetworking 继续有效不需改。这条优先级最低，可以排在出包之后。 | L1 ios-platform-ci（iOS 工程与流水线） | M | low |
| **L15 device-verify（Mac 构建与真机验证门）** | 不写业务代码，负责把 blockers 逐条证伪并记录。第一优先级是在 Mac 上单独跑 flutter build ios --release --no-codesign，只看 build/ios/iphoneos/Runner.app/Frameworks/ 下有没有 nai_png_codec 的 .framework（这一步不通后面全部无意义），顺带确认 flutter_driver 在 release AOT 下能编过、量一次 IPA 体积增量（v1.8.1 基线 61.5MB，ORT 1.15→1.23 与 GoogleSignIn/AppAuth 会显著增大）。真机清单：3D 编辑器 WKWebView 能连 127.0.0.1；ONNX 本地反推与魔棒 SAM 推理（CoreML EP）；复制/拖拽去元数据实际生效；生成图不进相册而手动「保存到相册」可用；覆盖安装后图库索引与相簿/集合成员是否失效（images.file_path 若存绝对路径会全空）；生成中切后台的恢复行为；iPad 横屏走 DesktopShell 是否符合预期。产出写进工作日志，不写成额外的永久测试文件。 | L1 ios-platform-ci（iOS 工程与流水线）, L2 capabilities-io（能力矩阵 iOS 补全与导出链路） | M | high |

<details><summary>L0 bootstrap（依赖与构建地基） 独占文件（4）</summary>

- `pubspec.yaml`
- `pubspec.lock`
- `.gitattributes`
- `packages/nai_png_codec/`

</details>

<details><summary>L1 ios-platform-ci（iOS 工程与流水线） 独占文件（3）</summary>

- `ios/`
- `.github/workflows/`
- `scripts/`

</details>

<details><summary>L2 capabilities-io（能力矩阵 iOS 补全与导出链路） 独占文件（6）</summary>

- `lib/core/platform/platform_capabilities.dart`
- `lib/core/services/file_export_service.dart`
- `lib/core/services/native_share_service.dart`
- `lib/core/services/ios_photo_library_service.dart`
- `lib/presentation/screens/generation/services/generation_image_batch_actions.dart`
- `lib/presentation/screens/local_gallery/local_gallery_action_coordinator.dart`

</details>

<details><summary>L3 update-gating（iOS 关闭应用内更新） 独占文件（7）</summary>

- `lib/presentation/screens/splash/app_bootstrap.dart`
- `lib/presentation/widgets/common/update_notice_banner.dart`
- `lib/presentation/widgets/common/update_check_dialog.dart`
- `lib/data/datasources/remote/github_api_service.dart`
- `lib/core/services/app_installation_service.dart`
- `lib/presentation/screens/settings/sections/about_settings_section.dart`
- `test/presentation/widgets/update_ios_gating_test.dart`

</details>

<details><summary>L4 gen-left-drawer（生成页左侧边栏 —— 用户点名） 独占文件（5）</summary>

- `lib/presentation/screens/generation/widgets/quick_tools_drawer.dart`
- `lib/presentation/screens/generation/mobile_generation_chrome.dart`
- `lib/presentation/screens/generation/mobile_generation_controller.dart`
- `lib/presentation/screens/generation/mobile_generation_shell.dart`
- `lib/presentation/screens/generation/mobile_layout.dart`

</details>

<details><summary>L5 image-detail-prefs（复制不带元数据 + 保存到相册 —— 用户点名） 独占文件（5）</summary>

- `lib/presentation/widgets/common/image_detail/image_detail_viewer.dart`
- `lib/presentation/widgets/common/image_detail/components/detail_top_bar.dart`
- `lib/presentation/widgets/common/image_detail/components/detail_image_page.dart`
- `lib/presentation/widgets/common/image_detail/image_detail_data.dart`
- `lib/presentation/widgets/common/image_detail/file_image_detail_data.dart`

</details>

<details><summary>L6 library-drawers（画廊/词库/Vibe 的左侧抽屉与集合筛选） 独占文件（11）</summary>

- `lib/presentation/screens/local_gallery/local_gallery_screen.dart`
- `lib/presentation/screens/local_gallery/local_gallery_screen_controller.dart`
- `lib/presentation/screens/local_gallery/local_gallery_view_model.dart`
- `lib/presentation/screens/tag_library_page/tag_library_page_screen.dart`
- `lib/presentation/screens/vibe_library/vibe_library_screen.dart`
- `lib/presentation/widgets/gallery/collection_filter_drawer.dart`
- `lib/presentation/widgets/gallery/local_gallery_toolbar.dart`
- `lib/data/services/gallery/gallery_filter_service.dart`
- `lib/data/services/gallery/gallery_album_import_coordinator.dart`
- `lib/presentation/providers/local_gallery_provider.dart`
- `test/data/services/gallery/gallery_filter_collection_test.dart`

</details>

<details><summary>L7 mobile-defaults（移动端默认值与壳层小改） 独占文件（10）</summary>

- `lib/core/storage/local_storage_service.dart`
- `lib/presentation/providers/notification_settings_provider.dart`
- `lib/presentation/providers/proxy_settings_provider.dart`
- `lib/presentation/providers/startup_initialization_provider.dart`
- `lib/presentation/providers/theme_provider.dart`
- `lib/presentation/router/mobile_more_panel.dart`
- `lib/presentation/router/mobile_shell.dart`
- `lib/presentation/widgets/common/app_toast.dart`
- `lib/presentation/screens/settings/sections/network_settings_section.dart`
- `lib/presentation/widgets/common/draggable_number_input.dart`

</details>

<details><summary>L8 prompt-pipeline（raw 直填、不清角色与提示词性能） 独占文件（9）</summary>

- `lib/presentation/providers/pending_prompt_provider.dart`
- `lib/presentation/screens/generation/widgets/prompt_input_coordinator.dart`
- `lib/presentation/services/generation_prompt_transfer_service.dart`
- `lib/presentation/screens/online_gallery/online_gallery_detail_launcher.dart`
- `lib/presentation/providers/prompt_token_counter_provider.dart`
- `lib/core/services/tokenizers/t5_prompt_token_encoder.dart`
- `lib/presentation/providers/generation/generation_params_notifier.dart`
- `lib/presentation/widgets/prompt/unified/unified_prompt_input.dart`
- `test/presentation/providers/generation/generation_params_notifier_test.dart`

</details>

<details><summary>L9 onnx-storage（tagger 目录与 iOS 存储设置） 独占文件（3）</summary>

- `lib/data/services/local_onnx_model_service.dart`
- `lib/data/services/local_onnx_tagger_service.dart`
- `lib/presentation/screens/settings/sections/storage_settings_section.dart`

</details>

<details><summary>L10 touch-reachability（上游至今未修的触屏可达性） 独占文件（14）</summary>

- `lib/presentation/widgets/tag_chip.dart`
- `lib/presentation/widgets/online_gallery/gallery_detail_tag_section.dart`
- `lib/presentation/widgets/online_gallery/gallery_detail_info_panel.dart`
- `lib/presentation/widgets/image_editor/widgets/color_picker.dart`
- `lib/presentation/widgets/image_editor/widgets/outpaint_edge_drag_overlay.dart`
- `lib/presentation/screens/tag_library_page/widgets/entry_card.dart`
- `lib/presentation/widgets/character/inline_character_row.dart`
- `lib/presentation/widgets/character/character_position_canvas.dart`
- `lib/presentation/widgets/character/add_character_buttons.dart`
- `lib/presentation/widgets/gallery/gallery_grid.dart`
- `lib/presentation/screens/generation/widgets/history_panel.dart`
- `lib/presentation/screens/generation/widgets/image_preview.dart`
- `test/presentation/widgets/tag_chip_test.dart`
- `test/presentation/widgets/character/add_character_buttons_limit_test.dart`

</details>

<details><summary>L11 clipboard-import（剪贴板读图与移动端导入） 独占文件（6）</summary>

- `lib/presentation/utils/clipboard_image.dart`
- `lib/presentation/services/mobile_image_metadata_importer.dart`
- `lib/presentation/screens/generation/widgets/img2img_source_section.dart`
- `lib/presentation/screens/generation/widgets/precise_reference_panel.dart`
- `lib/presentation/screens/generation/widgets/vibe_transfer_content.dart`
- `lib/presentation/screens/vibe_library/vibe_library_screen_controller.dart`

</details>

<details><summary>L12 settings-reverse（集成设置、反推与固定词同步） 独占文件（12）</summary>

- `lib/presentation/screens/settings/sections/integrations_settings_section.dart`
- `lib/presentation/screens/settings/sections/comfyui_settings_section.dart`
- `lib/app.dart`
- `lib/presentation/providers/reverse_prompt_provider.dart`
- `lib/presentation/screens/generation/widgets/reverse_prompt_panel.dart`
- `lib/presentation/providers/fixed_tags_provider.dart`
- `lib/presentation/providers/tag_library_page_provider.dart`
- `lib/presentation/screens/tag_library_page/widgets/send_to_home_dialog.dart`
- `lib/presentation/widgets/collection_select_dialog.dart`
- `lib/data/datasources/remote/nai_image_enhancement_api_service.dart`
- `lib/core/services/sqflite_bootstrap_service.dart`
- `test/presentation/providers/fixed_tags_provider_test.dart`

</details>

<details><summary>L13 l10n-merge（三语文案汇总） 独占文件（8）</summary>

- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_ja.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_ja.dart`
- `lib/l10n/app_localizations_zh.dart`
- `lib/l10n/fragments/`

</details>

<details><summary>L14 model3d-touch（3D 编辑器触屏，可选） 独占文件（2）</summary>

- `assets/model3d_editor/`
- `lib/presentation/widgets/model3d_editor/`

</details>

<details><summary>L15 device-verify（Mac 构建与真机验证门） 独占文件（2）</summary>

- `IOS_V3_REPLANT.md`
- `IOS_V3_VERIFY.md`

</details>

## 必须保留的定制（31 条）

> 判「被上游取代」判错一条，代价是手机上一个功能静默消失且没人会发现。
> 每条都经过对抗式复核（默认立场「这条判错了」，只有亲自在 v4.2.1 代码里看到等价实现才维持原判）。

### 1. 【用户点名】生成页左侧快捷工具抽屉（固定词 / 角色两个 Tab 的开关列表，整行点击切开关、行尾铅笔进编辑，底部有管理固定词与深度编辑角色入口）

- **现在**：ios-v2: lib/presentation/screens/generation/widgets/quick_tools_drawer.dart（534 行新建文件，文件头注释「左侧抽屉承载高频的固定词/角色开关操作，可以一边看生成结果一边调整」）；挂载点 lib/presentation/screens/generation/mobile_layout.dart:61 `drawer: const GenerationQuickToolsDrawer()`；入口 AppBar leading Icons.style_outlined
- **v4.2.1 上怎么落**：上游 mobile_generation_chrome.dart:239-240 是 drawer=参数面板 / endDrawer=历史，全仓只有这一对 drawer（已 grep 确认），且上游移动端的固定词只是 mobile_generation_workspace.dart:249-253 的只读计数 chip，没有任何逐条开关 UI。方案 (a)：把 chrome.dart:239 的 drawer 换成 GenerationQuickToolsDrawer，参数面板挪到 endDrawer（保留我们 width 300 + VisualDensity.compact + fontSizeFactor 0.92 的密度收紧），历史抽屉改由 AppBar history 按钮弹 AdaptivePresenter.showPanel（同步改 mobile_generation_controller.dart:151），在 leading 补回 openQuickToolsDrawer。角色列表改复用上游 MobileCharacterManagerSheet 的内容；保留「先 unfocus 再开抽屉」与 quick_tools_drawer.dart:360 的 viewInsets 键盘避让（全仓唯一一处）。
- **风险**：最高。这是同一个 Scaffold 的同一组 slot，两种实现不可能并存；照搬上游 = 左侧边栏静默消失 + 参数面板左右翻转。而且 mobile_layout.dart 整文件在 v4.2.1 已拆成五个文件，任何「整文件替换」都会连带吃掉它。

### 2. 【用户点名】复制不带元数据：顶栏常驻独立的「复制图片（去除元数据）」按钮，硬传 stripMetadataOverride: true 绕过全局开关；「复制（含元数据）」降级进溢出菜单

- **现在**：ios-v2: lib/presentation/widgets/common/image_detail/image_detail_viewer.dart:604-620（移动端 stripMetadataOverride 三元）与 :922-934（_copyImageToClipboard 的可选参数）；按钮在 components/detail_top_bar.dart:172-178；文案 lib/l10n/app_zh.arb:6161 image_copyCleanImage
- **v4.2.1 上怎么落**：上游 detail_top_bar.dart（456 行，已重写并带 compact/veryCompact 溢出菜单）只有单个 onCopyImage，行为取 effectiveStripMetadataForCopyAndDrag = protectionMode && stripMetadataForCopyAndDrag，而 protectionMode 默认 false（share_image_settings_provider.dart:8）——上游默认复制是带元数据的。做法：给上游的 _copyImageToClipboard 加回 {bool? stripMetadataOverride}，把 stripMetadata 改成 override ?? effectiveStrip；DetailTopBar 加 onCopyImageClean 作为第三个常驻动作（不要依赖 shareImageSettingsProvider）；溢出菜单本体用上游的。
- **风险**：高。上游有同名功能但默认值相反，最容易被判成「已被上游取代」。另有新风险：v4.2.1 的 viewer 会把 copyDragWatermarkProvider 的 transform 一并传给 sanitizer（「复制/拖拽时加水印」，默认 false），clean 路径必须确保不带 transform——两个开关正交，不能合并。底层还依赖 nai_png_codec，见 blockers。

### 3. 【用户点名】保存不自动进相册：保存只写应用自管的本地图库，进系统相册是用户主动点的独立动作（gal + requestAccess）

- **现在**：ios-v2: image_detail_viewer.dart:888-919 `_saveToPhotoAlbum`（Gal.requestAccess / Gal.putImageBytes）与 :593-595 onSaveToAlbum；按钮在 detail_top_bar.dart:155-170（桌面独立按钮、移动端收进更多菜单）；pubspec.yaml:94 `gal: ^2.3.0`；Info.plist 的 NSPhotoLibraryAddUsageDescription
- **v4.2.1 上怎么落**：两件事：(1) platform_capabilities.dart 的 `supportsSystemGalleryExport => isAndroid` 必须原样保持并在该行上方留中文注释写死原因——上游 Android 侧是每次保存/出图都无条件发布到系统相册（image_generation_provider.dart:136-145 的 publishToSystemGallery 回调 + generation_save_service.dart:151 等共 10 个 AndroidMediaStoreService 调用点），全靠这一个能力位守着；(2) 要给 iOS 补相册能力，新增独立的 supportsExplicitPhotoLibraryExport => isIOS，只被手动菜单入口消费，绝不接 publishToSystemGallery 自动回调。pubspec 的 gal 依赖与那行中文注释不能被上游 pubspec 覆盖。
- **风险**：高，且是本次最危险的单点。iOS 移植时最自然的动作就是「顺手把 Android 的相册导出打开」把 isAndroid 改成 isMobile——那一行改动同时踩掉用户偏好（变成自动进相册）和实现缺口（AndroidMediaStoreService 在 iOS 会抛错），且 10 个调用点同时生效、没有任何设置项能关。建议补一条断言 iOS 下该位为 false 的回归测试。

### 4. 本地画廊左侧集合筛选抽屉 + 集合筛选数据层（按文件名小写匹配以扛住 iOS 容器 UUID 变化）

- **现在**：ios-v2: lib/presentation/widgets/gallery/collection_filter_drawer.dart（326 行新建，width 290，抽屉内可新建/重命名/删除集合）；local_gallery_screen.dart:208 drawer + :210 drawerEnableOpenDragGesture:false + :561 onOpenCollections；local_gallery_toolbar.dart:414-422 的「集合」按钮；数据层 gallery_filter_service.dart 的 collectionId/collectionFileNames/collectionFileNameKey/filterFilesByCollection（全部为新增行）
- **v4.2.1 上怎么落**：经复核这是我们新增的功能而非上游删掉的旧代码——上游 ImageCollection、CollectionRepository、collection_provider、CollectionSelectDialog、bulk addToCollection 全都还在，只是另加了独立的 albumId 维度，从未提供按合集筛选。上游窄屏分类入口是 AdaptivePresenter 底部面板（local_gallery_screen_controller.dart:251-269 showCategoryPanelSheet），要保左抽屉就把那个分支换成 Drawer 承载同一个 controller.buildCategoryPanel(...)，并设 drawerEnableOpenDragGesture:false。
- **风险**：中高。第一层风险是被误判成「被上游相簿取代」而整套删掉（含 326 行新文件）。第二层是若真要迁到相簿，gallery_album_import_coordinator.dart:150-167 的迁移读绝对路径，iOS 重装后 getImageIdByPath 与 File.exists 双双失败，用户已有集合会在迁移那一刻整体丢成员且只打一行日志。第三层是语义重复：上游相簿 + 我们的集合会让用户同时看到两套分组。

### 5. 词库页与 Vibe 库的窄屏分类树用左侧 Drawer + 顶部入口条呈现

- **现在**：ios-v2: tag_library_page_screen.dart:125-126 与 vibe_library_screen.dart:157-158 的窄屏 Drawer 分支
- **v4.2.1 上怎么落**：上游改成 AdaptivePresenter.showPanel 底部面板（tag_library_page_screen.dart:435-445 _showCategoryPanelSheet、vibe_library_screen.dart:308 _showCategoryPanel）。保留 Drawer 呈现容器，里面换成上游的 _buildCategorySidebar(forPanel: true)，不要重建分类树。
- **风险**：中。同属「左边侧边栏」偏好，容易被当成移动端适配丢掉。

### 6. 从在线画廊 / AI TAG 详情「发送到文生图」时不清空已配置的角色提示词

- **现在**：ios-v2: ai_tag_detail_dialog.dart:753 与 post_detail_dialog.dart:674 的中文注释「有意不清空角色提示词：发送是增量行为」，两处均删掉了 clearAllCharacters()；IOS_V2_REPLANT.md:126-129 列为「rebase 时容易被带回来」
- **v4.2.1 上怎么落**：两个源文件上游已删除。等价点变成 online_gallery_detail_launcher.dart:496-498 的 `characterPromptNotifier.replaceAll(_codexCharacters(item, projection))` —— 解析不出角色时 replaceAll([]) 等价于清空。落点从「删 clearAllCharacters」变成给 replaceAll 加空值守卫（结果为空时不动角色面板），并处理由此产生的 _codexCharacters unused 警告。
- **风险**：中。上游把角色结构化解析进面板本身是改进值得吃下，但「解析为空就清空」这个副作用必须挡住。

### 7. AI TAG 发送走 raw 语义：PendingPromptState.raw 旁路 SD→NAI 转换与格式化

- **现在**：ios-v2: pending_prompt_provider.dart:45-47 的 raw 字段 + :78/:87 透传；消费端 prompt_input.dart:131/:163 的 if(!consumed.raw)；ai_tag_detail_dialog.dart:713-725 的竖线拼接
- **v4.2.1 上怎么落**：上游转换是无条件的：generation_prompt_transfer_service.dart:249-251 与 prompt_input_coordinator.dart:79-80 都是 `NaiPromptFormatter.format(SdToNaiConverter.convert(prompt))`，v4.2.1 的 PendingPromptState 没有 raw 字段。三步：state 加 @Default(false) bool raw 并跑 build_runner；coordinator:45/:69 改成 consumed.raw ? x : _normalize(x)；replaceMainPrompt 加 raw 参数并在 AI TAG 路径传 true。只旁路 mainPrompt/negative 两条，不要碰上游新增的 SendTargetType.smartDecompose(PipeParser)。我们旧的 _characterPromptsOf 重解析 hack 可以丢，改用上游的结构化 characterPrompts。
- **风险**：中。不做的话自然语言描述会被改写成下划线串、`[...]` 降权被破坏。竖线拼接是否还必要，建议先把 raw 落地再实机对比上游结构化路径。

### 8. 移动端默认关闭生成完成提示音（桌面保持开启）

- **现在**：ios-v2: notification_settings_provider.dart:10-11 `_defaultSoundEnabled = !(Platform.isIOS || Platform.isAndroid)` + :45/:47
- **v4.2.1 上怎么落**：上游 :38-43 仍是 defaultValue: true / ?? true，全平台一致。只改 build() 里那两处 true，不要整文件覆盖——上游从 v1.8.1 起新增了 setCustomSoundPath 的移动端持久化（:57-64）要保留。
- **风险**：低。改动极小、上游零冲突，但容易在「整文件采上游」时被抹掉。

### 9. 移动端默认不启用代理 + iOS 手动代理注入

- **现在**：ios-v2: proxy_settings_provider.dart:13-14 `_defaultProxyEnabled` + :24-26；startup_initialization_provider.dart:164-170 把 _configureSystemProxy 放宽到含 iOS/Android
- **v4.2.1 上怎么落**：上游 proxy_settings_provider.dart:19 仍是 ?? true；_configureSystemProxy 被收回成 `if (!PlatformCapabilities.operatingSystem.isDesktop) return;`（:287-288），这是唯一写 HttpOverrides.global 的地方——iOS 上代理开关可点可存但永不生效。改成 `if (!caps.isDesktop && !caps.isMobile) return;`，移动端只注入 manual 模式（auto 在 iOS 拿不到地址，ProxyService.getSystemProxyAddress 对 iOS return null），并隐藏 network_settings_section 的 auto 模式段（该文件本身零平台门控，卡片照常显示）。
- **风险**：中。不做的话 iOS 上整个代理设置是个死开关，用户以为配了其实没生效。

### 10. 移动端默认隐藏「随机提示词工具」入口

- **现在**：ios-v2: lib/core/storage/local_storage_service.dart:412-418 `defaultVisible = !(Platform.isIOS || Platform.isAndroid)`
- **v4.2.1 上怎么落**：上游 :377-384 的 getShowRandomPromptTools 仍是 defaultValue: true，注释还写「默认开启」。改同样三行，文件头补 import 'dart:io'。注意上游 mobile_layout.dart:86 仍在 watch randomPromptToolsVisibilityProvider，所以这一条是移动端隐藏抽卡开关的唯一支点，不能因为「上游已有 provider 控制」就跳过。
- **风险**：低，但有隐性依赖：L4 车道若按「抽卡开关隐藏由默认值覆盖」的假设删掉相关代码，而这条没落地，开关就会在手机上重新出现。

### 11. 全屏查看器内触发的「复用参数」成功后只弹 toast、不跳转生成页

- **现在**：ios-v2: local_gallery_screen.dart:1190-1229 `_applyReuseMetadataOptions`（末尾只有 AppToast.success，无 context.go）+ :589 挂载；IOS_V2_APPLY_REPORT.md:66 明确「属有意保留」
- **v4.2.1 上怎么落**：上游统一成 ImageMetadataImportWorkflow，openGenerationPage 默认 true 且全仓无人传 false（image_metadata_import_workflow.dart:78/:126）。只需在 ImageDetailViewer 触发的那条调用里传 openGenerationPage: false，图库列表/拖放入口保持默认 true。
- **风险**：低。改一个参数即可，但不做的话用户正在看图时会被跳走打断浏览。

### 12. 「更多」入口的一键深浅主题快切 toggleQuickTheme（默认深色拼贴朋克 ↔ Bold Retro 浅色）

- **现在**：ios-v2: theme_provider.dart:40-48 toggleQuickTheme；入口 more_screen.dart:95-101
- **v4.2.1 上怎么落**：上游 theme_provider.dart 只有按 AppStyle.values 顺序轮转的 nextTheme，无 toggleQuickTheme；mobile_more_panel.dart 的条目表（账户/Agent/队列/读元数据/Vibe 库/精准参考库/随机配置/统计/设置/Discord/GitHub）里没有任何主题项。把方法加回 theme_provider（先确认 grungeCollage 与 boldRetro 两个枚举值在 8 个版本后还在），入口挂到 mobile_more_panel 的 _MobileMoreDestination。
- **风险**：低，但这是 more_screen.dart 里唯一上游没有的功能。按「MoreScreen 已被上游取代」整页丢弃，这个功能与 provider 方法会一起变成死代码然后消失。

### 13. 底栏重按当前 Tab 回到该分支初始路由

- **现在**：ios-v2: mobile_bottom_nav_bar.dart:31-37 `goBranch(..., initialLocation: tabIndex == currentTab)`
- **v4.2.1 上怎么落**：上游 mobile_shell.dart:186-200 的 _onNavigate 只有 `goBranch(index)`，无 initialLocation，重按当前 Tab 是 no-op，从词库/图库深层子页无法一键回根。底栏本体采上游，只补这一行。
- **风险**：低。属于会被「底栏整体 superseded」顺手丢掉的单行交互。

### 14. 顶部 toast 的三项交互决定：不拦截点击（IgnorePointer）、让开 kToolbarHeight 顶栏按钮行、时长 2.2s

- **现在**：ios-v2: app_toast.dart:278/:376 IgnorePointer、:372-373 `top: topInset + kToolbarHeight + 12`、:351 2200ms
- **v4.2.1 上怎么落**：「顶部显示」这一半上游独立做了且更完整（可堆叠、rootOverlay），采上游。但上游是 Positioned.fill + MouseRegion（默认 opaque）会吃掉触摸，:299-305 紧贴状态栏下方 12pt 起（正好压住生成页 AppBar 的 tune/agent/history 三个 IconButton），:410 默认 3s。三项都要在上游实现上重新加回。
- **风险**：中。照搬上游会让 toast 在 3 秒内挡住并吞掉生成页 AppBar 的点击——这是我们当初专门避开的。

### 15. 从剪贴板粘贴图片读取元数据（整条来源）+ 生成页 AppBar 一击可达的导入入口 + 参数勾选对话框

- **现在**：ios-v2: clipboard_image.dart:44-77 readImageBytesFromClipboard（PNG/JPEG/WEBP/BMP 依次尝试）；mobile_layout.dart:83-89 的 document_scanner AppBar 按钮与 :265-300 _showImportImageSheet 两项来源；落地走 MetadataImportDialog 勾选 + MetadataImportCoordinator
- **v4.2.1 上怎么落**：上游 clipboard_image.dart 只有 writeImageBytesToClipboardAsPng，没有任何读取函数（纯增量，直接搬）。上游 MobileImageMetadataImporter 只有 FilePicker 一条来源且限定 png/webp，入口在「更多」面板需两次点击，落地直接走 GlobalDropActionCoordinator 全量套用。做法：采上游 importer 作为取图层（imageBytesPicker/imageProcessor 都可注入，正是为此留的），picker 接剪贴板、processor 换成我们的勾选对话框，入口同时保留生成页 AppBar 那一击。
- **风险**：中。上游有「同名功能」，但来源少一个、入口远两步、落地行为不同（无勾选），按 superseded 处理会一次丢掉三项。

### 16. iOS 关闭应用内更新的四处门控 + GitHub 资产选择兜底返回 null

- **现在**：ios-v2: app_bootstrap.dart:147 的 initState 早退、update_notice_banner.dart:17、update_check_dialog.dart:29、about_settings_section.dart:27 的 _isIosRuntime、github_api_service.dart:386-392 的 return null；回归测试 test/presentation/widgets/update_ios_gating_test.dart
- **v4.2.1 上怎么落**：四处全部要重做且位置变了：app_bootstrap 的守卫必须下沉到 _schedule() 开头（上游改成了带 WidgetsBindingObserver 的周期检查，initState 早退会被 didChangeAppLifecycleState 的 resumed 绕过）；banner 与 dialog 全文无平台判断；about 仍渲染检查更新 ListTile。github_api_service.dart:380-382 的兜底原样保留，要改成 unknown 时 return null 并保留上游新增的 android-apk 分支。判定统一用 PlatformCapabilities.current.isIOS 或新增 supportsAutomaticUpdateCheck => !isIOS。
- **风险**：中。不做的话 iPhone 上会被无限重试的失败检查骚扰，并被推送 macOS/Windows/Android 安装包。注意门控条件要写成「iOS 才禁用」，上游新增了 Android APK 应用内安装，写成「非 Windows 就禁用」会误伤。

### 17. iOS 存储路径只读展示（图片保存路径 / Vibe 库路径改成只读 + 仅保留重置为默认 + 中文说明）

- **现在**：ios-v2: storage_settings_section.dart 的 Platform.isIOS 分支（:243/:280/:299/:417/:444/:481/:594/:631）与 l10n key settings_pathFixedIosHint
- **v4.2.1 上怎么落**：图片/Vibe/Hive 三处路径改用上游的 supportsCustomStorageDirectories => isDesktop 门控（等价，副标题走 settings_androidManagedStorage），我们自己那套实现可丢——但文案提的是 Android，iOS 上想准确可自加一条 key。注意该文件 v4.2.1 改动很大（我们这边就有 +424 行），必须逐块比对不要整文件覆盖。
- **风险**：低（能力位等价），但与下一条 tagger 目录在同一个文件里，整文件处理会连带出事。

### 18. iOS 本地反推模型目录固定为 Documents/tagger_models + shareddocuments:// 跳「文件」App 入口

- **现在**：ios-v2: local_onnx_model_service.dart:37-60 的 iosTaggerFolderName / resolveTaggerDirectory（注释写明「iOS 沙盒容器路径每次重装都会变化，且沙盒外目录的授权无法跨启动持久化」）；storage_settings_section.dart 的 _openIosTaggerFolder；配套 Info.plist 的 UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace
- **v4.2.1 上怎么落**：上游重写了该文件（+518 行），新增 getManagedTaggerDirectory() = applicationSupport/models/onnx_taggers（iOS「文件」App 不可见）+ importTaggerSelections() 的 ZIP 导入流程；而入口 _configureLocalOnnxTagger 的分支条件是 supportsManagedFileImports(=isAndroid)，iOS 落到 FilePicker.getDirectoryPath 存下一个跨启动失效的 security-scoped 路径。做法是合并：保留 resolveTaggerDirectory 让扫描路径至少包含 Documents/tagger_models，把上游的 ZIP 导入接到 iOS 并指向同一目录，supportsManagedFileImports 改成含 iOS。
- **风险**：中高。这正是用户手动挪过模型文件的那个痛点。照搬上游表面上功能还在（有应用内导入），但用户既有的使用方式失效，且已放在 Documents/tagger_models 里的模型会直接扫不到；上游的 iOS 分支更糟——界面显示「已配置某目录」但重启后扫不到任何模型。

### 19. ONNX 本地反推的两处移动端定制：intra-op 线程放开到 min(4,CPU)、opset patch 为 no-op 时短路

- **现在**：ios-v2: local_onnx_tagger_service.dart:181 的线程数、以及 _bytesEqual 短路避免把 GB 级模型整份复制到临时目录
- **v4.2.1 上怎么落**：上游 :154 仍写死 setIntraOpNumThreads(1)，:373-379 仍无条件写文件。两处原样重做，但 onnxruntime→onnxruntime_v2 换代后 setIntraOpNumThreads 的 API 需复核（1.23.2+2 的 lib/src/ort_session.dart:542 仍有该方法，同源 fork）。
- **风险**：中。不做的话手机上反推慢一倍且每次都白白复制一遍 GB 级模型。

### 20. ComfyUI 在移动端保留 + 局域网 helperText（有意偏离上游）

- **现在**：ios-v2: comfyui_settings_section.dart 的 `helperText: Platform.isIOS || Platform.isAndroid ? l10n.settings_comfyUiLanHint : null`；integrations_settings_section.dart:18-20 的注释「ComfyUI 保留：它连的是用户自己的服务器，手机连同网段的 PC 是合理场景」；配套 Info.plist 的 NSLocalNetworkUsageDescription
- **v4.2.1 上怎么落**：上游走了相反决策：platform_capabilities.dart 的 supportsComfyUiIntegration => isDesktop，integrations_settings_section.dart:86-90 把 ComfyUI 分段 enabled: i != 1 || supportsComfyUi 直接禁用并挂 tooltip「仅桌面端可用」，:100 还拦了切换。要保留就必须在消费点覆写该能力位并重新落 helperText。
- **风险**：中。这是明确的「有意偏离上游行为」，不是移动端适配；采用上游的 Krita 门控时会在同一个文件里顺手把 ComfyUI 也禁掉。需用户确认是否仍要保留。

### 21. 设置的本地配置导出/导入（exportSettings / importSettings + 存储分区的两个 ListTile）

- **现在**：ios-v2: local_storage_service.dart:48-79；UI 在 storage_settings_section.dart:40/:92；配套脚本 tool/export_content_settings.dart
- **v4.2.1 上怎么落**：上游 grep exportSettings/importSettings 零命中，走的是云同步（app_cloud_sync_adapters.dart）。纯增量直接搬。建议加两件事：导出文件写版本号、导入前确认弹窗与 key 白名单过滤（v4.2.1 新增了大量 StorageKeys，逐条 put 覆盖旧备份的风险比当初更大）。
- **风险**：低。若 iOS 上云同步（GitHub/WebDAV）可用且用户愿意用，这条可降为可选。

### 22. 角色数达官方上限时移动端添加入口的可见反馈（变灰 + tooltip + 点击 toast）

- **现在**：ios-v2: add_character_buttons.dart:21-24 与 :93-106 `_wrapDisabled`（注释「触屏没有 hover，只留 tooltip 等于没有提示，所以点击也必须有反馈」）；回归测试 add_character_buttons_limit_test.dart
- **v4.2.1 上怎么落**：上游只覆盖了另一条路径：inline_character_row.dart:558-572 的行尾添加芯片有 Tooltip + Opacity + IgnorePointer（手机角色管理面板走这条，已覆盖）。但 add_character_buttons.dart（243 行）全文仍无 limit 判断，它挂在 parameter_panel 与 web_left_panel 的 headerActions，移动端仍可达且仍静默失效。复用已有的 characterLimitReachedProvider 与 character_limitReached key（上游已有，不用新增 l10n）。
- **风险**：低。主入口已被上游覆盖，这条可降级，但上游只给 tooltip 不给 toast，触屏要长按才看得到原因。

### 23. 固定词与词库的双向同步兜底（按「修改前的内容」收养未关联的手动固定词并补写 sourceEntryId）

- **现在**：ios-v2: fixed_tags_provider.dart:692-723 的 previousContent 参数与匹配条件；tag_library_page_provider 的 updateEntry 透传；回归测试 fixed_tags_provider_test.dart
- **v4.2.1 上怎么落**：上游 fixed_tags_provider.dart:756-758 的 syncFromTagLibrary 仍只有单参数、只按 sourceEntryId 匹配；tag_library_page_provider.dart:305-315 的 _syncToFixedTags 也不传 previousContent。两个文件 churn 都很大（105/42 与 272/175），按 hunk 重放不要 copy-ours。确认不与上游新增的 resolveFixedTagImport / fixedTagResolution 冲突。
- **风险**：低。纯增量行为改进，不做的话手动创建的固定词在词库改名后不会跟着更新。

### 24. 移动端隐藏「发送到 Krita」+ 放大/增强后自动展开参数面板

- **现在**：ios-v2: image_preview.dart:114-116 的 _isMobilePlatform、:692-694 的 onSendToKrita 门控、:727-735 的 _revealWorkflowPanelOnMobile
- **v4.2.1 上怎么落**：经复核上游只做了一半：image_preview.dart:849-851 的 onOpenInExplorer 用了 supportsOpenFolder（这半可丢），但 :838-845 的 onSendToKrita 只判 canUseAsInput，image_card_actions.dart:256-261 也无条件 add——iOS 预览菜单仍会出现 Krita 项，点了弹「未连接」。补 supportsKritaBridge 即可（history_panel.dart:937/:1140 同）。_revealWorkflowPanelOnMobile 上游完全没有（image_workflow_launcher 只 setPanelExpanded，移动端点放大后屏幕上没有任何面板弹出），必须重做，但槽位要按 L4 的最终左右分工调（不能再写死 openEndDrawer）。
- **风险**：中。两项都被审计误判成 superseded；不做的话手机上点「放大」毫无反应。

### 25. 本地画廊窄屏列宽 110（390pt 给 3 列）与移动端工具栏隐藏移动/打包/元数据编辑

- **现在**：ios-v2: local_gallery_screen.dart 的 `targetCardWidth = screenWidth < 600 ? 110 : 200`；local_gallery_toolbar.dart 的 `if (!_isMobilePlatform) [...]`
- **v4.2.1 上怎么落**：上游 local_gallery_view_model.dart:43-52 是 contentWidth < 360 ? 136 : 160，390pt 手机算下来是 2 列——信息密度差三分之一，是默认值差异不是等价实现。上游 bulk_action_bar.dart:63-79 的 _CompactBulkActions 是把全部动作塞进紧凑条而非隐藏，切过去后要复核那三个动作会不会重新挤回窄屏工具条。
- **风险**：中。需用户拍板：110(3 列) 还是跟上游 160(2 列)。

### 26. 角色定位画布只对启用中的角色编号（避免锚点编号与成图对不上）

- **现在**：ios-v2: character_position_canvas.dart 的 positionableCharacters 过滤（提交 cbb4064d）
- **v4.2.1 上怎么落**：上游没修：:736 只把禁用角色画成 opacity 0.45 仍然渲染，:620/:716 仍用原始 config 下标编号，而位置来自 character_prompt.dart:355-357 的 enabled 下标——中间禁用一个角色时锚点位置对、编号错。建议改最小面（把传给 _buildAnchor 的 index 换成 enabled 列表下标，未启用不显示编号），不要整块套用我们的过滤推翻上游有意的「变暗展示」设计。
- **风险**：中。这是上游同样存在的缺陷，可考虑回馈上游。

### 27. 详情页元数据异步兜底解析 + 按钮显隐接上兜底结果

- **现在**：ios-v2: image_detail_viewer.dart 的 _metadataOf/_resolvedMetadata/getMetadataAsync（更早的 iOS 提交）+ detail_top_bar 的显隐接线
- **v4.2.1 上怎么落**：上游 detail_top_bar.dart:55 仍是 `final metadata = currentImage.metadata`（DB 快照），viewer:584-596 传参里没有任何兜底元数据；上游只修了「点了之后能不能用」（local_gallery_action_coordinator.dart:794 改用文件级 resolveLocalGalleryMetadata），没修「按钮显不显示」。给 DetailTopBar 加 metadataOverride 参数，viewer 传异步解析结果；getPlaceholderProvider/getMetadataAsync 提升为 ImageDetailData 接口成员，detail_image_page 加低清占位图。
- **风险**：中。iOS 覆盖安装后 DB 里的绝对路径失效，「复用参数」按钮会直接消失——这是 iOS 特有的问题，上游永远不会修。

### 28. 移动端跳过桌面拖放包装（history_panel / gallery_grid / local_image_card_3d 的 hover 层）

- **现在**：ios-v2: history_panel 的 iOS/Android 早退跳过 MouseRegion+DraggableMemoryImage；gallery_grid 的 dragWrapper 禁用
- **v4.2.1 上怎么落**：上游 history_panel.dart:978-994 只判 !image.canDrag 随后无条件包 MouseRegion+DraggableMemoryImage；gallery_grid.dart:344-347 的 dragWrapper 只判 widget.enableDrag，而 gallery_content_view.dart:437 是 `enableDrag: !selectionState.isActive`——也就是尚未进入选择模式时拖拽仍开着，正是长按冲突发生的时刻。条件改用 PlatformCapabilities.current.supportsExternalFileDrop（更贴上游写法）。另外 local_image_card_3d 的按钮显隐上游仍是 visible: _isHovered || _isFocused，MouseRegion 与 LocalImageHoverPreview 都无指针类型门控，触屏免疫实际来自 card_action_buttons.dart:94-117 的提前返回——iOS 上仍可能因合成 hover 触发缩放与悬浮预览卡，建议按 interactionPolicy.precisePointerAvailable 门控。
- **风险**：中。触屏 tap/长按被桌面拖放吞掉是 iOS 上很难排查的一类问题。

### 29. NAI 图像增强改用 imageGenerationDioClientProvider

- **现在**：ios-v2: nai_image_enhancement_api_service.dart 的 dio 实例替换（通用 dioClient 的 Http2Adapter 在 api.novelai.net 上连接异常）
- **v4.2.1 上怎么落**：上游 :342 仍是 `ref.watch(dioClientProvider)`。原样重做；1024 分辨率预检降级那半边丢弃（上游已整体删除该逻辑）。
- **风险**：中。这是移动端直连才暴露的 HTTP/2 问题，桌面走系统代理永远看不到，很容易被当成「与上游无谓的分叉」删掉。

### 30. sqflite 移动端也调 sqfliteFfiInit 但只在桌面覆写全局 databaseFactory

- **现在**：ios-v2: lib/core/services/sqflite_bootstrap_service.dart（含中文注释：移动端 databaseFactory 要留给 flutter_cache_manager 传递依赖的原生 sqflite）
- **v4.2.1 上怎么落**：上游该文件 v1.8.1→v4.2.1 零 diff（已 git diff 确认为空），仍是 `if (!(isWindows||isLinux||isMacOS)) { _initialized = true; return; }`。基线未变，我方版本可直接覆盖。顺带向 Android 侧确认上游图库索引库用的是哪个 factory，别两边打架。
- **风险**：低。上游有了 Android 却没改它，说明 Android 走的是另一条路径，不是等价实现。

### 31. iOS 平台工程的三项 Info.plist 配置与 .gitattributes 换行锁

- **现在**：ios-v2: ios/Runner/Info.plist 的 NSAppTransportSecurity/NSAllowsLocalNetworking + NSLocalNetworkUsageDescription（3D 编辑器 127.0.0.1 HttpServer 与 ComfyUI 局域网）、NSPhotoLibraryAddUsageDescription（gal）、UIFileSharingEnabled + LSSupportsOpeningDocumentsInPlace（用户用「文件」App 投放 tagger 模型）；.gitattributes 的 ios/Podfile.lock 与 ios/Podfile 两行 eol=lf
- **v4.2.1 上怎么落**：上游无 ios/ 目录，Info.plist 整体是我们的。.gitattributes 上游只有 6 行且无任何 ios 规则（已核对），必须以上游为底只追加我们那两行，不要用我方整文件覆盖（会漏掉上游新增的 nai_official_random_wordlists.json 与 random_tag_library.json 两条 eol=lf）。flutter_inappwebview 版本零变化，ATS 键继续有效；v4.2.1 新增的 loopback OAuth（127.0.0.1 回调）让它更必要。
- **风险**：中。.gitattributes 只有几行、最容易被整文件覆盖，而后果是 Xcode 在 11 分钟编译的末尾才报 sandbox is not in sync——上一轮已经踩过一次。

## 确认可丢（26 条）

1. **AppBranch.more（第 10 个分支）+ MobileTab 常量类 + mobileTabForBranch/branchForMobileTab 双向映射 + app_branch_test.dart 的 3-Tab 用例** — 上游 app_branch.dart:41-56 已有 mobileNavigationBranches + mobileMoreNavigationIndex=4 + mobileNavigationIndexForBranch，枚举里没有 more（更多是面板不是分支）；上游自己把 app_branch_test.dart 重写成 5-Tab 断言。两套映射不能混。
2. **app_router.dart 的 /more 分支、MobileShell→MobileBottomNavBar 替换、MainShell 按 isMobileWidth 分流** — git diff v1.8.1 v4.2.1 对该文件是 0 增 736 删——文件已删除，拆成 app_router_config.dart / app_shell.dart / mobile_shell.dart / desktop_shell.dart。无处可重放。
3. **mobile_bottom_nav_bar.dart 本体（4-Tab 底栏 + 更新红点）** — 上游 mobile_shell.dart:96-150 原生 NavigationBar，更多格已带 Badge(queueCount>0 || showUpdateBadge)，:92 键盘或 overlay 激活时整条置 null，高度随 textScaler 夹取 64~84。仅「重按当前 Tab 回分支根」这一行行为要补回 _onNavigate（已列入 mustKeep）。
4. **lib/core/utils/responsive.dart（isCompactWidth/isMobileWidth/isDesktopWidth）+ design_tokens 的 breakpointNavRail=800** — 上游 adaptive/window_size_class.dart 的 600/840/1180 三档且量的是扣掉 safePadding 的安全可用宽度，AdaptiveWindowMetrics 同时暴露 viewInsets；design_tokens 的断点常量被上游整段删除（0 增 39 删）。两套断点在 800-840 之间给相反答案（iPad 10.9 竖屏 820pt 正好落进去），必须删掉改用 context.adaptiveWindow，不要试图共存。
5. **themed_scaffold.dart 的 scaffoldKey 参数** — 上游同文件 :10/:20/:32 已有该参数，且自己在 mobile_generation_chrome.dart:237 用了 scaffoldKey: controller.scaffoldKey。
6. **nav_links.dart（Discord/GitHub 常量与 GitHubLogoPainter）** — 上游 core/constants/community_links.dart 的 URL 与品牌色与我方逐字相同，GitHubLogo 在 main_nav_rail.dart:616。account_menu.dart 只有「添加账号」那一项需要另行补到 more 面板（已列入 mustKeep），其余被 account_profile_sheet.dart 覆盖。
7. **bulk_action_bar 的 veryNarrow(<600) 横滚分支 + queue_management_page 窄屏双行** — 上游 bulk_action_bar.dart:63-79 在 maxWidth<700 时整体切 _CompactBulkActions；queue_management_page.dart:348-356 用 LayoutBuilder + WindowSizeClass.fromWidth 决定 canUseSingleRow 再走 Wrap。
8. **app_toast 的移动端底部 SnackBar→顶部悬浮机制本体** — 上游 app_toast.dart:115-119/:226-265 已是全平台统一的 rootOverlay 可堆叠顶部 toast，全文无 SnackBar，且比我们的实现更完整。仅三项交互差异需在其上重新加回（已列入 mustKeep）。
9. **prompt_assistant_overlay 的 inline 参数 + 移动端操作 sheet + 合并设置入口；prompt_editor_toolbar 的 isFullscreen** — 上游已原生 PromptAssistantPlacement{inline,editor,viewport}（:41、:624-626）并按 _usesAnchoredMenus 区分右键/触屏菜单；prompt_editor_toolbar.dart:53/75/175 已有 isFullscreen 与 fullscreen_exit 图标。
10. **prompt_input.dart 的移动端紧凑化整块（行内助手、收键盘按钮、14px 字号、maxLines 2→3）** — 该文件 345 增 2002 删、现为 457 行，_consumePendingPrompt/_syncPromptFromProvider 已搬到新建的 prompt_input_{controller,coordinator,editor,footer,models,toolbar,tooltips}.dart；收键盘上游封成 KeyboardDismissRegion。仅 raw 旁路与 unified_prompt_input 的组词守卫另立条目保留。
11. **selectable_image_card 的长按合并（onLongPressStart 单识别器）+ 菜单向上弹定位；pro_context_menu 的 maxHeight 与内部滚动** — 上游 image_card_surface.dart:70-80 与我们逐条一致（clearPendingDoubleTap → onLongPress 优先 → 否则 onShowContextMenu）；pro_context_menu.dart:47/203-206 已有 maxHeight+SingleChildScrollView；image_card_context_menu.dart:158-183 用 safeTop/safeBottom/viewInsets 算高度，比我们的 clamp 更完整。
12. **本地画廊 5 个发送项的长按底部动作表** — 上游换了更好的机制：local_image_card_3d.dart:487-505 把 LocalImageContextMenu.buildActions 全量交给 CardActionButtons，card_action_buttons.dart:94 在 usesTouchActionMenu 时渲染卡片常驻 more 按钮，长按保持「进多选」语义。两套并存会互抢手势。注意 gallery_content_view.dart 里我们加的 onReuseMetadataWithOptions 不能一起丢（上游 :594-596 仍把第二个参数丢成 `_`）。
13. **settings_screen 的移动端一级列表 + 二级页 push + 隐藏快捷键分区 + _scheduleMobileDeepLink** — 上游 settings_screen.dart:276-278 在 isCompact 时走 _buildCompactSettings，:318-386 有列表+详情 AnimatedSwitcher、PopScope 返回、section.compactEnabled 门控，并且 _onSectionSelected 按 id 而非硬编码索引——连我们记在待办里的深链索引隐患也一并解决。
14. **prompt_assistant_settings_section 的 provider 行窄屏(<520)上下堆叠** — 上游同文件 :134/:151 LayoutBuilder→Wrap、:405 Wrap、:455-457 maxWidth<720 时 useStackedLayout。
15. **从三语 arb 删除 nav_gallery** — 上游重新启用了它：mobile_shell.dart:114 `label: context.l10n.nav_gallery`。这次删除要撤销。
16. **autocomplete 弹层扣除软键盘高度与键盘升降重定位（_keyboardInset）+ 候选行窄屏密度（_compactCandidateWidth=420）** — 上游 autocomplete_wrapper.dart:536-539 用 flutterView.viewInsets 与 MediaQuery.viewInsetsOf 取最大值并做双重坐标换算，是我们实现的严格超集；completion_overlay.dart:95-97/366-368 用 touchInput && maxWidth<600 判定并把来源徽章压到 1 个/64pt。断点值与判定口径都不同，补丁无处可打。
17. **Vibe 库与精准参考库的工具栏窄屏溢出修复、空态导入按钮、卡片长按底部菜单** — 两个库整体重写成共享的 GalleryCollectionWorkspace / GalleryLibraryToolbar：vibe_library_workspace.dart:113 compact<680、precise_ref_library_screen.dart:605 persistentCategories>=840、precise_ref_card.dart:182/232-240 触屏常驻 more 按钮。原文件 vibe_library_screen_layout.dart 已删除。
18. **共现数据包管理行的窄屏 Wrap 修复** — 上游抽成公共组件 settings_data_status_tile.dart:13/22-38（compactBreakpoint=600，窄屏把按钮组挪到文本下方），修法与我们一致。
19. **透明底色浮层的 _followerDx 边界钳制** — 上游用互斥机制解同一问题：preview_info_bar.dart:310/316-333/357-362 打开前量一次 targetBox/overlayBox，据此在 topLeft/bottomLeft 与 topRight/bottomRight 之间切锚点。两套实现不能并存。取色器的 SizedBox(height:150) 裁剪也已被 color_picker.dart:145-152 的 hasBoundedHeight→Expanded 修掉（仅 onTapDown 触屏点选仍需我们补）。
20. **14 处右键入口补长按（图库/词库/Vibe 分类树、文件夹标签页）** — 上游改成触屏常驻操作按钮而非长按：category_tree_view.dart:376-380、gallery_category_tree_view.dart:441-443、vibe_category_item.dart:97-98 均按 precisePointerAvailable/shouldExposeTouchAlternatives 判定并统一 48pt；空白区「新建分类」也有了可见按钮。folder_tabs.dart 已删除。
21. **词库选择对话框的 4 列硬编码 / 800×600 固定容器修复；Vibe 编码与命名对话框的键盘溢出修复** — 三者都改走 AdaptivePresenter.showForm（窄屏自动全屏 sheet），tag_library_picker_dialog.dart:200-207 动态算 crossAxisCount 并 clamp(1,4)，两个 Vibe 对话框已包 SingleChildScrollView / ContentSizedAdaptiveForm。
22. **在线画廊网格宽度算错 60pt；AI TAG 详情窄屏嵌套无界 ListView** — 前者计算已迁到 online_gallery_grid.dart:89-94 用真实 LayoutBuilder 约束；后者所在的 ai_tag_detail_dialog.dart / post_detail_dialog.dart 已删除，新结构 gallery_detail_dialog_view.dart:118-146 给 infoPanel 有界高度（mediaHeight + Expanded），该 bug 类别不可能出现。仅标签 chip 的触屏长按入口需重新打到 gallery_detail_tag_section.dart。
23. **V5 画布入口塞进「自定义」分段 + 打开时手动 setMaximized(false)** — 上游加了独立的第三个分段（character_position_canvas.dart:462-483，ValueKey('character-position-canvas-entry') + toggle(forceExitMaximizedPrompt:)），「自定义」回到纯 setGlobalAiChoice(false)；mobile_character_manager_sheet.dart:28-33 用了与我们逐字相同的 ref.listen 自动 pop 机制；退出提示词最大化由 character_position_canvas_provider.dart:74-91 的 provider 自己处理。仅 scaffold.closeDrawer() 在保留左抽屉时必须留。
24. **pubspec.yaml 把 assets/images/ 移出打包清单** — 上游提交 377895e1 自己做了，assets/images 目录已不存在，且我们旧清单里的 assets/data/wordlists/ 也已作废。必须整段采用上游的 flutter.assets（含新增的 icons/ai_brands/ 与 data/opencc/），硬套旧清单会漏资源。注意同一文件的 gal 依赖不在丢弃范围内。
25. **ios/Podfile.lock 的既有内容（9 个 pod，onnxruntime-objc 1.15.1）** — onnxruntime→onnxruntime_v2 换代 + 新增 flutter_appauth / google_sign_in / nai_png_codec，必须在 Mac 上重新生成。上游 macos/Podfile.lock 是陈旧的（最后提交早于引入 onnxruntime_v2 与 nai_png_codec），没有可抄的 Darwin 参照。注意与这条同名的提交 28932700 改的是 .gitattributes 不是 lock，那两行 eol=lf 必须保留。
26. **Krita 门控的 _hidesKritaBridge 自建判定 / 存储路径三处的 Platform.isIOS 自建分支 / 触摸目标逐点放大** — 改用上游的能力矩阵表达：supportsKritaBridge（app.dart:111-112 连「注入测试 provider 时仍订阅」的细节都一致）、supportsCustomStorageDirectories、interaction_policy.dart 的 minimumControlExtent（touchAvailable ? 48 : 40）。我们 20 个文件 65 行的直接 Platform.is* 会让 108 个重叠文件的冲突面显著变大，且无法被 debugOverride 覆盖导致上游的 widget test 在我们分支上行为不一致——按能力语义逐处翻译，iOS 专属的新位在 platform_capabilities.dart 里新增而不是在业务文件里撒 Platform.isIOS。

## 硬风险（12 条）

### 1. nai_png_codec 的 native assets 在 iOS 上的构建链路（最大工程风险）

packages/nai_png_codec 用 hooks ^2.0.2 + code_assets ^1.2.1 + native_toolchain_c 0.19.2 的 hook/build.dart 编译 5 个 C 源（nai_png_codec.c + libspng/spng.c + miniz 三件，已亲自读过 hook 全文）。它被 lib/core/utils/image_share_sanitizer.dart:7 无条件 import，而 sanitizer 是复制/拖拽去元数据、Discord 分享、ZIP 导出、水印渲染、打码渲染五条链路的公共底层（6 个模块引用）。上游只在 release.yml:204 缓存 build/native_assets，零 iOS 构建路径，README 里写的是「Windows、Android 和 macOS」。它不通 = 构建失败，或退化 = 用户点名的「复制不带元数据」失效。

**缓解**：这条不是未知风险但也不是已完成。有力的间接证据：v1.8.1 的依赖图里已有 objective_c 9.5.0（由 path_provider_foundation 拉入），其 hook 的 supportedOSs 就是 {OS.iOS, OS.macOS}——我们那颗 61.5MB 的 IPA 本身就是跑过 iOS build hook 流水线出的包；Flutter 3.44.2 的 flutter_tools 源码也确认产物是 lipo 成单一 .framework（非 xcframework），--no-codesign 下 codesignDylib 退化为 ad-hoc `-` 签名不会 throwToolExit，framework 的 MinimumOSVersion 硬编码 13.0 低于我们的 16.0 无害。做法：L0 落地后第一件事就是在 Mac 上单独跑 flutter build ios --release --no-codesign，只看 Runner.app/Frameworks/ 下有没有对应产物。退路：在 hook/build.dart 里对 OS.iOS 提前 return，让 image_share_sanitizer 走已存在的纯 Dart _encodePng 分支（代价是复制/拖拽出图变慢），或用条件 import 切换。自签时确认签名工具递归签内嵌 framework（Sideloadly/esign/zsign 默认会）。

### 2. FileExportService 在 iOS 上每条导出路径 100% 抛 ArgumentError

已亲自读过 v4.2.1 的 file_export_service.dart：saveBytes / saveText / saveFileFromPath 的非 _isAndroid 分支都调 FilePicker.platform.saveFile(dialogTitle/fileName/type/allowedExtensions) 且不传 bytes，而 file_picker 8.3.7 的 file_picker_io.dart:148-152 明确 `if (Platform.isIOS || Platform.isAndroid) { if (bytes == null) throw ArgumentError(...) }`。影响 20+ 调用点：Vibe 导出、词库导出、统计导出、Agent 技能/配置导出、danbooru 保存、在线图库保存、诊断日志导出、精准参考导出。更糟的是 generation_image_batch_actions.dart:113 与 local_gallery_action_coordinator.dart:267 的那两处内联 FilePicker.saveFile 在 try 块之外，iOS 上是未捕获异常，用户看到的是按钮点了没反应 + 一条 fatal 上报。pickExportDirectory 落到 getDirectoryPath，iOS 返回的是跨启动失效的一次性 security-scoped 路径。

**缓解**：L2 车道给 FileExportService 加第三条 iOS 分支：saveBytes/saveText 走 getTemporaryDirectory 临时文件 + Share.shareXFiles（我们 ios-v2 已在 storage_settings_section.dart:49-55 建立了这个模式并留了中文注释）；saveFileFromPath 先读成 bytes；pickExportDirectory 在 iOS 返回 null 由调用方降级；新增 supportsDirectoryBatchExport 把「先选目录再批量写」的入口整体隐藏。同时把全仓裸 FilePicker.saveFile 调用点收编进这一个服务，不要在 UI 层直接调。

### 3. 上游 FileExportService 会收编我们已建好的 7 个「移动端走系统分享面板」调用点

ios-v2 上还有 6 处裸 FilePicker.platform.saveFile：vibe_export_utils.dart:131/624、history_panel.dart:1466、local_gallery_screen.dart:809、export_dialog.dart:616、vibe_export_dialog_advanced.dart:1410，加上 storage_settings_section 那处样板。移栽时 v4.2.1 新增的 FileExportService 会把它们收编——如果没先给它加 iOS 分支，等于把现有可用的导出换成 100% 抛异常的路径。

**缓解**：L2 与其他车道的顺序约束：FileExportService 的 iOS 分支必须先落地，收编这 7 个调用点时逐个确认 iOS 路径没丢。这是 L2 被列为其他多条车道前置依赖的原因。

### 4. .gitattributes 的 ios/ eol=lf 两行丢失 → Xcode 在 11 分钟编译末尾报 sandbox is not in sync

已亲自比对：上游 .gitattributes 只有 6 行，无任何 ios 规则；我们的版本有 `ios/Podfile.lock text eol=lf` 与 `ios/Podfile text eol=lf` 及中文注释。根仓库的 `* text=auto` 在 Windows 上会把 Podfile.lock 检出成 CRLF，而 Mac 上 pod install 写的 Pods/Manifest.lock 是 LF，Xcode 的 [CP] Check Pods Manifest.lock 做逐字节比对，症状延迟到整个编译快结束时才出现。上一轮已踩过一次（IOS_V2_REPLANT.md:100-103）。在 Mac 上重跑 pod install 不会让这两行回来。

**缓解**：L0 把 .gitattributes 当手工合并文件：以上游 6 行为底，追加我们的两行，同时保留上游新增的 nai_official_random_wordlists.json 与 random_tag_library.json 两条 eol=lf。

### 5. 云盘 OAuth 在 iOS 上整块缺失（Dart 枚举 + Info.plist 双缺）

cloud_drive_oauth_config.dart:5 的枚举是 {android, macos, windows, unsupported}，detectPlatform()(:129-134) 没有 iOS 分支落到 unsupported，diagnose() 直接返回「OAuth is supported only on Android, macOS, and Windows」，factory 因而 continue 跳过——不会崩，但 Google Drive / OneDrive 永远显示未配置。mobile_oauth_clients.dart:24-27/158-162/290-295 的构造断言也只允许 android/macos。平台工程侧：ios/Runner/Info.plist 全文无 CFBundleURLTypes（已核），即使 Dart 侧补了 iOS 分支，`com.aaalice.nailauncher.oauth://oauth2redirect/microsoft` 回调也回不来。另外这两个包（GoogleSignIn 9 + GTMAppAuth + GTMSessionFetcher + AppAuth）即使一行不调也会链进 IPA 并在首次构建时从 GitHub 拉 SPM 依赖，是纯死重。

**缓解**：本轮建议接受「iOS 无 Google Drive/OneDrive 同步」（零风险零工作量），GitHub/WebDAV 在 iOS 完整可用足以覆盖需求；但必须确认设置页的这两个 provider 入口在 iOS 是隐藏而不是留一个点了报错的按钮。若要做：枚举加 ios、detectPlatform 加分支、放宽 AppAuth 两个 client 的 platform 断言（避开 google_sign_in_ios 需要 GIDClientID/反向 client ID 那套）、Info.plist 加 CFBundleURLTypes、在 Entra 注册 iOS redirect、ios-release.yml 补 dart-define。注意 Google Drive 新连接上游自己也因审核未过而禁用了，真正有价值的只有 OneDrive。

### 6. Share Extension 与未签名 IPA 自签分发的结构性冲突

v4.2.1 的「接收从 Discord 等应用分享的图片/直链」靠 AndroidManifest 的 ACTION_SEND intent-filter + AndroidImageShareChannel.kt；app_shell.dart:252-256 的三元里桌面挂 GlobalDropHandler、Android 挂 IncomingImageShareHandler、其余平台（含 iOS）什么都不挂。iOS 要做需要独立 target + 独立 bundle ID + 各自 provisioning profile，宿主与 extension 之间传图必须走 App Group——而 App Group 属于要在 Developer Portal 显式创建并写进 entitlements 的 capability，免费 Apple ID 的 free provisioning 不支持；Sideloadly/AltStore 这类工具给 extension 重签时要么失败要么直接剥掉 PlugIns/。我们的分发方式正是 flutter build ios --release --no-codesign 出未签名 IPA 由用户自签（ios/ 目录下目前连一个 .entitlements 都没有）。

**缓解**：明确不做 Share Extension（除非用户有付费开发者账号且用固定签名工具）。改做零签名代价的 CFBundleDocumentTypes(public.image) + 已有的 LSSupportsOpeningDocumentsInPlace：app 会出现在「文件」App 和任意图片的「用其他 App 打开」列表里，只需 Info.plist 改动 + AppDelegate 实现 application(_:open:options:) 接到 IncomingImageShareService，不需要新 target、不影响自签。顺带用 UTExportedTypeDeclarations 声明 .naiv4vibe/.naiv4vibebundle，修掉「Vibe 文件在 iOS 选不到」那条旧账。现有兜底是生成页 AppBar 的导入入口（相册/文件 + 剪贴板），比 Android 多两步但功能不缺。

### 7. 旧集合 → 上游相簿的迁移在 iOS 上会整体丢成员

gallery_album_import_coordinator.dart:150-167 的迁移读的是旧集合里的绝对路径：先 getImageIdByPath(绝对路径)，失败再 File(绝对路径).exists()，两者在 iOS 容器 UUID 变化后都会失败，直接走 skippedImageCount++ 只打一行日志。审计里「相簿成员是相对图库根目录所以覆盖安装后不变」的说法只对新建成员成立，对迁移入口不成立。同一问题的更底层版本：需要真机确认 gallery_image_repository 里 images.file_path 存的是绝对路径还是相对路径——若是绝对路径，重装后相簿 JOIN 出来的路径与实际扫描到的文件对不上，相簿会全空。

**缓解**：若决定迁到相簿，先给迁移路径加 basename 或相对路径回退匹配；更正确的修法是让图库索引按相对图库根目录存 file_path（或启动时做一次 root 前缀 rebase），而不是退回我们的 basename 匹配（那会有同名文件误选的副作用）。这件事必须在 L15 真机验证里单独跑一遍覆盖安装。

### 8. 46MB tag_catalog.db 的获取、iOS 堆内存与 iCloud 备份

三个子问题：(1) CI 获取——v4.2.1 起 assets/databases/tag_catalog.db 是 133 字节的 LFS 指针，真实产物由 manifest.json 锁定的独立 prerelease 提供，上游 android-build.yml:31 已改用 scripts/prepare_bundled_database.ps1（做 URL + size 46792704 + SQLite 头 + sha256 三重校验），而我们的 ios-release.yml 用自写 bash 先 git lfs pull 再 curl 上游 raw，既烧上游 LFS 配额又不校验版本，配额用尽时 iOS CI 第一步就挂。(2) 运行时拷贝——AssetDatabaseManager._copyBundledDatabase 只给 Android 走原生流式通道，iOS 落到 rootBundle.load + writeAsBytes，整包 46MB 一次性进 Dart 堆，而 main.dart:595 刚把移动端 imageCache 压到 64MB。(3) 备份——拷出来的 db 与魔棒 SAM 模型（约 133MiB）都会进 iCloud 备份，Android 那边靠 backup_rules.xml 排除，iOS 侧我们什么都没做。

**缓解**：(1) ios-release.yml 换成 lfs:false checkout + pwsh ./scripts/prepare_bundled_database.ps1，补 verify_flutter_sources.ps1 与 verify_bundled_databases.dart（macos-15 runner 预装 pwsh）。(2) 给 iOS 补一个同名 method channel 做 Swift 侧流式拷贝，或先在真机上量一次峰值再决定。(3) 给这些派生/可重下的文件设 NSURLIsExcludedFromBackupKey 或放到 Library/Caches；同时 flutter_secure_storage 全部读写点带 IOSOptions(accessibility: first_unlock_this_device)，把 NAI token 钉在本机不随 iCloud Keychain 漫游（Android 用 backup_rules 排除了 FlutterSecureStorage.xml，iOS 无对等）。

### 9. 后台生成与 Agent 运行在 iOS 上无对等能力

Android 有 GenerationForegroundService（startForeground + PARTIAL_WAKE_LOCK）+ android_foreground_task_service.dart:21 的 Platform.isAndroid 门控，两个调用点是 image_generation_provider.dart:334 和 agent_chat_notifier.dart:1233。iOS 没有等价机制：UIBackgroundModes 里没有一项适合「持续 HTTP 轮询直到出图」，processing/fetch 是 BGTaskScheduler 的机会性调度不能用来续命当前任务，audio 是明确的滥用。实际影响是切后台/锁屏几十秒后正在飞的生成请求被挂起。

**缓解**：不要为了对齐 Android 去加 UIBackgroundModes（我们 Info.plist 现在没有，这个现状是对的），也不要把 isAndroid 改成 isMobile（AndroidForegroundTaskService 在 iOS 只会空转）。做法：生成期间通过 method channel 调 beginBackgroundTask/endBackgroundTask 争取约 30 秒；生成中切后台超时后，回前台能从已发出的请求恢复或明确报「已中断」，不留半永久 loading；iOS 上生成开始时给一次轻提示。Agent 提问通知同理——先给 show()/cancel() 补 `if (!_supported) return`（上游 show() 根本没检查，iOS 上会先弹「已通知你」再弹「通知不可用」两条打架的 toast），要做真通知则写 UNUserNotificationCenter 实现复用同一 channel 协议。

### 10. onnxruntime_v2 换代后的 iOS pod 与包体（风险中等，有正面证据）

pubspec 从 onnxruntime ^1.4.1 换成 onnxruntime_v2 ^1.23.2+2，上游注释只提 Android 16KB pages 和模拟器 ABI，未提 iOS。我们当前 ios/Podfile.lock 锁的是 onnxruntime-objc/c 1.15.1。本地反推（WD14/CL Tagger）与魔棒 SAM 抠图都依赖它。

**缓解**：从 pub.dev 原包核对过，不是推测：pubspec 的 flutter.plugin.platforms 明确列了 ios: ffiPlugin: true；ios/onnxruntime_v2.podspec 是 `s.dependency 'onnxruntime-objc', '1.23.0'`（trunk 上确实存在）+ platform :ios, '11.0' + static_framework；bindings.dart:10-12 的 iOS 分支返回 DynamicLibrary.process() 与 static_framework 一致；API 与旧包同源（同为 gtbluesky/onnxruntime_flutter 的 fork），setIntraOpNumThreads / OrtValueTensor 等都在。做法：Mac 上 pod install 重生成 Podfile.lock 并提交（注意 .gitattributes 的 eol 规则必须已就位），确认 podspec 最低版本 ≤16.0，出包后对比 IPA 体积（61.5MB 基线，ORT 1.15→1.23 通常显著增大），真机跑一次推理确认 CoreML EP 正常。

### 11. flutter_driver 被放进 dependencies（不是 dev_dependencies）

上游 pubspec.yaml:13-15 把 flutter_driver 放在 dependencies 段，lib/main.dart:6 无条件 import driver_extension.dart，:570 用 const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER') 包住调用。常量条件在 AOT 下会被 tree shake，拖进来的 fuchsia_remote_debug_protocol/webdriver/sync_http 也都是纯 Dart 无原生实现，理论上 release 没问题——但 flutter_driver 官方定位是不进 release 包，上游只在 Android/Windows 上验证过。

**缓解**：零成本可证伪：就在 L15 的第一次 flutter build ios --release --no-codesign 时顺带确认能编过，不需要单独安排。若真报错，最小改法是把 driver 扩展挪到条件导入后面，而不是把 flutter_driver 挪出 dependencies（那会和上游分叉，后续移栽更麻烦）。

### 12. 明文 HTTP：Android 全局放行，iOS 只放开了 RFC1918 局域网

AndroidManifest.xml:20 是 android:usesCleartextTraffic="true" 无条件允许任意明文 HTTP。我们 Info.plist 的 NSAppTransportSecurity 只有 NSAllowsLocalNetworking，覆盖 localhost、*.local、不带点主机名和私网 IP——同网段 ComfyUI（http://192.168.x.x:8188）没问题，但通过公网域名或内网穿透暴露的 http:// ComfyUI/反代、以及任何 http:// 的自定义 API base URL 会被 ATS 静默拒绝，表现是「连不上」而没有可辨别的错误。

**缓解**：域名是运行时输入，NSExceptionDomains 在 Info.plist 里做不到，实际只有两选：维持现状并在 ComfyUI/自定义 API 连接设置里明确提示「iOS 仅支持 https 或同网段 http」，或加 NSAllowsArbitraryLoads=true（对未签名自用分发无审核风险，但整体降低传输安全）。需用户拍板。

## 待用户拍板（12 条）

1. 【分发能力】要不要做 Share Extension（从 Discord/相册直接分享进 app）？成本明确偏高：需独立 target + 独立 bundle ID + App Group，而 App Group 在免费 Apple ID 的 free provisioning 下不可用，多数自签工具默认会剥掉 PlugIns/，做了也大概率在你手里不生效还把每次自签的失败面积放大一倍。建议改做零签名代价的 CFBundleDocumentTypes(public.image)+「用其他 App 打开」，功能上比 Android 多两步。确认？

2. 【云同步】Google Drive / OneDrive 在自签 IPA 上做不做？现状是 iOS 落到 unsupported（不崩，永远显示未配置），GitHub/WebDAV 完整可用。要做的成本是：Dart 枚举加 iOS、放宽 AppAuth client 断言、Info.plist 加 CFBundleURLTypes、去 Entra 注册 iOS redirect、CI 补 dart-define。注意 Google Drive 上游自己也因审核未过禁用了新连接，真正有价值的只有 OneDrive；另外 Google 的 iOS OAuth client 会绑定 bundle id，自签换 bundle id 就失效。你目前用 GitHub 还是 WebDAV？

3. 【上游关系】ios-v3 是继续留在私有仓库，还是给上游发 PR？有几条是上游同样存在的缺陷、适合回馈：角色定位画布禁用角色的编号错位（canvas:620/716 用原始下标而位置按 enabled 下标算）、词库卡片 entry_card.dart 的 onSend 死回调（声明了从不引用，全平台不可达）、取色器只有 onPan 没有 onTapDown（触屏必须拖动才生效）、image_preview.dart:838 的 onSendToKrita 漏门控、agent_question_notification_service 的 show() 不检查 _supported。你有 push 权限吗？

4. 【底栏】底栏要 4 个 Tab（生成/图库/在线/更多，我们现在的）还是上游的 5 个（生成/图库/探索/词库/更多）？上游第 4 格是独立的「词库」Tab，我们把词库放进了「更多」。改成 4 格只需动 app_branch.dart:42-47 的 mobileNavigationBranches 去掉 tagLibrary 并把 mobileMoreNavigationIndex 改成 3。

5. 【更多入口】「更多」要整页（我们现在的 /more 分支页，可深入子页且保持 Tab 高亮）还是上游的底部弹出面板？上游方案少一个 branch、少一套映射、底栏能随键盘隐藏，功能上不缺（面板里同样能 go 到次级分支）。我倾向上游，但这是你每天点的东西。

6. 【图库分组】上游新增了可嵌套逻辑相簿（子相簿、拖拽归类、sidecar 跨设备恢复），我们有自己的扁平「集合」筛选左抽屉。两者是同一问题域的两种解法：保留两套会让你同时看到两组分组；迁到相簿功能更强但迁移那一刻会丢成员（迁移读绝对路径，iOS 重装后全失败）。保留集合 / 迁到相簿（先修迁移）/ 两套并存？

7. 【画廊密度】本地画廊窄屏列宽：我们是 110（390pt 手机 3 列），上游是 160（2 列）。一屏图片数差三分之一。保留我们的 3 列？

8. 【ComfyUI】上游把 ComfyUI 在移动端整段禁用了（supportsComfyUiIntegration => isDesktop，分段变灰挂「仅桌面端可用」tooltip）。我们当初的判断相反——手机连同网段的 PC 是合理场景，Info.plist 也为此加了 NSLocalNetworkUsageDescription。保留我们的行为（需覆写能力位并重新落局域网提示）还是跟上游？

9. 【网络安全】要不要在 Info.plist 加 NSAllowsArbitraryLoads？不加的话，通过公网域名或内网穿透暴露的 http:// ComfyUI/自定义 API 在 iOS 上会被静默拒绝且没有可辨错误（同网段私网 IP 不受影响）。加的话整体降低传输安全，但对自用未签名分发没有审核风险。

10. 【复制默认值】经核实「复制不带元数据」在上游是靠打开「保护模式」实现的，而 protectionMode 默认 false——也就是新装机第一次复制仍会带元数据（我们的顶栏 clean 按钮会绕过它，所以日常不受影响）。要不要顺手把 assetProtectionMode 在 iOS 上的默认值改成 true？那会是一条新的有意偏离，需要单独记账。

11. 【CI 成本】上游 6 个 workflow，我建议删 4 个（online-gallery-live-contract 有 cron 定时烧分钟、release 监听 push v* 会与我们的 ios-v* 撞车且跑 windows+macos、pull-request-validation 有三个 windows-2022 分片最贵、cooccurrence-data-pack 有 contents: write 会往 fork 发 Release），保留 android-build 和 windows-portable（均纯手动、零成本，前者是验证我们改的 lib/ 没破坏移动端的唯一手段）。同意？

12. 【清理范围】要不要把我们 20 个文件里的 65 行直接 Platform.is* 按能力语义翻译成 PlatformCapabilities？好处是与上游纪律一致、后续移栽冲突面小得多、上游新增的一批 widget test 能用 debugOverride 覆盖；成本是一条独立车道的工作量。做还是先留着？

