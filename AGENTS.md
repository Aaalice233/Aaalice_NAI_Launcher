# 项目协作指南

## 文档职责与协作边界

- 文档入口见 [docs/README.md](docs/README.md)。本文件维护工程与协作规则；[PRODUCT.md](PRODUCT.md) 维护产品边界，[DESIGN.md](DESIGN.md) 维护视觉与交互规范，专项文档和项目 skill 维护对应实现与操作流程。
- 面向用户使用简体中文，代码、命令、路径和 API 保持原文。以当前代码、日志、配置和官方资料判断，不把旧报告当作当前证据。
- 修改前确认目录、调用方与现有内容；工作区已有改动视为用户内容，不回滚、覆盖或清理无关文件。只修复任务范围内的问题。
- 使用 PowerShell 7+；多行命令以 `$ErrorActionPreference = 'Stop'` 开始，路径统一使用 `/`，文本读取显式指定 UTF8，修改保留原有编码与换行。临时产物只放在项目明确的 `tool/.tmp/` 子目录。
- 已授权的必要准备和可撤销操作直接执行；仅在缺失信息会显著改变结果或动作超出已有授权时询问。文档中的例子不自动授权发布、外部发送或付费请求。
- 验证按影响和风险选择最小有效范围；失败先定位原始原因，不吞异常、伪造成功或为通过检查扩大修复范围。交付前审查 diff，报告实际结果和未执行项。

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

`tool/.tmp/` 只存放可删除的本地临时产物，不得提交。移动或新增 assets 后同步检查 `pubspec.yaml`；修改 ARB 后保持简中/繁中/英/日文案键一致，并通过 `flutter gen-l10n` 重新生成本地化代码。

## 构建、测试与开发命令

项目使用 Flutter `>=3.35.0`、Dart `>=3.10.7`，当前 CI 固定 Flutter `3.44.2`。拉取仓库后必须安装 Git LFS，并获取唯一内置数据库 `assets/databases/tag_catalog.db`。Windows 构建还需要 Visual Studio 2022 的 Desktop development with C++、已加入 `PATH` 的 NuGet CLI；macOS 构建需要完整 Xcode 与 CocoaPods；Android 构建需要 JDK 17 和 Android SDK，最低运行版本为 Android 7.0（API 24）。

`pubspec.lock` 中的 hosted package URL 必须保持为 `https://pub.dev`。禁止在用户级或系统级设置 `PUB_HOSTED_URL` 或 `FLUTTER_STORAGE_BASE_URL` 镜像，因为 `flutter pub get` 会据此重写 lockfile 或从非官方地址下载 SDK 资源。项目开发脚本与 GitHub Actions 固定使用官方源，提交、构建和发布前运行 `scripts/verify_flutter_sources.ps1`；发现镜像环境变量或非官方 lockfile URL 时必须失败，不得提交或发布。

```powershell
git lfs install
git lfs pull --include="assets/databases/tag_catalog.db"
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_flutter_sources.ps1
flutter pub get --enforce-lockfile
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows
flutter run -d <android-device-id>
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run_flutter_tests.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/test_affected.ps1
flutter analyze
flutter build windows --release
flutter build apk --release
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_nuget.ps1
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-dev-sessions/scripts/start.ps1 -Target All -EmulatorId Aaalice_API35
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Status
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Reload -Target All
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Restart -Target All
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Logs -Target All -Last 200
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-hot-reload/scripts/control.ps1 -Action Stop -Target All
pwsh -NoProfile -ExecutionPolicy Bypass -File .agents/skills/aaalice-runtime-verify/scripts/android_verify.ps1 -Name <scenario> -HotReload -Action "tap:x,y","wait:500"
```

Windows release 产物位于 `build/windows/x64/runner/Release/`。macOS 使用 `flutter build macos --release`，产物位于 `build/macos/Build/Products/Release/Aaalice NAI Launcher.app`；本地 Keychain 反复授权时使用 `scripts/create_macos_dev_cert.sh` 与 `scripts/dev_run_macos_signed.sh debug`。Android 通用 APK 位于 `build/app/outputs/flutter-apk/app-release.apk`；推送 `v*` Tag 时由 `.github/workflows/release.yml` 构建并发布正式签名 APK，`.github/workflows/android-build.yml` 仅用于按需手动构建可安装 APK 与 SHA-256 Actions artifact。

