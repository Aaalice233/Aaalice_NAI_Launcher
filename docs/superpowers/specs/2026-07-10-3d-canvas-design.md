# 3D 画布(3D 模型图层)设计

- 日期:2026-07-10
- 状态:待评审
- 范围:`lib/presentation/widgets/image_editor/`、新增 `lib/presentation/widgets/model3d_editor/`(或同级新模块)、`assets/model3d_editor/`、`pubspec.yaml`(新增 flutter_inappwebview)、项目序列化 v2
- 决策人已确认:方案 A(WebView + three.js);三端(Windows/macOS/Android);独立 3D 编辑页;第一版仅 glb/gltf;内置人偶不默认加载,以编辑器内按钮添加;模型持久化用应用内模型库

## 背景:官网实现调研结论(2026-07-10 实证)

NovelAI 官网的"3D 画布"是 Canvas 编辑器里的一种图层类型(**3D 模型图层**,2026-02-23 上线),不是独立工具。从官网 live bundle 逆向确认:

- 技术栈:three.js(`WebGLRenderer {alpha:true, preserveDrawingBuffer:true, antialias:true}`)+ GLTFLoader / OrbitControls / TransformControls / CCDIKSolver + MMDLoader(.pmd/.pmx)+ @pixiv/three-vrm(.vrm)+ JSZip;2D 舞台为 Konva。
- **API 侧没有任何 3D/pose 参数**:3D 层经 `canvas.toDataURL("image/png")` 渲染成透明位图参与图层合成,画布 flatten 后走 img2img/inpaint。3D 只是"构图参考图生产者"。
- 交互:模型变换(整体移动/旋转/缩放)与 Pose 模式(逐骨骼 FK,TransformControls gizmo);相机为滚轮缩放/左键旋转/右键平移/中键推拉/WASDQE;支持 .vpd 姿势文件;MMD 物理(ammo.js)未实际加载;官网无内置人偶模型。
- 参考文档:官方公告 <https://blog.novelai.net/image-generation-canvas-update-new-tools-better-performance-and-3d-support-cbbc54c1d89d>;操作文档 <https://docs.novelai.net/en/image/editimagecanvas/>。

## 目标

- image_editor 新增 3D 模型图层:进入全屏 3D 编辑器摆模型/姿势/相机,确认后渲染为透明 PNG 写回图层,复用现有合成、导出、img2img/inpaint 全链路。
- 3D 图层可再编辑:双击重开编辑器,场景状态(模型引用、骨骼姿势、相机、光照)完整恢复。
- 三端可用:Windows(WebView2)、macOS(WKWebView)、Android(Chromium WebView),触屏与键鼠交互都覆盖。
- 离线可用:three.js 与编辑器页面全部 vendored 进 assets,不依赖 CDN。

## 非目标(第一版)

- 不做 VRM / PMD / PMX / VPD / zip 模型包(第二批,three.js 侧有现成 loader,架构预留 `modelRef` 抽象)。
- 不做 IK 解算与物理(官网对 glb 也是纯 FK;CCDIKSolver 依赖 MMD 模型自带 IK 链)。
- 不做官网式"画布内就地 3D 视口"(WebView 与 Flutter 画布叠放的输入路由三端各有一套坑;独立编辑页桥最窄、行为一致)。
- 不做多模型同场景。多角色构图用**多个 3D 图层叠加**实现(每层独立渲染透明 PNG),已覆盖主要需求。
- 不改生成 API 层:3D 层产物就是普通位图图层。

## 用户流程

1. 图层面板点「添加 3D 模型图层」→ 打开全屏 `Model3dEditorScreen`,**场景初始为空**,视口中央显示两个入口:「添加内置人偶」和「导入模型(.glb/.gltf)」。
2. 点「添加内置人偶」→ 从 assets 加载素体人偶(`builtin:mannequin`);或「导入模型」→ 文件选择器 → 拷入模型库 → 加载。场景已有模型时,这两个入口(移至工具栏)变为**替换**语义,替换前弹确认。
3. 模型变换/Pose 两种模式摆好构图,调相机与光照;编辑器内 Ctrl+Z 撤销姿势操作(会话内 undo,不进画布 history)。
4. 点「确认」→ 按当前画布尺寸渲染透明 PNG(辅助网格/骨骼球/gizmo 均隐藏)→ 返回 image_editor 建层;「取消」丢弃。
5. 双击 3D 图层 → 带 `sceneState` 重开编辑器 → 确认后替换该层位图(一次编辑 = 现有 history 的一步撤销)。

## 架构

