# iOS 分支

`ios` 分支是 NAI Launcher 的 iOS 版：**上游正式版 + iOS 平台层 + 选定的 iOS 偏好定制**。当前基于 v4.2.1，不跟随 `main` 的开发中提交，上游发布下一个正式版后再整体跟进。

- 所有改动以 PR 形式合入 `ios`，不直接推送。
- iOS 版只提供未签名 IPA，需要用户自行签名侧载。
- 与 Android / 桌面共享的业务逻辑、Provider 与界面保持上游实现，iOS 的差异只出现在下面列出的位置。

## 构建

环境：macOS、Xcode（已验证 16.4）、Flutter 3.44.2（与上游 CI 一致）、CocoaPods。最低系统版本 iOS 16.0（`ios/Podfile`、`project.pbxproj`）。

1. 获取 `assets/databases/tag_catalog.db`：与上游相同，按 `assets/databases/manifest.json` 锁定的 URL 下载并校验大小与 SHA-256（`scripts/prepare_bundled_database.ps1`），确认是真实 SQLite 而不是 LFS pointer。
2. `flutter pub get --enforce-lockfile`，然后 `dart run build_runner build --delete-conflicting-outputs`。
3. `flutter build ios --release --no-codesign`。
4. 打包 IPA：

   ```bash
   mkdir -p Payload && ditto build/ios/iphoneos/Runner.app Payload/Runner.app && zip -qry NAI_Launcher_iOS.ipa Payload
   ```

CI 入口是 `.github/workflows/ios-release.yml`（macOS runner）：手动触发只产出 Actions artifact；推送 `ios-v*` tag 时额外发布，见下节。

## 发布

iOS 版不单独建 Release，而是把 IPA 追加到**同版本的上游 Release**：

1. 在 `ios` 分支上打 tag `ios-v<版本>`，版本与 `pubspec.yaml` 一致（同一版本只重打 iOS 包时用 `ios-v<版本>-<n>`）。
2. 推送 tag 后，`ios-release.yml` 打包并把 `NAI_Launcher_iOS_<版本>+<构建号>_unsigned.ipa` 与 `.sha256` 上传到上游 Release `v<版本>`（同名文件覆盖），在发布说明末尾追加或替换 `<!-- ios-build:start -->` 到 `<!-- ios-build:end -->` 之间的 iOS 段落。
3. tag 与 `pubspec.yaml` 版本不一致、或上游 Release 不存在时，workflow 直接失败。

IPA 不写入 `checksums.txt` 与 `release_manifest.json`：应用内更新只读 manifest，其他平台的更新检查不会看到 iOS 包；而更新检查只认 `v` 开头的 tag，`ios-v*` 也不会被当成新版本。

构建相关的两个约束：

- `.gitattributes` 固定 `ios/Podfile` 与 `ios/Podfile.lock` 为 `eol=lf`。Windows 检出成 CRLF 时，Xcode 的 `[CP] Check Pods Manifest.lock` 会在编译末尾报 `sandbox is not in sync`。
- `nai_png_codec` 的 native assets 在 iOS 上打包为 `Runner.app/Frameworks/nai_png_codec.framework`；`onnxruntime_v2` 静态链接进主二进制。

## 签名与安装

- IPA 未签名。签名工具必须对 `Payload/Runner.app` 里的**每一个嵌套二进制**（含 `nai_png_codec.framework`）重签，只签主可执行文件会被 dyld 拒绝加载。
- Bundle ID 为 `com.aaalice.naiLauncher`。签名时保持不变、覆盖安装，才能保留应用沙盒里的数据。
- 覆盖安装后应用容器路径会变，数据库里存的绝对路径随之失效；相关兜底见下文「沙盒路径变化」。

## 与 Android / 桌面的差异

### 平台限制（iOS 平台层）

判定集中在 `lib/core/platform/platform_capabilities.dart`。