项目热重载与按需运行验收由 `.agents/skills/` 中的三个项目 skill 管理：`aaalice-dev-sessions` 负责让 Codex 创建、复用和关闭唯一的 `PC热重载` / `安卓热重载` 独立 PowerShell 窗口；`aaalice-hot-reload` 负责判定并触发 `r`、`R` 或完整重建，并读取两端控制台验证结果；`aaalice-runtime-verify` 在用户要求自动化验收时自动启动或复用所需会话，完成真实 UI 操作、逐张截图检查与增量日志验证。不得依赖外部终端编排器，不得另开第二个 `flutter run`、`flutter attach` 或新的 Codex task。

`build_runner` 不是常规测试或纯 Dart/UI 改动的默认验证步骤。只有改动了 Riverpod/Freezed/JSON/Drift 等生成输入，或开发 Runner 预检明确报告生成文件缺失/过期时才运行；针对性测试直接运行相关测试文件，不得为此先扫描全仓库生成代码。用户要求立即启动热重载时先执行会话状态检查和 Runner 预检，不得先跑测试或生成器；若预检阻塞且必须全量生成，应明确说明这是一次性环境准备及预计耗时，让命令完整结束后立即继续启动，不得称其为“最小验证”或反复中断重跑。生成命令中断后必须检查并恢复被删除但未重新生成的已有输出。

普通 Dart 方法、Widget 布局、样式和文案使用 `Reload`；状态字段、`initState`、Provider/依赖注入、路由/启动流程、静态缓存或生成 Dart 代码使用 `Restart`；依赖、Windows C++/插件注册、Android Kotlin/Manifest/Gradle/插件注册变化必须重建受影响会话。共享代码默认作用于 `All`，平台实现只作用于对应端。

### Windows 窗口稳定性

- 主 Runner 必须在 `WM_SIZE` 和 `WM_WINDOWPOSCHANGED` 后排队重新对齐 Flutter child view；不得只依赖 `WM_SIZE`。否则外层主 HWND 恢复后，内部 `FLUTTERVIEW` 可能仍停在 Windows 最小化哨兵坐标 `-32000,-32000`，表现为旧画面冻结、按钮 hover 不消失、点击无响应或出现调整尺寸光标。
- Flutter Windows 最小化发送零尺寸 metrics 是官方已知生命周期行为；顶层 `SIZE_MINIMIZED` 仍须通过 `HandleTopLevelWindowProc` 传递 `hidden` 生命周期，但主 Runner 不得把 iconic/零尺寸 client rect 转发给 child HWND。Flutter 壳层遇到临时无效 constraints 时必须保留同一 child element/state，并暂停 ticker、语义和交互；正常非最小化缩放仍须响应真实 constraints。
- `windows/runner/` 是受 Git 管理的项目原生源码，`test`、`analyze`、`flutter clean`、`flutter build`、Release CI 和 Flutter SDK 升级不会用官方模板还原；若删除/重建平台工程或人工同步模板，必须保留项目的 child resize、accessibility 和生命周期定制，并运行静态契约测试。
- 调试“窗口可见但无法操作”时必须分别检查顶层 `FLUTTER_RUNNER_WIN32_WINDOW` 与其 `FLUTTERVIEW` 子窗口的 rect、enabled、capture 和 hit-test；不能只根据 Flutter 日志或外层 HWND 状态判断。
- 修改插件版本或 Windows C++ 后必须完整重建。独立窗口存在或 session marker 留有 PID 不等于构建成功；应确认控制台出现原生构建成功/启动标记、真实 `nai_launcher` 进程存在，依赖变化时再核对插件 DLL 时间戳，然后才让用户复现。
- Windows 最小化会让窗口 constraints 短暂归零，响应式布局可能因此销毁并重建面板子树；滚动位置、是否跟随最新内容等必须跨 Widget/Controller 生命周期的 viewport 状态应由更高层稳定 owner 按会话保存。重建 ScrollController 时必须用保存值设置 `initialScrollOffset`，在首帧直接呈现原位置；不得先渲染默认位置再通过 post-frame `jumpTo` 恢复，否则会出现跳到底部后拉回的闪烁。

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
7. **保证 Riverpod 生命周期安全**：`ConsumerState.dispose` / `deactivate` 及 widget 已卸载后的异步回调不得读取 `ref`；销毁清理需要的 service/port 必须在 `initState` 等有效生命周期预先获取并保存稳定句柄，异步回写 UI 或 Provider 前检查 `mounted` 或对应请求世代，避免卸载阶段断言和旧响应污染。

