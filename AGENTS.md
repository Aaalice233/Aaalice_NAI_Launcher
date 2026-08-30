# 项目协作指南

## 项目结构与模块组织

这是 NovelAI 的 Flutter 跨平台客户端。主应用按 `core`、`data`、`presentation` 分层，平台工程、资源、测试和工具各自独立；新增代码应放入现有职责最接近的目录，不在仓库根目录堆放临时实现。

```text
Aaalice_NAI_Launcher/
├── lib/
│   ├── core/               # 网络、存储、数据库、缓存、通用服务与基础能力
│   ├── data/               # API 数据源、业务模型、仓库与领域服务
│   ├── presentation/       # 页面、组件、Riverpod providers、主题与路由
│   └── l10n/               # ARB 源文案及 Flutter 生成的本地化代码
├── assets/                 # 图片、翻译、数据文件与随包 SQLite 数据库
├── fonts/                  # 应用字体
├── test/                   # 与 lib 分层对应的单元测试和 widget tests
├── scripts/                # 构建、打包、发布、开发会话与诊断入口脚本
├── tool/                   # 数据构建、验证、迁移与一次性开发工具
├── krita_plugin/           # Krita 桥接与插件代码
├── windows/                # Windows Runner 与原生工程
├── macos/                  # macOS Runner 与原生工程
├── android/                # Android Runner、原生文件/相册/更新桥接与平台资源
├── installer/              # Windows 安装器配置
├── .github/workflows/      # PR 验证与 Release CI
├── l10n.yaml               # Flutter 国际化生成配置
└── pubspec.yaml            # Dart/Flutter 依赖、版本与 assets 声明
```

`tool/.tmp/` 只存放可删除的本地临时产物，不得提交。移动或新增 assets 后同步检查 `pubspec.yaml`；修改 ARB 后保持中/英/日文案键一致并重新生成本地化代码。

## 构建、测试与开发命令

项目使用 Flutter `>=3.35.0`、Dart `>=3.10.7`，当前 CI 固定 Flutter `3.44.2`。拉取仓库后必须安装 Git LFS，并获取唯一内置数据库 `assets/databases/tag_catalog.db`。Windows 构建还需要 Visual Studio 2022 的 Desktop development with C++、已加入 `PATH` 的 NuGet CLI；macOS 构建需要完整 Xcode 与 CocoaPods；Android 构建需要 JDK 17 和 Android SDK，最低运行版本为 Android 7.0（API 24）。

`pubspec.lock` 中的 hosted package URL 必须保持为 `https://pub.dev`，与 GitHub CI 一致；本地可使用 `PUB_HOSTED_URL` 镜像下载，但不得提交镜像 URL 对 lockfile 的机械改写。

```powershell
git lfs install
git lfs pull --include="assets/databases/tag_catalog.db"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
flutter run -d <android-device-id>
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run_flutter_tests.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1
flutter analyze
flutter build windows --release
flutter build apk --release
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_nuget.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-dev-sessions/scripts/windows_runner.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-dev-sessions/scripts/android_runner.ps1 -EmulatorId Aaalice_API35
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-hot-reload/scripts/control.ps1 -Action Status
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-hot-reload/scripts/control.ps1 -Action Reload -Target All
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-hot-reload/scripts/control.ps1 -Action Restart -Target All
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-hot-reload/scripts/control.ps1 -Action Logs -Target All -Last 200
pwsh -NoProfile -ExecutionPolicy Bypass -File .pi/skills/aaalice-runtime-verify/scripts/android_verify.ps1 -Name <scenario> -HotReload -Action "tap:x,y","wait:500"
```

Windows release 产物位于 `build/windows/x64/runner/Release/`。macOS 使用 `flutter build macos --release`，产物位于 `build/macos/Build/Products/Release/Aaalice NAI Launcher.app`；本地 Keychain 反复授权时使用 `scripts/create_macos_dev_cert.sh` 与 `scripts/dev_run_macos_signed.sh debug`。Android 通用 APK 位于 `build/app/outputs/flutter-apk/app-release.apk`；推送 `v*` Tag 时由 `.github/workflows/release.yml` 构建并发布正式签名 APK，`.github/workflows/android-build.yml` 仅用于按需手动构建可安装 APK 与 SHA-256 Actions artifact。