| 能力 | iOS 上的行为 |
| --- | --- |
| 应用内更新 | 关闭：不做周期检查、不弹更新横幅；「关于」页改为打开 GitHub Release 页面 |
| 导出 / 另存为 | 写入临时文件后交给系统分享面板，关闭面板视为取消 |
| 先选文件夹再批量导出 | 不支持（拿不到可长期写入的目录）：画廊批量下载与详情「下载全部媒体」入口隐藏；Vibe 多条导出只提供打包格式；提取内部 Vibe 一次只能导出一条 |
| 系统相册 | 保存**不会**自动进入相册；详情页「保存到相册」是独立的手动动作（`gal`，首次询问「仅添加照片」权限） |
| 读取图片元数据 | 取图来源多一个「从相册选择」（PHPicker，`allowCompression: false` 以取得未转码的原图） |
| 存储路径 | 图片、Vibe 库、Hive 三处路径只读，说明为沙盒固定 |
| 本地反推模型 | 目录固定为 `Documents/tagger_models`，可在「文件」App 中直接放入模型；设置页可一键跳转到该目录 |
| 代理 | 只支持手动模式（iOS 读不到系统代理地址），自动模式段隐藏 |
| Krita、ComfyUI、DLSS、快捷键配置、外部拖放 | 与 Android 相同，不可用 |
| 键盘 | 点输入框外部即收起键盘；在线画廊网格滑动时收起搜索键盘 |
| Google Drive / OneDrive 云同步 | 未在 iOS 上验证 |

### iOS 版的偏好定制

| 定制 | 说明 |
| --- | --- |
| 生成页左侧快捷工具抽屉 | 左抽屉为固定词 / 角色的开关列表（固定词按正负向与词库分类分节、可收起并记住状态）；参数面板改到右抽屉；历史改为顶栏按钮弹出的面板 |
| 生成页底栏 ×N | 连续生成张数放在底栏 |
| 放大 / 增强后展开参数面板 | 手机上点「放大 / 增强」后自动打开参数面板 |
| 复制不带元数据 | 详情页顶栏常驻「复制（去除元数据）」，带元数据的复制收进溢出菜单 |
| 窄屏分类树 | 本地图库、词库、Vibe 库的分类树用左侧抽屉呈现（上游为底部面板） |
| 本地图库 3 列 | 宽度 <600 时最小卡片宽 110，390pt 手机排 3 列（上游为 136 / 160，2 列） |
| AI TAG 原样发送 | 从 AI TAG 发送到文生图时提示词原样填入，不做 SD→NAI 转换 |
| 移动端默认值 | 生成完成提示音默认关闭；代理默认关闭；随机提示词工具默认隐藏 |
| 底栏重按当前 Tab | 回到该分支的根页面 |
| 顶部 toast | 窄屏下让开顶栏按钮行、不拦截点击、2.2 秒消失 |
| 剪贴板 | 可从剪贴板读取图片元数据（生成页顶栏一键导入，可勾选要套用的参数）；Vibe、精准参考、图生图、反推面板可直接粘贴剪贴板图片 |
| 触屏可用性 | 取色器点按即取色；标签长按弹出菜单；3D 姿势编辑器支持触屏；角色添加入口到上限时可见反馈；紧凑角色行命中区 44pt；触屏上不包桌面拖放层 |
| 「更多」面板添加账号 | 登录后可在手机上添加第二个账号 |
| 大图低清占位 | 原图解码期间先显示降采样占位图 |
| 中文输入 | 输入法组词期间不被外部改写；提示词输入同步写入状态（避免组词时卡死） |
| Token 计数 | 结果缓存 + 停止输入 400ms 后再计算 |
| 其他网络修复 | 图像增强改用生图网络客户端（直连时通用客户端的 HTTP/2 异常）；AI TAG 请求带同源 Referer（与 `main` 相同） |

## 与上游同步

上游文件中的每一处 iOS 改动都带有「偏离上游」注释，列出全部触点：

```bash
git grep -n "偏离上游"
```

同步到上游新的正式版时，从该版本开新分支，按下表逐条把 iOS 改动迁移过去；迁移时顺带把插在上游文件里的大段逻辑挪进独立文件，上游文件只保留挂钩。遇到上游已实现等价能力的条目，先确认行为再决定是否丢弃。

### 文件与条目对照

iOS 自有文件：`ios/`、`.github/workflows/ios-release.yml`、`lib/core/services/ios_photo_library_service.dart`、`lib/presentation/adaptive/ios_keyboard_dismissal.dart`、`lib/presentation/screens/generation/widgets/quick_tools_drawer.dart`、`docs/ios.md`。