> 文件长不代表产出多；越长，越没人敢改。拆分的目标是让职责清楚、修改安全，而不是机械追求行数。

### 云同步兼容性

新增持久化功能或设置时必须评估云同步：判断其数据是否应同步；若现有同步数据类型过于笼统、无法让用户独立控制，应细化或新增同步列表选项，并确定合理默认状态。同步方案还需验证跨版本、跨设备兼容，评估数据量及增长趋势，避免缓存、日志、索引、生成产物等使同步体积急剧膨胀；凭据和设备专属状态必须排除。

云备份不得设置“总备份大小”硬上限来回避体积问题，也不得因备份较大而静默跳过用户已选择的内容。应在数据进入备份前按业务语义减量：远程内容保存稳定 ID 与恢复必需字段，重复元数据去重，预览图等展示资源预先压缩，大型可选资源由用户独立控制；传输协议仍可保留单对象分块、并发和内存上限，但这些约束必须通过分块承载任意总量的备份。出于安全原因设置的解压体积、文件数量和响应体边界不属于备份总量限制。

本地图库图像本体不参与云备份；相簿、分类及基于稳定相对路径的成员引用可以作为独立轻量选项同步，但不得读取或上传引用指向的图像字节。在线画廊只同步用户创建的轻量状态和收藏引用，不同步远程原图、缓存、浏览历史或远程目录副本。

云同步的协议、后端能力与验证入口见 [docs/cloud_sync.md](docs/cloud_sync.md)，OAuth 配置见 [docs/cloud_drive_oauth.md](docs/cloud_drive_oauth.md)。OneDrive 与 Google Drive 云同步保持简单明文备份，不引入加密、解密、恢复密钥或 KEY 文件流程；不保留未发布加密格式的兼容、迁移或分支；已发布数据的兼容边界以当前协议和回归测试为准。保存连接只保存和验证配置，不得自动上传、拉取或恢复待处理同步，所有数据传输必须由用户显式触发。

## UI 设计语言

新增或修改界面必须遵循仓库根目录的 [`DESIGN.md`](DESIGN.md)。项目采用 Quiet Layered Utility（静谧层叠工具界面）：内容优先、无边框优先、细边框兜底，主要通过排版、留白和低对比色面建立层级。普通卡片、工具按钮、导航项与已填充控件不得默认添加完整描边；主题个性不得破坏统一的信息层级、交互状态、密度、响应式和可访问性规则。

Material 3 的中性色面必须在 `ThemeComposer` 中补全并作为跨端唯一事实来源：`surfaceContainerLowest` 至 `surfaceContainerHighest` 不得全部退化为 `surface`，缺失色阶只能从 `surface` 做中性明度变化，严禁混入 `onSurface`、品牌色、强调色或错误色。Android、Windows 与 macOS 必须消费同一套解析结果，不按平台修补普通卡片颜色；Section、Control、Overlay 分别复用 `sectionSurfaceColor`、`controlSurfaceColor`、`overlaySurfaceColor`，并用最终 `ThemeData` 回归测试验证中性色不偏红、层级可辨且切换 `TargetPlatform` 不改变语义色。

所有共享 UI 从设计阶段起必须同时覆盖 Windows/macOS 桌面端和 Android 手机、横屏、平板/大屏，不能先完成桌面版再以缩放、裁切或静默删减功能得到移动版。业务能力、字段语义、状态和操作结果保持跨端一致；导航容器、面板呈现和输入方式可按 constraints 与设备能力自适应。桌面端保留鼠标、触控板、键盘、hover、快捷键和上下文操作效率；移动端提供不依赖 hover/右键/外接键盘的触屏等价入口，并正确处理 `SafeArea`、系统返回、横竖屏、软键盘和系统手势区。共享业务组件、Provider、路由状态和操作命令必须复用，平台差异集中在导航壳层、capabilities/service 与 conditional import，不在页面散落 `Platform.isAndroid` 或复制业务流程。