项目热重载与按需运行验收由 `.pi/skills/` 中的三个项目 skill 管理：`aaalice-dev-sessions` 负责通过 Orca 创建、复用和关闭唯一的 `PC热重载` / `安卓热重载` 终端；`aaalice-hot-reload` 负责判定并触发 `r`、`R` 或完整重建，随后按 Orca cursor 增量读取两端日志；`aaalice-runtime-verify` 在用户明确要求自动化验收时负责真实 UI 自动化与布局检查。Agent 不得另开第二个 `flutter run` 或 `flutter attach`，仓库 `scripts/` 下不再保留项目热重载入口。

为本项目创建 Orca worktree 会话时，用户未明确指定 Agent 则默认使用 `pi`；仅在用户明确要求时改用其他 Agent。

普通 Dart 方法、Widget 布局、样式和文案使用 `Reload`；状态字段、`initState`、Provider/依赖注入、路由/启动流程、静态缓存或生成 Dart 代码使用 `Restart`；依赖、Windows C++/插件注册、Android Kotlin/Manifest/Gradle/插件注册变化必须重建受影响会话。共享代码默认作用于 `All`，平台实现只作用于对应端。

### Windows 窗口稳定性

- 主 Runner 必须在 `WM_SIZE` 和 `WM_WINDOWPOSCHANGED` 后排队重新对齐 Flutter child view；不得只依赖 `WM_SIZE`。否则外层主 HWND 恢复后，内部 `FLUTTERVIEW` 可能仍停在 Windows 最小化哨兵坐标 `-32000,-32000`，表现为旧画面冻结、按钮 hover 不消失、点击无响应或出现调整尺寸光标。
- 调试“窗口可见但无法操作”时必须分别检查顶层 `FLUTTER_RUNNER_WIN32_WINDOW` 与其 `FLUTTERVIEW` 子窗口的 rect、enabled、capture 和 hit-test；不能只根据 Flutter 日志或外层 HWND 状态判断。
- 修改插件版本或 Windows C++ 后必须完整重建。Orca 会话显示 `running` 或留有 PID 不等于构建成功；应确认控制台出现原生构建成功/启动标记、真实 `nai_launcher` 进程存在，依赖变化时再核对插件 DLL 时间戳，然后才让用户复现。

用户明确要求自动化运行验收时，两个 runner 通过 `--dart-define=ENABLE_FLUTTER_DRIVER=true` 启用仅限开发会话的 Flutter Driver extension，供官方 Dart and Flutter MCP server 在不抢占用户键鼠和桌面焦点的情况下截图、点击、输入、滚动与检查运行中 Flutter UI。禁止使用 Computer Use。稳定场景应固化为 `integration_test`；Android 系统界面场景使用 ADB。Android 项目 emulator 首次使用无 Quick Boot 快照、host GPU、无设备外框的干净启动，之后默认保留并复用暖机实例；复用前停止旧 App 并返回 Home，显式传 `-StopEmulatorOnExit` 时才跟随会话关闭。`-DeviceId` 仅用于明确复用外部设备。

## 代码风格与命名约定

遵循 `analysis_options.yaml` 和 Dart 默认格式化规则，使用两个空格缩进。变量和方法使用 `lowerCamelCase`，类型使用 `UpperCamelCase`。Riverpod provider 命名应以 `Provider` 或 `NotifierProvider` 结尾。新增功能优先复用现有 service、provider、widget 和 utility，保持 `core`、`data`、`presentation` 的职责边界清晰。

### Pi Harness 上游对齐

`lib/core/agent/harness/` 及其持久会话协议以 Pi 官方实现为唯一事实来源。排查 Harness 问题时必须先查看本机已安装的 `@earendil-works/pi-agent-core` 源码及 `https://github.com/earendil-works/pi` 对应实现，并以官方行为为准定位和修复；修改 Harness 的类型、记录格式、状态归约、恢复/续跑、队列、回放、错误语义或存储约束时，能够移植的直接等价移植，并同步相关 conformance/regression tests，不得自行发明替代协议、额外 outcome 或自动修复语义。Launcher 特有的 UI 和业务适配放在 Harness 边界之外；若 Pi 尚未实现某项能力，应明确保留边界，不在 Harness 内创建第二套事实来源。

### Dart / Flutter 代码组织约定