```
image_editor 图层面板
  └─「添加/编辑 3D 模型图层」──► Model3dEditorScreen(Flutter 全屏页)
                                   ├─ 顶栏/工具栏:Flutter(确认·取消·模式·重置·光照·添加人偶·导入)
                                   └─ 视口:InAppWebView ◄─JS 桥─► editor.html + three.js
                                               ▲ http://127.0.0.1:<随机端口>
                                   LocalAssetServer(dart:io HttpServer)
                                     ├─ /editor/*        → assets/model3d_editor/
                                     ├─ /models/<hash>   → <appData>/model3d_library/
                                     └─ /builtin/<name>  → assets 内置人偶
返回 Model3dEditResult {pngBytes, sceneState, modelRef}
  └─► LayerManager 建层/更新层(Layer + Model3dLayerData 元数据)
```

### 关键选型理由

- **flutter_inappwebview 6.x**:唯一同时覆盖三端且提供 JS 双向桥(`addJavaScriptHandler`)的 WebView 插件。
- **自带 dart:io HttpServer** 而非各平台 asset-loader:three.js r160+ 仅发 ES modules,`file://` 下 import 被 CORS 拦;几十 MB 模型走 base64 桥会卡 UI,HTTP 流式加载三端行为一致。仅绑定 127.0.0.1、路径白名单、编辑器关闭即停。
- **UI 分工**:视口手势、gizmo、骨骼拾取归 JS(three.js 原生能力);按钮与文案归 Flutter(统一主题与 l10n)。桥上只过命令与结果,不过 UI 状态。
- **JS 侧无状态化**:`serialize` / `loadModel(sceneState)` 构成完整快照往返;WebView 崩溃或重载只需重放状态,不丢姿势。

## WebView 侧(assets/model3d_editor/)

`editor.html` + vendored `three.module.js`、`GLTFLoader`、`OrbitControls`、`TransformControls`(importmap 引入)。

- 场景:透明背景(`alpha:true, preserveDrawingBuffer:true`)、半球光 + 可调平行光、地面辅助网格(渲染输出时隐藏)。
- 模型变换模式:TransformControls 挂模型 root(translate/rotate/scale 切换)。
- Pose 模式:遍历 SkinnedMesh 骨骼生成可点击标记球,射线拾取后 TransformControls 以 rotate 模式挂骨骼(FK);支持骨骼平移/缩放(对齐官网)。
- 相机:OrbitControls,键位对齐官网(滚轮缩放/左键旋转/右键平移/中键推拉/WASDQE);触屏用 OrbitControls 原生手势(单指旋转、双指缩放平移)。指针命中 gizmo/骨骼球时 TransformControls 吞事件、相机让路(three 标准事件仲裁),触屏与鼠标同规则。
- 会话内姿势 undo 栈(Ctrl+Z / 工具栏按钮)。
- 渲染输出:按请求尺寸 `setSize` 后单帧渲染,隐藏全部辅助对象,`toDataURL("image/png")` 回传。

### 桥协议(全部 JSON)

| 方向 | 消息 | 内容 |
|---|---|---|
| Dart→JS | `loadModel` | `{url, sceneState?}`(再编辑时带状态;替换模型 = 直接再发 `loadModel`,JS 内部先卸载旧模型) |
| Dart→JS | `setMode` | `{mode: "transform" \| "pose", gizmo: "translate" \| "rotate" \| "scale"}` |
| Dart→JS | `resetPose` / `undoPose` | 重置到绑定姿势 / 会话内撤销 |
| Dart→JS | `setLight` | `{intensity, azimuth, elevation}` |
| Dart→JS | `render` | `{width, height}` → 返回 `{png: base64}` |
| Dart→JS | `serialize` | → 返回 `sceneState` |
| JS→Dart | `onReady` | 页面与 three 初始化完成 |
| JS→Dart | `onModelLoaded` / `onLoadError` | 加载结果(错误带原因分类) |
| JS→Dart | `onDirty` | 任何修改后置脏(Flutter 侧控制"未保存退出"提示) |

### sceneState 结构

```json
{
  "version": 1,
  "modelTransform": {"position": [..], "quaternion": [..], "scale": [..]},
  "bones": {"<骨骼名>": {"quaternion": [..], "position": [..], "scale": [..]}},
  "camera": {"position": [..], "target": [..], "fov": 30},
  "light": {"intensity": 1.0, "azimuth": 45, "elevation": 60}
}
```