| 条目 | 改动的上游文件 |
| --- | --- |
| 构建与依赖 | `.gitattributes`、`pubspec.yaml`（`gal`）、三份 README 的平台表 |
| 能力判定 | `lib/core/platform/platform_capabilities.dart` |
| 导出与分享 | `core/services/file_export_service.dart`、`core/services/native_share_service.dart`、`core/utils/vibe_export_utils.dart`、`screens/generation/services/generation_image_batch_actions.dart`、`screens/local_gallery/local_gallery_action_coordinator.dart`、`screens/online_gallery/online_gallery_selection_actions.dart`、`screens/online_gallery/online_gallery_detail_launcher.dart`（下载全部）、`screens/vibe_library/widgets/vibe_export_dialog.dart`、`screens/vibe_library/widgets/vibe_export_dialog_advanced.dart`、`widgets/common/image_picker_card/_internal/picker_handler.dart`、`screens/vibe_library/vibe_library_screen_controller.dart` |
| 相册与读取元数据 | `widgets/common/image_detail/image_detail_viewer.dart`、`widgets/common/image_detail/components/detail_top_bar.dart`、`services/mobile_image_metadata_importer.dart`、`router/mobile_more_panel.dart` |
| 应用内更新 | `core/services/app_installation_service.dart`、`data/datasources/remote/github_api_service.dart`、`screens/splash/app_bootstrap.dart`、`widgets/common/update_notice_banner.dart`、`widgets/common/update_check_dialog.dart`、`screens/settings/sections/about_settings_section.dart` |
| 存储路径与反推模型 | `screens/settings/sections/storage_settings_section.dart`、`data/services/local_onnx_model_service.dart`、`data/services/local_onnx_tagger_service.dart` |
| 沙盒路径变化 | `data/services/gallery/gallery_album_import_coordinator.dart`、`image_detail_viewer.dart` / `detail_top_bar.dart`（元数据兜底）、`widgets/common/image_detail/image_detail_data.dart`、`widgets/common/image_detail/file_image_detail_data.dart` |
| 代理 | `providers/proxy_settings_provider.dart`、`providers/startup_initialization_provider.dart`、`screens/settings/sections/network_settings_section.dart` |
| Krita 入口 | `screens/generation/widgets/image_preview.dart`、`screens/generation/widgets/history_panel.dart` |
| 键盘 | `lib/app.dart`、`screens/online_gallery/online_gallery_grid.dart` |
| 中文输入 | `widgets/prompt/unified/unified_prompt_input.dart`、`providers/generation/generation_params_notifier.dart` |
| 网络修复 | `data/datasources/remote/nai_image_enhancement_api_service.dart`、`data/datasources/remote/online_gallery/ai_tag_gallery_source_adapter.dart`、`core/cache/online_gallery_image_cache_manager.dart` |
| 生成页布局（左抽屉、×N、展开参数面板） | `screens/generation/mobile_generation_chrome.dart`、`screens/generation/mobile_generation_controller.dart`、`screens/generation/widgets/image_preview.dart`、`core/constants/storage_keys.dart` |
| 复制不带元数据 | `image_detail_viewer.dart`、`detail_top_bar.dart` |
| 窄屏分类树与图库列数 | `screens/local_gallery/local_gallery_screen.dart`、`screens/local_gallery/local_gallery_screen_controller.dart`、`screens/local_gallery/local_gallery_view_model.dart`、`screens/tag_library_page/tag_library_page_screen.dart`、`screens/vibe_library/vibe_library_screen.dart` |
| AI TAG 原样发送 | `providers/pending_prompt_provider.dart`、`services/generation_prompt_transfer_service.dart`、`screens/generation/widgets/prompt_input_coordinator.dart`、`online_gallery_detail_launcher.dart` |
| 移动端默认值 | `providers/notification_settings_provider.dart`、`providers/proxy_settings_provider.dart`、`core/storage/local_storage_service.dart` |
| 底栏与 toast | `router/mobile_shell.dart`、`widgets/common/app_toast.dart` |
| 剪贴板 | `utils/clipboard_image.dart`、`services/mobile_image_metadata_importer.dart`、`mobile_generation_chrome.dart`、`screens/generation/widgets/img2img_source_section.dart`、`screens/generation/widgets/precise_reference_panel.dart`、`screens/generation/widgets/reverse_prompt_panel.dart`、`screens/generation/widgets/vibe_transfer_content.dart` |
| 触屏可用性 | `widgets/image_editor/widgets/color_picker.dart`、`widgets/tag_chip.dart`、`widgets/online_gallery/gallery_detail_tag_section.dart`、`assets/model3d_editor/editor.js`、`assets/model3d_editor/editor.html`、`widgets/character/add_character_buttons.dart`、`widgets/character/inline_character_row.dart`、`history_panel.dart`、`widgets/gallery/gallery_grid.dart`、`widgets/gallery/local_image_card_3d.dart` |
| 添加账号 | `mobile_more_panel.dart` |
| 大图低清占位 | `widgets/common/image_detail/components/detail_image_page.dart`、`image_detail_data.dart`、`file_image_detail_data.dart` |
| Token 计数 | `core/services/tokenizers/t5_prompt_token_encoder.dart`、`providers/prompt_token_counter_provider.dart` |