1. **关注文件规模**：行数是职责和可维护性的风险信号，不是强制拆分门槛。业务代码接近 800 行时关注职责、可读性和后续扩展成本；超过 1000 行时必须仔细评估是否应按职责拆分。若文件仍保持单一职责和高内聚，或拆分会制造更差的跨文件耦合，可以保留并说明理由；不得仅为满足行数机械拆分。生成代码、大型枚举和静态常量表不参与规模判断。
2. **一个文件只做一件事**：文件职责必须能用一句话说清；说不清，或同时承担多个独立职责，就应按职责拆分。
3. **页面只负责组装**：页面 Widget 只组织布局、状态和事件入口；对话框、列表 item、复杂区块拆成独立文件，业务逻辑放入 ViewModel、Cubit、Notifier 或对应 service，不写进 Widget。
4. **及时拆方法和 Widget**：方法超过 50 行应检查职责，超过 100 行必须拆分；`build` 嵌套超过 3～4 层，或主体需要滚动才能读完时，抽取具名子 Widget，避免堆叠匿名 builder。
5. **目录按功能聚合**：在既有 `core`、`data`、`presentation` 分层内按功能组织，例如 `features/auth/`、`features/home/`；禁止用单个 `widgets.dart`、`utils.dart` 收纳所有不相关实现。
6. **克制使用 `part` / `part of`**：仅在必须共享私有成员或框架约定要求时使用；同一逻辑单元的 part 文件合并计算规模，不得用它把 800 行代码伪装成数个小文件。

> 文件长不代表产出多；越长，越没人敢改。拆分的目标是让职责清楚、修改安全，而不是机械追求行数。

## UI 设计语言

新增或修改界面必须遵循仓库根目录的 [`design.md`](design.md)。项目采用 Quiet Layered Utility（静谧层叠工具界面）：内容优先、无边框优先、细边框兜底，主要通过排版、留白和低对比色面建立层级。普通卡片、工具按钮、导航项与已填充控件不得默认添加完整描边；主题个性不得破坏统一的信息层级、交互状态、密度、响应式和可访问性规则。

所有共享 UI 从设计阶段起必须同时覆盖 Windows/macOS 桌面端和 Android 手机、横屏、平板/大屏，不能先完成桌面版再以缩放、裁切或静默删减功能得到移动版。业务能力、字段语义、状态和操作结果保持跨端一致；导航容器、面板呈现和输入方式可按 constraints 与设备能力自适应。桌面端保留鼠标、触控板、键盘、hover、快捷键和上下文操作效率；移动端提供不依赖 hover/右键/外接键盘的触屏等价入口，并正确处理 `SafeArea`、系统返回、横竖屏、软键盘和系统手势区。共享业务组件、Provider、路由状态和操作命令必须复用，平台差异集中在导航壳层、capabilities/service 与 conditional import，不在页面散落 `Platform.isAndroid` 或复制业务流程。

## 在线画廊顶栏布局约束

在线画廊顶栏在能够承载工具栏的桌面/平板宽度按控件职责固定分行，不允许按站点自由重排；紧凑手机端可改用触屏友好的分层筛选面板，但必须保留相同的全局/来源专属职责边界和全部操作能力。实现位于 `lib/presentation/screens/online_gallery/online_gallery_screen.dart`，布局回归测试位于 `test/presentation/screens/online_gallery/online_gallery_source_auth_test.dart`。

- 第一行只放且始终保留全站点共用控件：站点选择、搜索/热门/收藏模式、年龄分级、搜索框、黑名单、输出过滤、随机、刷新、多选和账号入口。QuickTagCloud 法典、AI TAG 等来源不得把其中任何控件挪到第二行。
- 第二行只放当前站点专属筛选与操作，例如法典浏览/更新/最近浏览/法典/分类/筛选/贡献者，以及其他来源自己的榜单周期、日期或来源筛选。
- 第一行采用三段式布局：站点/模式/年龄分级固定在左侧；搜索框位于中间并动态填满剩余空间；从黑名单、输出过滤开始的全部操作固定为右侧组并贴右排列。不得在搜索框与右侧组之间留下弹性空白。
- 常规桌面宽度保留按钮的图标与文字；窄屏可压缩为短文字或分级缩写，但不得退化为含义不明的纯图标。
- 宽度不足以维持可用搜索空间时让第一行整体横向滚动，并给搜索区域保留中等宽度；控件仍属于第一行，禁止通过换到第二行、塞入站点筛选弹窗或按来源创建例外来解决溢出。
- 站点筛选弹窗只能包含第二行的站点专属内容，不得重复或收纳黑名单、输出过滤等全局控件。
- 修改顶栏后必须覆盖至少 `700`、`840`、`1180`、`1600` 宽度，并断言所有全局控件与第一行纵向中心一致、无 `RenderFlex overflow`；QuickTagCloud 必须单独作为回归场景。