`bones` 只记录与绑定姿势有差异的骨骼,JSON 通常几 KB。骨骼以名称寻址;同名骨骼冲突的模型属于劣质资产,加载时检测到重名即在 `onModelLoaded` 里告警并按首个匹配处理。模型引用(`modelRef`)不放在 sceneState 内,只存于 Dart 侧 `Model3dLayerData`——场景状态与模型来源解耦,替换模型可复用姿势(骨骼名匹配则套用)。

## Dart 侧组件

- **`Model3dEditorScreen`**:仿 `ImageEditorScreen.show()` 静态方法,入参 `{existing: Model3dLayerData?, renderWidth, renderHeight}`,返回 `Model3dEditResult {pngBytes, sceneState, modelRef}`,取消返回 null;脏状态退出弹确认。
- **`Model3dBridge`**:封装 InAppWebView controller 与桥协议,唯一接触 JS 的类;所有命令带超时(默认 15s)。
- **`Model3dLibraryService`**:导入时按 SHA-256 内容寻址拷贝到 `<appData>/model3d_library/<hash>.glb`(去重);`resolve(ref) → 服务 URL`;导入前限制文件大小(默认 200MB)。`builtin:` 前缀直接映射 assets,不入库。第一版不做引用计数,库管理界面后置。
- **`LocalAssetServer`**:编辑器打开时启动、关闭时停止;随机端口,占用重试 3 次;仅白名单路径,拒绝 `..` 穿越。
- **图层集成**:`Layer` 增加可空 `Model3dLayerData {modelRef, sceneState}`;图层面板给含该数据的层加 3D 角标,双击进入再编辑;确认后替换位图走现有 history。渲染尺寸 = 当前画布尺寸(画布本身受 3.14MP 生成上限约束,无需额外限制)。

## 序列化与项目兼容

`projectVersion` 1 → 2:`LayerProjectData` 增加可空字段 `model3d: {modelRef, sceneState}`;位图仍走现有 base64 `imageData`。

- v1 项目读入:`model3d` 为 null,行为不变。
- v2 项目被旧版打开:未知字段被忽略,3D 层退化为普通位图层,不损坏。
- 模型文件丢失(库被清)时:层保持位图形态可用,再编辑时提示"模型文件已丢失,可重新导入"。**位图为主、3D 元数据为增强**的双轨设计是本功能的降级底线。

## 错误处理

| 场景 | 处理 |
|---|---|
| Windows 无 WebView2 运行时 | 入口检测(插件提供的环境探测),弹窗引导安装 Evergreen Runtime |
| WebGL 初始化失败 | JS 上报 `onLoadError(webgl_unavailable)`,编辑器显示不可用页,不崩 |
| 模型解析失败 / 非 glb/gltf / 超大 | 导入前扩展名与大小校验;解析失败 `onLoadError` 带原因,Toast 提示 |
| 再编辑时模型缺失 | 提示后允许重新导入或仅以位图使用 |
| 端口占用 | 随机端口重试 3 次,仍失败则报错并留日志 |
| 桥命令超时 | Bridge 统一 15s 超时,失败提示并允许重试/退出 |

## 测试策略

WebView 真实渲染进不了 `flutter_test`,可测逻辑全部收在 Dart 纯类:

- `Model3dLibraryService`:哈希/去重/resolve/大小限制(临时目录)。
- `sceneState` 与 `Model3dLayerData` 序列化往返;`ProjectData` v1→v2 兼容读写(v1 读入、v2 含未知字段读入)。
- `LocalAssetServer`:白名单命中、`..` 穿越拒绝、端口重试。
- `Model3dBridge`:以 mocktail 假 controller 测消息编解码与超时。
- 三端真实渲染走发布前手动冒烟清单;spike 阶段先在 Windows 全链路验证。

## 实施里程碑

1. **Spike(风险集中点)**:Windows 上 flutter_inappwebview + LocalAssetServer + three.js 转方块 + PNG 回传全链路打通。
2. editor.html 完整编辑器:空场景入口、人偶/导入、双模式、手势、undo、渲染输出。
3. Dart 桥 + 模型库 + `Model3dEditorScreen`。
4. image_editor 图层集成 + 项目序列化 v2 + l10n 词条。
5. macOS/Android 适配冒烟;内置人偶资产选型与接入。

## 实施约束

- 内置人偶资产:必须 CC0 或明确可商用再分发授权、带标准 humanoid 骨骼的 SkinnedMesh、文件 ≤ 5MB(打进 assets 与安装包);资产选型是里程碑 5 的实施任务。
- vendored three.js 锁定单一版本(取当前稳定版),升级需回归冒烟。
- 遵循仓库验证规范:收尾前 `flutter pub get`、必要的 `build_runner`、`flutter test`、`flutter analyze`、`flutter build windows --release`。
