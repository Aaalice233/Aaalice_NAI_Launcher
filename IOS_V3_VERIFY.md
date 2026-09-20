# iOS v3 真机验证清单

> 只能在 iPhone 真机上确认的事项。widget test 和 Mac 构建都覆盖不到这些。
> 来源：批次 2/3 各车道自报 + 集成自检汇总。勾掉一条就在前面打 `x`。

## 构建与打包（Mac 上已确认，列在这里作为回归基准）

- [x] `flutter build ios --release --no-codesign` EXIT=0
- [x] `Runner.app/Frameworks/nai_png_codec.framework` 存在，174,080 字节，arm64
- [x] install name 为 `@rpath/nai_png_codec.framework/nai_png_codec`，签名 adhoc
- [x] `onnxruntime` 符号静态链进主二进制（`nm -u Runner` 命中 19 个 ORT 符号）
- [ ] 自签后能安装，且**覆盖安装**保留沙盒数据（Bundle ID 必须仍是 `com.aaalice.naiLauncher`、同一张证书）

## 功能验证

- [ ] iPhone 真机：详情页溢出菜单点「保存到相册」，首次应弹系统「仅添加照片」权限询问 → 允许后出 image_savedToAlbum 成功 toast，照片进入系统相册；再去「设置 > 隐私 > 照片」关掉权限重试，应出 image_albumPermissionDenied 警告 toast 而不是 image_saveToAlbumFailed 的异常串（gal 在 iOS 上究竟抛 GalExceptionType.accessDenied 还是让 requestAccess 返回 false，只能真机确认）。
- [ ] iPhone 真机：生成一张图并保存，确认**没有**任何图片自动出现在系统相册（必保 #3 的核心——验证没有误接 publishToSystemGallery，桌面/Android 的行为不变）。
- [ ] iPhone 真机：打开「设置 → 分享 → 复制/拖拽时添加水印」，然后在详情页点常驻的「复制（去除元数据）」，粘贴到备忘录/其他 App，确认结果**既没有水印也没有元数据**；再点溢出菜单的「复制（含元数据）」，确认它仍带水印且带元数据（必保 #2 的正交性只能靠真机粘贴确认，Mac 上还需复核 nai_png_codec 的去元数据链路在 iOS 上真的生效）。
- [ ] iPhone 真机覆盖安装（换应用容器 UUID）后打开本地图库里的旧图：顶栏的「复用参数」按钮应在短暂延迟后出现（异步兜底解析完成），点下去能正确回填参数；覆盖安装前应立即出现。这是必保 #27 的唯一真实复现场景。
- [ ] iPhone 真机：打开一张大尺寸 PNG（≥2048px），确认原图解码前先看到低清占位图 + 右下角小转圈，而不是纯色 + 全屏转圈；并确认从**生成页/历史面板**（而非本地图库分支）打开详情页时占位同样出现（这条是我刻意不复用 LocalGalleryThumbnailProvider 的原因）。
- [ ] iPad 横屏（≥840pt，走 DesktopShell + 宽屏顶栏）：确认顶栏同时有「保存到相册」「复制（去除元数据）」「复制（含元数据）」三个按钮且不溢出。
- [ ] 「文件」App → 我的 iPhone → NAI Launcher 下能看到 `tagger_models` 文件夹；手动把 .onnx + 词表拖进去后，设置页 tagger tile 的文件数变成非 0，反推面板的模型下拉能选到它。
- [ ] 设置 → 存储 → 本地 ONNX tagger 模型，点右侧文件夹图标能真的跳进「文件」App 的该目录（验证 `shareddocuments://` scheme 在当前 iOS 版本仍可用；失败时只会静默记日志，不会报错，所以必须肉眼确认）。
- [ ] **覆盖安装 / 重装后**沙盒容器 UUID 变化，之前放在 `Documents/tagger_models` 的模型仍能被扫到（这是用户上一轮踩过的坑，也是 #18 的核心）。
- [ ] 应用内 ZIP 导入在 iOS 上落地到 `Documents/tagger_models`（不是 Application Support），导入完成后立刻能在「文件」App 里看到解出来的文件。
- [ ] 反推耗时对比：同一张图同一模型，确认 intra-op 4 线程相对单线程有实际提速；并确认第二次反推**没有**在 tmp 目录再复制一份 GB 级模型（检查 `Caches`/tmp 下 `nai_launcher_onnx_cache` 是否为空）。
- [ ] 设置页三处路径（图片保存位置 / Vibe 库路径 / Hive 存储路径）在真机上显示「iOS 沙盒限制…」且点了没有任何目录选择器弹出。
- [ ] 魔棒 SAM 抠图仍正常（与 tagger 共用 onnxruntime_v2 + CoreML EP，本次改了 session options 的线程数，属同一条推理链路）。
- [ ] iPhone 真机跑 30 分钟以上不切页面，确认从不出现更新横幅，诊断日志里没有 'Auto update check failed' 的周期性重试记录（这是 failedCheckRetryInterval 无限重试的唯一可观测信号）。
- [ ] iPhone：设置 → 关于 → 更新卡片只有一条「前往 GitHub Release 页」，点击能用 Safari 打开 releases 页；「检查更新」与「包含预发布版本」两项都不在。
- [ ] Android APK 真机（或 android-build.yml 出的包）回归：自动检查仍会触发、更新横幅仍会弹、弹窗仍显示 APK 资产卡与「下载更新」、下载后能拉起系统安装界面——这是「写成非 Windows 就禁用」会静默踩掉的那条线，编译器抓不到。
- [ ] Windows 便携版回归：横幅、检查更新入口、应用内下载与就地替换全部照旧。
- [ ] narrow 手机宽度下打开一条含 Markdown 表格的发布说明，确认表格横向可滚动且不再逐字换行（tableColumnWidth 改动的目标）；同时确认桌面端宽表格的外观变化可接受。
- [ ] NAI 图像增强改 imageGenerationDioClientProvider 之后，在 iPhone 不开代理、直连的状态下依次跑通：图像放大 / 图像增强 / Vibe 编码 / Director Tools（线稿、深度图、姿态）。这是必保 #29 的全部价值所在，模拟器和桌面都复现不了原来的 HTTP/2 故障，只有真机直连能确认修好了。
- [ ] 配置导出：在 iPhone 上点「导出配置」应弹出系统分享面板（不是另存为对话框），能存进「文件」App / AirDrop 出去；导出的 JSON 打开后第一层应是 formatVersion / exportedAt / settings 三个字段。
- [ ] 配置导入端到端：在 Windows 上 dart run tool/export_content_settings.dart 导出一份固定词+词库，传到 iPhone 用「导入配置」读入，确认固定词与词库真的出现了，且 toast 里的「跳过数」不为 0（证明白名单在工作）。另外单独验一次「导入不会把 iPhone 的图片保存路径/窗口尺寸改坏」。
- [ ] 反推面板剪贴板入口：iPhone 上先在 Safari 或相册复制一张图，回到生成页展开反推面板，点「从剪贴板粘贴图片」应直接入队缩略图；剪贴板为空或非图片时应弹「剪贴板里没有图片」而不是报错。另外确认两个按钮在 iPhone SE 宽度（375pt）下不溢出。
- [ ] 固定词双向同步：在 iPhone 上手动新建一条固定词（内容例如 masterpiece），再去词库里把同内容的条目改名改内容，回到固定词面板确认它跟着变了；再改第二次，确认第二次也跟着变（验证 sourceEntryId 确实被补写了，而不是只靠内容匹配蒙对一次）。
- [ ] 真机上打开生成页并触发一条 toast：确认它落在 AppBar 按钮行（leading + 4 个 action）下方、且这 5 个按钮在 toast 显示的 2.2 秒内全部可点。这是必保 #14 的最终判据，widget test 只能验证到几何与命中，验证不了真实刘海/灵动岛下的 SafeArea 叠加。
- [ ] iPhone 上「更多」面板 → 添加账号：确认表单能正常弹出、键盘弹起时不遮挡输入框、登录成功后表单自动关闭并出现在切换账号列表里。LoginFormContainer 的内部依赖（第三方站点卡片、安全存储）我没有在测试里实际点开，属于未覆盖路径。
- [ ] 「更多」面板 → 切换主题连点：确认深/浅两套在底部面板打开状态下即时生效，并且重启 App 后主题被持久化（toggleQuickTheme 走的是 setTheme → storage.setThemeIndex）。
- [ ] 底栏重按当前 Tab：在词库和图库两个分支的深层子页各试一次，确认回到分支根且没有把其它分支的位置一并重置。
- [ ] iPad + Apple Pencil：在本地图库网格上用笔悬停（不落笔），确认卡片不再缩放抬升、不再弹出悬浮预览卡；随后接 Magic Keyboard 触控板移动鼠标，确认 hover 呈现恢复（precisePointerAvailable 置真后该会话一直保留）。
- [ ] iPhone：在线画廊详情页打开一个多图作品，确认右侧动作栏没有「下载全部媒体」项，但单张「下载原图」仍能拉起系统分享面板并存进「文件」。
- [ ] iPhone：在线画廊进入多选，确认底部动作只剩「加入队列」「批量收藏」，没有批量下载的死按钮。
- [ ] iPhone：Vibe 库选中 ≥2 个条目导出，确认格式单选里只有「打包文件 (.naiv4vibebundle)」，选它导出能弹出系统分享面板并真的落盘；再只选 1 个，确认「单文件 (.naiv4vibe)」重新出现且导出可用。
- [ ] iPhone：对一个 bundle 走「提取内部 Vibe」，确认默认只勾第一个、没有「全选」按钮，多勾一个后导出按钮置灰并显示「目前平台无法匯出到資料夾…」文案；只勾一个时能正常分享出单个 .naiv4vibe。
- [ ] Mac 上跑 `scripts/run_flutter_tests.ps1` 的等价命令，确认本轮新增的 4 个测试文件与被我改过的 local_image_card_thumbnail_test.dart 全绿（本机 native assets 构建失败，无法跑测试）。
- [ ] 【必保 #3 的核心，最高优先】iPhone 真机生成并保存一张图，确认**没有**任何图片自动出现在系统相册。再去详情页溢出菜单点「保存到相册」，首次应弹系统「仅添加照片」权限询问 → 允许后出成功 toast 且照片进相册；随后在「设置 > 隐私 > 照片」关掉权限重试，应出 image_albumPermissionDenied 警告而不是异常串（gal 在 iOS 上究竟抛 accessDenied 还是 requestAccess 返回 false，只能真机确认）。
- [ ] 【必保 #2 的正交性】iPhone 打开「设置 → 分享 → 复制/拖拽时添加水印」，在详情页点常驻的「复制（去除元数据）」，粘贴到备忘录，确认结果**既没有水印也没有元数据**；再点溢出菜单的「复制（含元数据）」，确认它仍带水印且带元数据。
- [ ] 【必保 #27 的唯一真实复现场景】iPhone 覆盖安装（换容器 UUID）后打开本地图库旧图：顶栏「复用参数」按钮应在短暂延迟后出现（异步兜底解析完成）并能正确回填；覆盖安装前应立即出现。
- [ ] 【必保 #18 的核心】「文件」App → 我的 iPhone → NAI Launcher 下能看到 tagger_models；手动拖入 .onnx + 词表后设置页文件数变非 0、反推面板下拉能选到；**覆盖安装/重装后**（容器 UUID 变化）这些模型仍能被扫到；应用内 ZIP 导入落地到 Documents/tagger_models 而不是 Application Support，导入完成后立刻能在「文件」App 里看到。
- [ ] 设置 → 存储 → 本地 ONNX tagger 模型，点右侧文件夹图标能真的跳进「文件」App 的该目录（shareddocuments:// scheme 失败时只静默记日志，必须肉眼确认）。
- [ ] 【必保 #19】同一张图同一模型对比反推耗时，确认 intra-op 4 线程相对单线程有实际提速；并确认第二次反推**没有**在 tmp 的 nai_launcher_onnx_cache 下再复制一份 GB 级模型。顺带确认魔棒 SAM 抠图仍正常（与 tagger 共用 onnxruntime_v2 + CoreML EP，本次改了 session options）。
- [ ] 【必保 #29，模拟器和桌面都复现不了】iPhone 不开代理、直连状态下依次跑通：图像放大 / 图像增强 / Vibe 编码 / Director Tools（线稿、深度图、姿态）。
- [ ] 【必保 #16 的反向回归，编译器抓不到】Android APK 真机回归：自动检查仍触发、更新横幅仍弹、弹窗仍显示 APK 资产卡与「下载更新」、下载后能拉起系统安装界面。这是「写成非 Windows 就禁用」会静默踩掉的那条线。Windows 便携版同样回归一次。
- [ ] iPhone：设置 → 关于 → 更新卡片只有一条「前往 GitHub Release 页」，能用 Safari 打开；「检查更新」与「包含预发布版本」都不在。再跑 30 分钟不切页面，确认从不出现更新横幅、日志里无 'Auto update check failed' 周期重试。
- [ ] 【必保 #14】真机生成页触发一条 toast：确认它落在 AppBar 按钮行下方，且 leading + 4 个 action 在 toast 显示的 2.2 秒内全部可点（刘海/灵动岛下的 SafeArea 叠加 widget test 验不到）。
- [ ] 【必保 #12/#13】「更多」面板 → 添加账号：表单能弹出、键盘不遮输入框、登录成功后自动关闭并出现在切换账号列表里（LoginFormContainer 的内部依赖未被测试覆盖）。「更多」→ 切换主题连点，确认即时生效且重启后持久化。底栏在词库和图库两个分支的深层子页各重按一次当前 Tab，确认回到分支根且不影响其它分支。
- [ ] 【L16 / 必保 #28】iPad + Apple Pencil 在本地图库网格上悬停（不落笔），确认卡片不再缩放抬升、不再弹 360pt 悬浮预览卡；随后接触控板移动鼠标，确认 hover 呈现恢复。
- [ ] 【L16 导出门控】iPhone：在线画廊详情页多图作品的动作栏没有「下载全部媒体」但单张「下载原图」能拉起分享面板；多选栏只剩「加入队列」「批量收藏」；Vibe 库选 ≥2 条导出时格式只剩「打包文件」、只选 1 条时「单文件」重新出现；bundle 的「提取内部 Vibe」默认只勾第一个、无「全选」按钮、多勾后按钮置灰并显示新文案。
- [ ] 【必保 #21，若补了 UI 才验】iPhone 点「导出配置」应弹系统分享面板（不是另存为），导出的 JSON 第一层是 formatVersion / exportedAt / settings；在 Windows 上 dart run tool/export_content_settings.dart 导一份固定词+词库，传到 iPhone 导入，确认内容出现且 toast 的「跳过数」非 0（证明白名单在工作），并确认没把 iPhone 的图片保存路径/窗口尺寸改坏。
- [ ] 【必保 #23】iPhone 手动新建一条固定词（如 masterpiece），去词库把同内容条目改名改内容，回固定词面板确认跟着变了；**再改第二次**确认仍跟着变（证明 sourceEntryId 确实被补写，而不是只靠内容匹配蒙对一次）。
- [ ] iPhone SE 宽度（375pt）下反推面板的两个按钮（添加图片 / 从剪贴板粘贴）不溢出；剪贴板为空或非图片时弹「剪贴板里没有图片」而不是报错。
- [ ] iPad 横屏（≥840pt，走 DesktopShell + 宽屏顶栏）：确认详情页顶栏同时有「保存到相册」「复制（去除元数据）」「复制（含元数据）」三个按钮且不溢出；720~900px 正常字号窗口是理论风险最高区间。
- [ ] Mac 上在 L13 合并 l10n 之后跑全量 flutter test，重点看本批新增的 11 个测试文件、被改的 10 个既有测试文件，以及 app_toast_test.dart:430-466 那条「桌面 Toast」（L7b 报告疑似上游既有失败，需要确认它在本次改动前后状态一致）。

## 已知会失败/需单独确认的测试

- `test/data/services/vibe_bulk_import_service_test.dart` 的
  「progress keeps one parsed-result unit across bundles, parse failures, and save failures」
  在全量跑时失败、**单独跑两次都通过**。我们从未改动该服务或其测试
  （`git log v4.2.1..ios-v3 --` 对这三个文件为空），判为上游既有的顺序依赖型 flake。
  待办：在不含我们新增测试的范围里单独跑 `test/data/services/` 复现一次，坐实归属。
- `test/presentation/widgets/common/app_toast_test.dart` 的「桌面 Toast」一条，
  L7b 报告疑似上游既有失败，需确认改动前后状态一致。