## 测试规范

测试使用 `flutter_test`，需要 mock 时使用 `mocktail`。测试文件以 `_test.dart` 结尾，并放在对应功能路径下，例如 `test/core/utils/`、`test/data/services/`、`test/presentation/providers/`。UI 行为变更尽量补 widget test；状态管理、请求构造、文件处理等逻辑变更应补 provider 或 service 回归测试。

测试必须快速、确定且可终止：禁止在 Widget test 中依赖真实时间长轮询、未受控 isolate、网络、平台插件、文件选择器或无法取消的 `tester.runAsync` 链；这类跨异步边界的完整流程应拆成可直接测试的 service/utility。单测不得把默认十分钟超时当作等待机制，不得在失败后遗留 timer、isolate、进程、ProviderContainer 或未完成 Future。新增测试正常环境下单文件应在 30 秒内结束；若做不到，应先简化被测边界，而不是提高超时。

`dart_test.yaml` 将单个测试硬限制为 30 秒并把默认并发限制为 4。禁止直接运行无总时限的 `flutter test`：全量测试统一使用 `scripts/run_flutter_tests.ps1`，总时限最多 600 秒，超时必须终止整个进程树并失败；不得提高此上限。日常局部修改优先运行 `scripts/test_affected.ps1`，每批默认 120 秒 watchdog：不传 `-Path` 时根据当前 Git 改动选择镜像测试和直接 import 受影响源码的测试；需要限制本次范围时用 `-Path "lib/foo.dart,lib/bar.dart"`，额外回归测试用 `-Include "test/foo_test.dart"`，只查看选择结果用 `-ListOnly`。测试卡住或超时后禁止原样重跑；先终止残留进程树，定位未完成异步资源，并修复或删除脆弱测试。

### 按需 Android 运行时验收

仅当用户明确要求 Agent 执行自动化运行验收时，使用本节流程；普通 UI 修改不默认启动真机、emulator、自动点击或截图验收。

Android 系统界面快速回归使用 `.pi/skills/aaalice-runtime-verify/scripts/android_verify.ps1`：`-HotReload` 后约 1.2 秒开始操作，`-Foreground` 只把现有应用带回前台，`-Action` 接受 `tap:x,y`、`text:value`、`key:KEYCODE`、`swipe:x1,y1,x2,y2,duration` 和 `wait:milliseconds`。脚本会清理日志基线并保存截图、窗口树、Activity 状态和有界日志，发现 overflow、Flutter rendering exception 或原生崩溃时失败。

运行时交互统一使用 `adb` CLI，并尽量在一条 PowerShell 命令中批量完成一个确定场景的点击、输入、等待、状态采集、截图和日志读取，避免逐个命令往返。操作前先用 `uiautomator dump` 和当前窗口信息确认页面、文本与控件边界；点击坐标必须来自本次设备的实际树或截图，不得把某一分辨率的坐标当作跨尺寸稳定选择器。常用命令包括 `adb shell input tap/text/keyevent/swipe`、`adb shell uiautomator dump`、`adb shell dumpsys window`、`adb exec-out screencap -p` 和 `adb logcat`。

每个关键场景至少验证：目标 Activity/窗口仍在前台、预期控件或文案可见、操作后状态正确、截图无截断/重叠/overflow、日志无新的 Flutter exception 或原生崩溃。UI 验收必须先建立“页面 × 子部件 × 可操作状态 × 展开层级”的覆盖矩阵，不能以访问顶级页面和各截一张首页图代替：进入页面后必须实际操作所有可达的选项卡、模式切换、折叠区、抽屉、菜单、筛选、详情、弹窗和编辑态；生成页还需覆盖文生图/图生图、参数、正负提示词、固定词、角色 0/1/多角色及角色编辑、随机模式、历史和 Agent 等状态。空态、有数据态、窄屏、键盘态及展开前后会显著改变布局时应分别取证；禁止真实扣除 Anlas，临时新增的角色或编辑状态必须可撤销并在验收后恢复，不破坏用户数据。