### 响应式与体验实施规则

- 先明确用户主任务、首要信息和关键操作，再安排视觉层级；工具界面优先可扫描、低认知负担和高频操作效率，不用装饰抢占内容注意力。
- 遵循“constraints 向下、size 向上、parent 定位”：页面级用共享 `WindowSizeClass`，局部重排用 `LayoutBuilder`；不得用平台名、设备型号或横竖屏标签推断可用空间。
- 统一复用 `AdaptiveSlotLayout`、`AdaptiveContentBounds`、`AdaptivePresenter` 与 `InteractionPolicyScope`；能力层只描述“能否执行”，策略层决定“如何呈现”，不得在页面另建冲突断点。
- Compact/Medium/Expanded/Wide 只改变导航、分栏、密度和呈现方式，不改变业务语义。窄屏可滚动、分层或换行，但不得裁切或静默隐藏功能；宽屏限制正文/表单阅读宽度，列表和网格使用惰性构建。
- 触屏先保证关键操作显式可达且命中区不少于 44×44；桌面再保留 hover、右键、快捷键和焦点遍历作为加速器。断点切换不得丢失选择、输入、焦点、滚动位置或未提交状态。
- 每个界面同时设计 loading、empty、error、disabled、success 与长文案/本地化状态；层级优先用排版、间距和低对比色面表达，强色只用于主操作、状态和风险。动效只解释状态变化，并遵循 Reduce Motion。
- 新增或修改界面至少检查 `320/600/840/1180/1600` 宽度、`3x` 文本、短横屏、IME 与 `SafeArea`；Widget test 必须断言无 overflow、关键信息完整且全部操作可达，验证按“批量审查一次、集中修复、再确认一次”收敛。

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

### 按需自动化运行验收

用户要求自动化验收，即授权为本次成果启动或复用必要的热重载会话、正确刷新、进入相关页面、操作控件和查看截图，无需再询问是否启动或是否点击。普通 UI/文档修改不默认触发真实运行验收。

- 执行流程统一见 [aaalice-runtime-verify](.agents/skills/aaalice-runtime-verify/SKILL.md)：先 Status，缺失会话由开发会话 skill 启动；确认构建日志和真实应用进程后继续操作，不能停在“窗口已打开”。
- Windows 使用 Computer Use，Android 使用 ADB；不依赖项目级 Dart MCP。Windows 操作可能占用键鼠和焦点，开始前说明，完成后交还控制权。
- 指定平台时仅验收该端；共享 UI 未限定平台时覆盖 Windows 与 Android。按本次影响建立“页面 × 子部件 × 状态 × 展开层级”矩阵，实际打开相关菜单、弹窗和编辑态，不把局部任务扩大为全应用遍历。
- 当前 Agent 必须逐张查看截图，检查四边、工具栏首尾、文字/图标、对齐、对比、命中区、滚动及 IME/SafeArea；同时验证操作结果和增量日志。只读 UI 树或无异常日志不能替代视觉验收。
- 发现本次引起的问题后修复、刷新并复测受影响平台；恢复本次临时编辑、尺寸和方向状态。未执行的平台/场景明确标注，不借用旧测试结论。
- 验收授权不包含未授权的 Anlas 消耗、外部发送、云端数据传输或用户数据删除。临时证据仅放在 `tool/.tmp/` 对应目录，查看和报告后清理本次产物；会话默认保留供用户继续使用。

## 文档维护规范

`AGENTS.md` 必须始终不超过 500 行，这是硬性限制；新增规则前先删重、归并和精炼现有内容，只保留当前有效且可执行的项目约定。其他文档也应围绕单一稳定主题，不持续堆放历史审计、迁移过程、重复示例或临时结论。除天然累积或机器生成的 `CHANGELOG.md`、第三方许可/来源清单、版本发布记录等材料外，Markdown 文档原则上控制在 500 行以内；仍需拆分时按稳定职责建立独立文档和明确索引，禁止为规避行数机械切片或复制内容。用户说明遵守简中、繁中、英文三语同步要求；产品内 ARB 保持简中、繁中、英文、日文四语一致。