表中路径除另有前缀外均相对 `lib/presentation/`。

## 测试

- 测试在 macOS 上运行：`nai_png_codec` 的 native assets 在每次 `flutter test` 时都要编译，Windows 上需要 Visual Studio C++ 工具链。
- 在 v4.2.1 上，以下 4 条上游用例在 macOS 上本来就失败，与 iOS 改动无关：`gallery_album_cloud_sync_adapter_test` 的 `export includes pending paths and relativizes cover`、`agent_image_observation_ledger_test` 的 `normalizes separators and case so both entry points agree`、`generation_toolbox_test` 的 `interrogate_image rejects a path outside the workspace`（均为 Windows 路径写法），以及 `selectable_image_card_gesture_test` 的 `linked double click is immediate tap then one double callback`。
- 被 iOS 偏好有意改变行为的上游用例，已按 iOS 行为调整前置条件或预期，调整处带「iOS 分支」注释。

## 真机回归清单

每次发布前在 iPhone 上逐项确认；有 iPad 时补做标注 iPad 的项。

- 签名后能安装；覆盖安装后原有数据仍在
- 生成并保存一张图，系统相册里**没有**自动出现任何图片
- 详情页「保存到相册」：首次弹出「仅添加照片」权限询问，允许后图片进入相册
- 打开「复制/拖拽时添加水印」后点「复制（去除元数据）」：粘贴出的图既无元数据也无水印
- 覆盖安装后打开本地图库旧图：「复用参数」按钮在短暂延迟后出现并可用
- 打开 ≥2048px 的大图：先显示低清占位，再换成原图
- 「读取图片元数据」→「从相册选择」：选一张用本 app 存进相册的 PNG，能读出完整参数；选普通 JPEG 照片提示读取失败
- 「文件」App 中能看到 `tagger_models`；放入模型后设置页能识别；设置页文件夹按钮能跳到该目录；覆盖安装后模型仍能扫到
- 应用内 ZIP 导入反推模型后，模型出现在 `tagger_models`
- 本地反推与魔棒抠图正常
- 设置页三处存储路径只读，说明为沙盒固定
- 长时间使用不出现更新横幅；「关于」页只有打开 Release 页面的入口
- 不开代理直连：图像放大、增强、Vibe 编码均成功
- 在线画廊 AI TAG 来源正常加载，搜索、榜单、详情可用
- 在线画廊搜索：点输入框外部收起键盘，滑动网格收起键盘，点补全候选不收起
- 生成页左抽屉：固定词分节、收起状态在重开抽屉与重启后保留；角色页可切换
- 生成页触发 toast：不遮挡顶栏按钮，toast 显示期间顶栏按钮可点
- 底栏重按当前 Tab 回到根页面
- 从 Safari 复制一张图：生成页顶栏导入读出元数据；反推、Vibe、精准参考、图生图面板能粘贴
- 提示词输入框用中文输入法连续输入、快速删除，不卡死
- 「更多」面板 → 添加账号：表单可用，登录成功后自动关闭
- 在线画廊详情多图作品：没有「下载全部媒体」，单张「下载原图」弹出分享面板
- Vibe 库多条导出只提供打包格式，导出时弹出分享面板
- 3D 姿势编辑器可用手指旋转、缩放和选中骨骼
- iPad：Apple Pencil 在本地图库卡片上悬停不触发缩放和悬浮预览；宽屏详情页顶栏同时有「保存到相册」和「复制（去除元数据）」