截图生成后，当前 Agent 必须逐张实际查看并进行细粒度视觉验收，按区域检查页面四边、标题栏、导航、卡片、输入区、工具栏首尾、弹窗、底栏及展开/折叠前后状态，逐项核对布局层级、间距密度、基线与中心对齐、文字/图标对比度、首尾裁切、文字省略、控件遮挡、可点击区域、键盘/弹窗覆盖和整体观感；不能只找黄色 overflow 条，也不能因主要内容可用而忽略边缘图标、工具栏入口或低对比度次要信息。不得只确认截图文件存在、只读取窗口树，或仅把截图当作行为流程证据。每轮发现问题后由主 Agent 修复并重新采集双端截图，再让 Android / Windows 审查分别复审；循环到两端新一轮均无新增问题才可结束。场景开始前清理或记录 `logcat` 基线，结束后同时保存截图、窗口树和有界日志到 `tool/.tmp/android-e2e/`；这些文件只用于本地验收，完成后删除，不得提交。涉及横竖屏、软键盘、返回手势、系统文件选择器、分享、相册保存、权限或更新安装时，必须实际走对应 Android 系统界面，不能用 mock 结果代替。不得在未获用户明确授权时发起真实扣除 Anlas 的生成请求。

## 文档维护规范

`AGENTS.md` 必须始终不超过 500 行，这是硬性限制；新增规则前先删重、归并和精炼现有内容，只保留当前有效且可执行的项目约定。其他文档也应围绕单一稳定主题，不持续堆放历史审计、迁移过程、重复示例或临时结论。除天然累积或机器生成的 `CHANGELOG.md`、第三方许可/来源清单、版本发布记录等材料外，Markdown 文档原则上控制在 500 行以内；仍需拆分时按稳定职责建立独立文档和明确索引，禁止为规避行数机械切片或复制内容。修改中英文用户文档时继续遵守双语同步要求。

## 资源、生成文件与发布注意事项

`assets/databases/tag_catalog.db` 是唯一通过 Git LFS 管理并随应用提供的数据库，发布前应确认它是真实 SQLite 数据库而不是 LFS pointer。原始标签/翻译/共现 CSV 不得放回 `assets/`；`assets/translations/` 已废弃。`assets/data/` 和 `assets/images/` 会随 Flutter assets 打包，移动或重命名后需要同步检查 `pubspec.yaml`。发布前确认 `CHANGELOG.md`、`dist/release_notes_<tag>.md`、`pubspec.yaml` 版本号和 Windows release build。

CI 与 Release checkout 不直接消耗 GitHub LFS 流量；`scripts/prepare_bundled_database.ps1` 从 `assets/databases/manifest.json` 锁定的独立 `autocomplete-data-tag-catalog-*` prerelease 下载同一份数据库，并在替换 LFS pointer 前校验固定 URL、大小、SQLite 文件头和 SHA-256。数据 release 不得设为 latest，数据库版本变化时必须同步更新 LFS 对象、manifest 与独立数据 release。

随机词库维护两条独立且可验证的数据来源：官网模式使用 `tool/random_tag_library/source_lock.json` 固定的 NovelAI 前端副本可重复生成官方词库资产，必须完整保留原始记录、重复项、顺序、权重、条件与排除字段，但不得提交前端脚本副本；自定义/扩展模式继续只维护 `assets/data/random_tag_library.json` 中的声明式语义分类规则，候选标签来自完整的 `tag_catalog.db`。混合模式必须让两套来源真实生效。更新任一来源时同步更新 lock 中的源文件名称、大小、SHA-256、数组及分组计数、输出 schema/hash、catalog 来源与完整分类计数，并运行 `dart run tool/random_tag_library/verify_random_tag_library.dart`；校验未通过不得提交。

共现数据包只能通过 `tool/database/build_cooccurrence_only.dart` 从 `tool/database/cooccurrence_source_lock.json` 固定的完整源构建，产物写入 `tool/.tmp/cooccurrence/`，不得提交 `.db`、`.gz` 或源 CSV。完整构建必须通过哈希确定性、记录数、SQLite、查询计划、160 MiB 数据库和 80 MiB GZip 门槛；客户端只提交 `assets/data/cooccurrence_data_pack_manifest.json`。数据版本变化时手动运行 `.github/workflows/cooccurrence-data-pack.yml`，使用独立的 `autocomplete-data-cooccurrence-*` prerelease tag 发布，不得并入普通应用 Release 或设为 latest。

## Changelog 与 Release Notes 规范

`CHANGELOG.md` 是 GitHub Release notes 的“更新内容”来源。日常开发和普通代码修改不要逐次更新 Changelog；只在准备发布新版本时统一重写目标版本段落。