发布版本涉及大量功能或底层调整、且测试覆盖相对有限时，可以在该版本 Release Note 开头添加显著警告，客观说明可能存在尚未发现的问题；需要引导用户反馈时，统一使用“如遇异常，请通过‘设置 → 关于 → 导出诊断日志’反馈”。

## 资源与生成文件注意事项

`assets/databases/tag_catalog.db` 是唯一通过 Git LFS 管理并随应用提供的数据库，校验或构建时必须确认它是真实 SQLite 数据库而不是 LFS pointer。原始标签/翻译/共现 CSV 不得放回 `assets/`；`assets/translations/` 已废弃。`assets/data/` 和 `assets/images/` 会随 Flutter assets 打包，移动或重命名后需要同步检查 `pubspec.yaml`。

CI 与 Release checkout 不直接消耗 GitHub LFS 流量；`scripts/prepare_bundled_database.ps1` 从 `assets/databases/manifest.json` 锁定的独立 `autocomplete-data-tag-catalog-*` prerelease 下载同一份数据库，并在替换 LFS pointer 前校验固定 URL、大小、SQLite 文件头和 SHA-256。数据 release 不得设为 latest，数据库版本变化时必须同步更新 LFS 对象、manifest 与独立数据 release。

随机词库维护两条独立且可验证的数据来源：只读默认预设使用 `tool/random_tag_library/source_lock.json` 固定的 NovelAI 前端副本可重复生成官方词库资产，必须完整保留原始记录、重复项、顺序、权重、条件与排除字段，但不得提交前端脚本副本；用户自定义预设只维护 `assets/data/random_tag_library.json` 中的声明式语义分类规则，候选标签来自完整的 `tag_catalog.db`。生成时两条来源按当前预设互斥，禁止把 catalog 内容注入默认预设或合并两套结果。更新任一来源时同步更新 lock 中的源文件名称、大小、SHA-256、数组及分组计数、输出 schema/hash、catalog 来源与完整分类计数，并运行 `dart run tool/random_tag_library/verify_random_tag_library.dart`；校验未通过不得提交。

共现数据包只能通过 `tool/database/build_cooccurrence_only.dart` 从 `tool/database/cooccurrence_source_lock.json` 固定的完整源构建，产物写入 `tool/.tmp/cooccurrence/`，不得提交 `.db`、`.gz` 或源 CSV。完整构建必须通过哈希确定性、记录数、SQLite、查询计划、160 MiB 数据库和 80 MiB GZip 门槛；客户端只提交 `assets/data/cooccurrence_data_pack_manifest.json`。数据版本变化时手动运行 `.github/workflows/cooccurrence-data-pack.yml`，使用独立的 `autocomplete-data-cooccurrence-*` prerelease tag 发布，不得并入普通应用 Release 或设为 latest。

## README 多语言同步规范

`README.md`（简体中文）、`README.zh-TW.md`（繁體中文）与 `README.en-US.md`（English）只面向最终用户，保留产品简介、功能、界面、平台、下载安装、隐私、支持和致谢；构建命令、项目结构和开发约定写在 `AGENTS.md`，版本发布流程写在项目级 `aaalice-launcher-release` skill，不要再放回 README。

三份 README 内容必须保持同步：任一用户可见功能、平台支持、安装方式或隐私说明变化时，在同一提交中同时更新。三份文件顶部均保留语言切换链接；繁中版与英文版只翻译简中版事实，不自行增删承诺。

## 提交与 Pull Request 规范

提交与 Pull Request 标题使用 `type(scope): 中文描述`，scope 可选，标题不超过 72 字；type 取 `feat`、`fix`、`refactor`、`perf`、`style`、`docs`、`test`、`chore`。例如 `fix(generation): 修复取消后旧结果回写`。提交保持范围清晰；正文按需用中文 bullet points。Pull Request 使用简体中文说明改动内容、验证结果和注意事项，并标注生成文件、LFS 或 assets 变化，不填写未实际执行的检查。

## 安全与配置

不要提交 NovelAI API token、账号数据、本地日志、构建产物或个人工作流文件。调试认证逻辑时避免打印完整 bearer token；如需日志，只记录 token 类型、长度或脱敏前缀。