发布前必须在代码全部提交后运行 `scripts/prepare_changelog_review.ps1`。脚本默认对比上一个可达的 `v*` tag 与当前 `HEAD`，并在 `tool/.tmp/changelog-review/` 生成提交/文件审查报告和完整 diff。必须同时阅读两份材料、按变更文件反向核对，不能只根据 commit 标题总结，然后把本版本全部用户可见变化整理进对应版本段落，例如 `## [1.0.0] - YYYY-MM-DD`。

更新日志的差异审查、归类、撰写和完整性复核必须由当前主 Agent 亲自完成，禁止启动或委派任何子代理；这属于发布流程中的单一职责任务，不得为了并行分析而拆分。

Changelog 条目应面向用户描述结果，不要只写内部实现名。常用分类为 `### ✨ 新增`、`### 🛠 改进`、`### 🐛 修复`，必要时才增加 `### ⚠️ 注意`。同一新功能开发期间的内部修复应合并描述最终结果，不要暴露用户从未使用过的中间损坏状态。不要在 `CHANGELOG.md` 中写发布文件列表；安装版、便携版、macOS 包说明由 `scripts/generate_release_metadata.ps1` 自动生成，避免 Release notes 重复。

准备发布时需要检查：

- 当前版本段落是否覆盖登录、更新、生成、画廊、词库、设置、启动、安装包等用户实际能感知到的变化。
- bug 修复是否写成用户看到的问题和结果，例如“修复 Token 登录后无法获取会员状态”，而不是只写接口名或类名。
- 新功能开发期间顺手修掉的问题，如果用户从未用过损坏版本，可以合并进新功能描述，不必拆成多条。
- `CHANGELOG.md` 中不要重复自动生成的下载文件表；Release 页面会自动附带文件说明、校验文件和更新内容。

## 发布流程

1. 切换到 `main`，拉取最新代码，确认所有待发布修改均已提交且工作区干净。
2. 更新 `pubspec.yaml` 版本号；tag 必须等于去掉 `+build` 后的版本，如 `1.0.0+17` 对应 `v1.0.0`。
3. 运行 `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/prepare_changelog_review.ps1`，根据报告与完整 diff 重写版本日志并提交。
4. 运行 `dart run tool/tag_catalog/verify_bundled_databases.dart`，确认 LFS 数据库是真实 SQLite 文件；按风险运行测试、分析和 release build。
5. 创建并推送 `v*` tag。GitHub Actions `Release` workflow 会构建 Windows Setup、Windows Portable、macOS Portable 与签名 Android APK，并生成 `release_manifest.json`、`checksums.txt` 和 Release notes。
6. Windows 本地打包使用 `scripts/package_windows_release.ps1`；签名使用 `scripts/sign_windows_binary.ps1`。Windows CI secrets 为 `WINDOWS_SIGNING_CERT_BASE64` 与 `WINDOWS_SIGNING_CERT_PASSWORD`。Android 正式发布必须配置 `ANDROID_SIGNING_KEYSTORE_BASE64`、`ANDROID_SIGNING_KEYSTORE_PASSWORD`、`ANDROID_SIGNING_KEY_ALIAS` 与 `ANDROID_SIGNING_KEY_PASSWORD`；缺少任一项时 Release workflow 必须失败，不得发布调试签名 APK。

## README 双语同步规范

`README.md`（简体中文）与 `README.en-US.md`（English）只面向最终用户，保留产品简介、功能、界面、平台、下载安装、隐私、支持和致谢；构建命令、项目结构、开发约定、发布流程等维护者内容统一写在 `AGENTS.md`，不要再放回 README。

两份 README 内容必须保持同步：任一用户可见功能、平台支持、安装方式或隐私说明变化时，在同一提交中同时更新。两份文件顶部均保留语言切换链接；英文版只翻译中文版事实，不自行增删承诺。

## 提交与 Pull Request 规范

Git 历史使用 Conventional Commits，例如 `fix(generation): cancel stale results`、`feat(prompt): add random mode`。提交应保持范围清晰、标题简洁。Pull Request 需要说明用户可见变化，列出已运行的验证命令，标注生成文件、LFS 资源或 assets 变更。

## 安全与配置

不要提交 NovelAI API token、账号数据、本地日志、构建产物或个人工作流文件。调试认证逻辑时避免打印完整 bearer token；如需日志，只记录 token 类型、长度或脱敏前缀。
